#!/usr/bin/env python3
"""R1.7 benchmark: VNtyper-Online versus a local Docker run on identical sliced BAMs.

For each BAM the harness slices the MUC1 region exactly as the browser does
(``samtools view -P -b <bam> <region>`` with the region read from the
frontend's regionsConfig.js), runs the pinned image locally, submits the same
slice to the online API, and compares the two Kestrel results. ``--batch-sizes``
then submits N jobs at once to measure queue wait and throughput.

Stdlib only. Never point this at the production service without a scheduled
window: every submission is a real job on a shared single-worker queue.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
import zipfile
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REGIONS = REPO_ROOT / "frontend/resources/js/regionsConfig.js"
# VNtyper writes <out>/kestrel/kestrel_result.tsv; the API zips <out> with paths relative
# to it (vntyper/scripts/archive_safety.py _write_zip), so the member is kestrel/kestrel_result.tsv.
KESTREL_TSV = "kestrel_result.tsv"
ARTIFACT_FLAG = "False_Positive_4bp_Insertion"
# Seconds between calls per endpoint: the API's limits (10/60 s high, 100/60 s simple) plus 20%.
MIN_INTERVAL = {"high": 60 / 10 * 1.2, "simple": 60 / 100 * 1.2}


# --------------------------------------------------------------------------- regions / slicing


def read_regions(path: Path) -> dict[str, str]:
    """Parse ``{assembly: region}`` from the frontend's regionsConfig.js."""
    text = path.read_text()
    found = dict(re.findall(r"assembly:\s*'([^']+)',\s*region:\s*'([^']+)'", text))
    if not found:
        raise ValueError(f"no assembly/region pairs found in {path}")
    return found


def slice_cmds(bam: Path, region: str, out: Path) -> list[list[str]]:
    # Same flags as frontend bamProcessing.js extractRegion(), then index.
    return [
        ["samtools", "view", "-P", "-b", str(bam), region, "-o", str(out)],
        ["samtools", "index", str(out)],
    ]


def local_cmd(image: str, bam: Path, out_dir: Path, threads: int, assembly: str, fast: bool):
    # Mirrors build_vntyper_command() in the API worker (docker/app/tasks.py), adVNTR off.
    # Run as the caller so outputs are not owned by the image user; HOME=/tmp because
    # the caller's uid has no home directory in the image.
    cmd = [
        "docker", "run", "--rm", "--user", f"{os.getuid()}:{os.getgid()}", "-e", "HOME=/tmp",
        "-v", f"{bam.parent}:/in:ro", "-v", f"{out_dir}:/out",
        image, "vntyper", "pipeline", "--bam", f"/in/{bam.name}", "-o", "/out",
        "--threads", str(threads), "--reference-assembly", assembly,
    ]  # fmt: skip
    return cmd + ["--fast-mode"] if fast else cmd


# --------------------------------------------------------------------------- concordance


def parse_kestrel(text: str) -> list[dict[str, str]]:
    lines = [ln for ln in text.splitlines() if ln and not ln.startswith("##")]
    return list(csv.DictReader(lines, delimiter="\t"))


def classify_row(row: dict[str, str]) -> str:
    """positive / flagged / artifact / negative. Only unflagged calls are positive."""
    conf, flag = row.get("Confidence", ""), row.get("Flag", "") or "Not flagged"
    if not conf or conf == "Negative":
        return "negative"
    if ARTIFACT_FLAG in flag:
        return "artifact"
    return "positive" if flag == "Not flagged" else "flagged"


def sample_status(rows: list[dict[str, str]]) -> str:
    classes = {classify_row(r) for r in rows}
    for status in ("positive", "flagged", "artifact"):
        if status in classes:
            return status
    return "negative"


def variant_key(row: dict[str, str]) -> str:
    return ":".join(row.get(k, "") for k in ("Motif", "POS", "REF", "ALT"))


def compare(local_rows: list[dict[str, str]], online_rows: list[dict[str, str]]) -> dict:
    """Compare call status, variant set, confidence and flag between two Kestrel results."""
    loc = {variant_key(r): r for r in local_rows if classify_row(r) != "negative"}
    onl = {variant_key(r): r for r in online_rows if classify_row(r) != "negative"}
    mismatches = sorted(set(loc) ^ set(onl))
    for key in sorted(set(loc) & set(onl)):
        for field in ("Confidence", "Flag"):
            if loc[key].get(field) != onl[key].get(field):
                mismatches.append(f"{key} {field}: {loc[key].get(field)} != {onl[key].get(field)}")
    status_l, status_o = sample_status(local_rows), sample_status(online_rows)
    return {
        "status_local": status_l,
        "status_online": status_o,
        "concordant": status_l == status_o and not mismatches,
        "mismatches": "; ".join(mismatches),
    }


def pick_kestrel(paths: list[str]) -> str:
    """The kestrel_result.tsv to use: prefer one inside a kestrel/ dir, then the shallowest."""
    hits = [p for p in paths if p.split("/")[-1] == KESTREL_TSV]
    if not hits:
        raise ValueError(f"{KESTREL_TSV} not found")
    return min(hits, key=lambda p: (not p.endswith("kestrel/" + KESTREL_TSV), p.count("/"), p))


def kestrel_from_zip(data: bytes) -> str:
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        return zf.read(pick_kestrel(zf.namelist())).decode()


def kestrel_from_dir(root: Path) -> str:
    return Path(pick_kestrel([str(p) for p in root.rglob(KESTREL_TSV)])).read_text()


# --------------------------------------------------------------------------- timing


def to_epoch(value) -> float | None:
    """Server timestamps may be epoch seconds or ISO 8601; None if absent."""
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    dt = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    return (dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)).timestamp()  # naive = UTC, like the API


def online_timings(t: dict, server: dict) -> dict:
    """Split one online job into phases.

    ``t`` holds client epochs: upload_start, upload_end, first_started (first poll
    that saw 'started', may be None), first_completed, download_end. ``server`` is
    the final job-status body; its submitted_at/started_at/completed_at win when
    present, otherwise queue/compute come from polling (resolution = poll interval).
    """
    sub, sta, com = (to_epoch(server.get(k)) for k in ("submitted_at", "started_at", "completed_at"))
    source = "server" if None not in (sub, sta, com) else "client"
    if source == "client":
        sub, sta, com = t["upload_end"], t.get("first_started"), t["first_completed"]
    return {
        "timing_source": source,
        "upload_s": t["upload_end"] - t["upload_start"],
        "queue_s": None if sta is None else sta - sub,
        "compute_s": None if sta is None else com - sta,
        "download_s": t["download_end"] - t["first_completed"],
        "end_to_end_s": t["download_end"] - t["upload_start"],
    }


def batch_summary(jobs: list[dict]) -> dict:
    """Throughput and queue wait for one batch of concurrently submitted jobs."""
    first_submit = min(j["upload_start"] for j in jobs)
    last_done = max(j["first_completed"] for j in jobs)
    waits = sorted(j["queue_s"] for j in jobs if j["queue_s"] is not None)
    span = last_done - first_submit
    return {
        "n": len(jobs),
        "makespan_s": span,
        "throughput_jobs_per_h": len(jobs) / span * 3600 if span > 0 else None,
        "queue_wait_median_s": waits[len(waits) // 2] if waits else None,
        "queue_wait_max_s": waits[-1] if waits else None,
    }


# --------------------------------------------------------------------------- online client


class Api:
    def __init__(self, base: str, dry: bool):
        self.base, self.dry, self.last = base.rstrip("/"), dry, {"high": 0.0, "simple": 0.0}

    def call(self, method, path, tier, body=None, headers=None):
        if self.dry:
            print(f"[dry-run] {method} {self.base}{path}")
            return None
        while True:
            time.sleep(max(0.0, self.last[tier] + MIN_INTERVAL[tier] - time.time()))
            self.last[tier] = time.time()
            req = urllib.request.Request(self.base + path, body, headers or {}, method=method)
            try:
                with urllib.request.urlopen(req, timeout=600) as resp:
                    return resp.read()
            except urllib.error.HTTPError as e:
                if e.code != 429:
                    raise
                time.sleep(float(e.headers.get("Retry-After") or 60))

    def json(self, path, tier="simple"):
        raw = self.call("GET", path, tier)
        return None if raw is None else json.loads(raw)

    def submit(self, bam: Path, threads: int, assembly: str, fast: bool) -> str:
        fields = {
            "thread": str(threads), "reference_assembly": assembly,
            "fast_mode": str(fast).lower(), "advntr_mode": "false",
        }  # fmt: skip
        files = {"bam_file": bam, "bai_file": Path(f"{bam}.bai")}
        boundary = uuid.uuid4().hex
        buf = io.BytesIO()
        for k, v in fields.items():
            buf.write(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
        for k, p in files.items():
            head = f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"; filename="{p.name}"\r\n'
            buf.write(f"{head}Content-Type: application/octet-stream\r\n\r\n".encode())
            buf.write(p.read_bytes() if not self.dry else b"")
            buf.write(b"\r\n")
        buf.write(f"--{boundary}--\r\n".encode())
        ctype = {"Content-Type": f"multipart/form-data; boundary={boundary}"}
        raw = self.call("POST", "/run-job/", "high", buf.getvalue(), ctype)
        return "DRYRUN" if raw is None else json.loads(raw)["job_id"]


def submit_and_track(api: Api, bams: list[Path], args) -> list[dict]:
    """Submit all BAMs, poll until each finishes, download each result."""
    jobs = []
    for bam in bams:
        t = {"bam": bam, "upload_start": time.time()}
        t["job_id"] = api.submit(bam, args.threads, args.assembly, args.mode == "fast")
        t["upload_end"] = time.time()
        jobs.append(t)
    if api.dry:
        api.json("/job-status/DRYRUN/")
        api.call("GET", "/download/DRYRUN/", "high")
        return []
    pending = list(jobs)
    while pending:
        for t in list(pending):
            body = api.json(f"/job-status/{t['job_id']}/")
            if body["status"] == "started":
                t.setdefault("first_started", time.time())
            elif body["status"] in ("completed", "failed"):
                t["first_completed"], t["server"] = time.time(), body
                pending.remove(t)
        time.sleep(args.poll)
    for t in jobs:
        if t["server"]["status"] == "completed":
            t["zip"] = api.call("GET", f"/download/{t['job_id']}/", "high")
        t["download_end"] = time.time()
        t.update(online_timings(t, t["server"]))
    return jobs


# --------------------------------------------------------------------------- main


def run(cmd: list[str], dry: bool) -> str:
    print(("[dry-run] " if dry else "+ ") + " ".join(cmd), file=sys.stderr)
    return "" if dry else subprocess.run(cmd, check=True, capture_output=True, text=True).stdout


ROW_COLS = [
    "sample", "job_id", "online_status", "timing_source", "upload_s", "queue_s", "compute_s",
    "download_s", "end_to_end_s", "local_wall_s", "status_local", "status_online", "concordant",
    "mismatches", "error",
]  # fmt: skip


def error_text(e: Exception) -> str:
    detail = (getattr(e, "stderr", None) or "").strip().splitlines()
    return f"{type(e).__name__}: {e}" + (f" | {detail[-1]}" if detail else "")


def benchmark_sample(api: Api, bam: Path, args, versions_match: bool) -> dict:
    """Online then local run of one slice. Any failure is recorded in ``error``, never raised,
    so online timings already measured survive a failed local run and the next sample runs."""
    row: dict = {"sample": bam.stem}
    errors = []
    o: dict = {}
    try:
        # One job at a time so queue wait reflects other users, not our own submissions.
        o = (submit_and_track(api, [bam], args) or [{}])[0]
        timing = ("job_id", "timing_source", "upload_s", "queue_s", "compute_s", "download_s", "end_to_end_s")
        row.update({k: o.get(k) for k in timing})
        row["online_status"] = o.get("server", {}).get("status")
    except Exception as e:
        errors.append(f"online: {error_text(e)}")
    res_dir = (args.out / "local" / bam.stem).resolve()
    t0 = time.time()
    try:
        res_dir.mkdir(parents=True, exist_ok=True)
        run(local_cmd(args.image, bam.resolve(), res_dir, args.threads, args.assembly, args.mode == "fast"), api.dry)
        row["local_wall_s"] = time.time() - t0
        if versions_match and "zip" in o:
            local_rows = parse_kestrel(kestrel_from_dir(res_dir))
            row.update(compare(local_rows, parse_kestrel(kestrel_from_zip(o["zip"]))))
    except Exception as e:
        errors.append(f"local: {error_text(e)}")
    if errors:
        row["error"] = "; ".join(errors)
        print(f"! {bam.stem}: {row['error']}", file=sys.stderr)
    return row


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("bams", nargs="+", type=Path)
    p.add_argument("--assembly", required=True, help="key in regionsConfig.js, e.g. hg38, GRCh38")
    p.add_argument("--base-url", required=True, help="API base, e.g. https://staging.example/api")
    p.add_argument("--image", default="ghcr.io/hassansaei/vntyper:2.0.47")
    p.add_argument("--threads", type=int, default=4)
    p.add_argument("--mode", choices=("fast", "normal"), default="normal")
    p.add_argument("--batch-sizes", default="", help="comma list, e.g. 1,5,10 (cycles through BAMs)")
    p.add_argument("--poll", type=float, default=5.0, help="seconds between status sweeps")
    p.add_argument("--regions-config", type=Path, default=DEFAULT_REGIONS)
    p.add_argument("--out", type=Path, default=Path("r17_out"))
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args(argv)
    dry = args.dry_run

    region = read_regions(args.regions_config).get(args.assembly)
    if region is None:
        p.error(f"assembly {args.assembly!r} not in {args.regions_config}")
    args.out.mkdir(parents=True, exist_ok=True)
    api = Api(args.base_url, dry)

    online_ver = (api.json("/version/") or {}).get("tool_version")
    local_ver = run(["docker", "run", "--rm", args.image, "vntyper", "-v"], dry).strip() or None
    digest = run(["docker", "image", "inspect", "--format", "{{json .RepoDigests}}", args.image], dry).strip()
    versions_match = online_ver is not None and online_ver == local_ver

    sliced = []
    for bam in args.bams:
        out = args.out / "sliced" / f"{bam.stem}.muc1.bam"
        out.parent.mkdir(parents=True, exist_ok=True)
        for cmd in slice_cmds(bam, region, out):
            run(cmd, False)  # local and cheap, so dry-run slices too
        sliced.append(out)

    rows = []
    with open(args.out / "per_sample.tsv", "w", newline="") as fh:
        w = csv.DictWriter(fh, ROW_COLS, delimiter="\t", extrasaction="ignore")
        w.writeheader()
        for bam in sliced:
            row = benchmark_sample(api, bam, args, versions_match)
            rows.append(row)
            w.writerow(row)
            fh.flush()  # a crash later in the run keeps every finished sample

    batches = []
    for n in [int(x) for x in args.batch_sizes.split(",") if x]:
        try:
            jobs = submit_and_track(api, [sliced[i % len(sliced)] for i in range(n)], args)
            batches.append(batch_summary(jobs) if jobs else {"n": n, "dry_run": True})
        except Exception as e:  # keep the per-sample results and the other batches
            batches.append({"n": n, "error": error_text(e)})

    compared = [r for r in rows if "concordant" in r]
    summary = {
        "base_url": args.base_url, "assembly": args.assembly, "region": region,
        "mode": args.mode, "threads": args.threads, "image": args.image, "image_digest": digest,
        "online_tool_version": online_ver, "local_tool_version": local_ver,
        "concordance": (
            {"n": len(compared), "concordant": sum(r["concordant"] for r in compared)}
            if versions_match else
            {"refused": f"tool versions differ or unknown: online={online_ver!r} local={local_ver!r}"}
        ),
        "batches": batches, "dry_run": dry,
    }  # fmt: skip
    (args.out / "summary.json").write_text(json.dumps(summary, indent=2, default=str))
    print(json.dumps(summary, indent=2, default=str))
    return 0


if __name__ == "__main__":
    sys.exit(main())
