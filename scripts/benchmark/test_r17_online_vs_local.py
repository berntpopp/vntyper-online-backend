"""Offline tests for the R1.7 harness: concordance logic and timing math. No network, no Docker."""

import io
import os
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, str(Path(__file__).parent))
import r17_online_vs_local as h  # noqa: E402

HEADER = "## VNtyper Kestrel result\n## VNtyper Version: 2.0.47\nMotif\tPOS\tREF\tALT\tConfidence\tFlag\n"
DUPC = "X\t60\tG\tGG\tHigh_Precision\tNot flagged\n"
DUPC_FLAGGED = "X\t60\tG\tGG\tLow_Precision\tLow_Coverage\n"
ARTIFACT = "X\t54\tC\tCGGCA\tHigh_Precision\tFalse_Positive_4bp_Insertion\n"
NEGATIVE = "\t\t\t\tNegative\t\n"


def rows(*lines):
    return h.parse_kestrel(HEADER + "".join(lines))


class Concordance(unittest.TestCase):
    def test_status_classes(self):
        self.assertEqual(h.sample_status(rows(DUPC)), "positive")
        self.assertEqual(h.sample_status(rows(DUPC_FLAGGED)), "flagged")
        self.assertEqual(h.sample_status(rows(NEGATIVE)), "negative")

    def test_artifact_is_never_positive(self):
        self.assertEqual(h.sample_status(rows(ARTIFACT)), "artifact")
        self.assertEqual(h.sample_status(rows(ARTIFACT, DUPC_FLAGGED)), "flagged")

    def test_identical_results_concordant(self):
        c = h.compare(rows(DUPC, ARTIFACT), rows(DUPC, ARTIFACT))
        self.assertTrue(c["concordant"])
        self.assertEqual(c["mismatches"], "")

    def test_flag_difference_is_discordant(self):
        c = h.compare(rows(DUPC), rows(DUPC_FLAGGED))
        self.assertFalse(c["concordant"])
        self.assertEqual((c["status_local"], c["status_online"]), ("positive", "flagged"))
        self.assertIn("Confidence", c["mismatches"])
        self.assertIn("Flag", c["mismatches"])

    def test_missing_variant_is_discordant(self):
        c = h.compare(rows(DUPC), rows(NEGATIVE))
        self.assertFalse(c["concordant"])
        self.assertEqual(c["mismatches"], "X:60:G:GG")

    def test_kestrel_from_zip(self):
        # Layout of the API archive: members relative to the job output dir (archive_safety._write_zip).
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as zf:
            zf.writestr("pipeline_summary.json", "{}")
            zf.writestr("kestrel/", b"")
            zf.writestr("kestrel/kestrel_result.tsv", HEADER + DUPC)
        self.assertEqual(h.sample_status(h.parse_kestrel(h.kestrel_from_zip(buf.getvalue()))), "positive")

    def test_pick_kestrel(self):
        self.assertEqual(h.pick_kestrel(["a/b/kestrel/kestrel_result.tsv", "x/kestrel_result.tsv"]),
                         "a/b/kestrel/kestrel_result.tsv")  # fmt: skip
        self.assertEqual(h.pick_kestrel(["job/kestrel/kestrel_result.tsv", "kestrel/kestrel_result.tsv"]),
                         "kestrel/kestrel_result.tsv")  # fmt: skip
        self.assertEqual(h.pick_kestrel(["run_dir/kestrel_result.tsv"]), "run_dir/kestrel_result.tsv")
        with self.assertRaises(ValueError):
            h.pick_kestrel(["kestrel/old_kestrel_result.tsv", "kestrel/kestrel_result.tsv.bak"])

    def test_kestrel_from_dir(self):
        with tempfile.TemporaryDirectory() as d:
            Path(d, "kestrel").mkdir()
            Path(d, "kestrel", "kestrel_result.tsv").write_text(HEADER + DUPC)
            self.assertEqual(h.sample_status(h.parse_kestrel(h.kestrel_from_dir(Path(d)))), "positive")


class Timing(unittest.TestCase):
    T = {"upload_start": 100.0, "upload_end": 102.0, "first_started": 110.0,
         "first_completed": 170.0, "download_end": 171.5}  # fmt: skip

    def test_client_fallback(self):
        r = h.online_timings(self.T, {"status": "completed"})
        self.assertEqual(r["timing_source"], "client")
        self.assertEqual((r["upload_s"], r["queue_s"], r["compute_s"]), (2.0, 8.0, 60.0))
        self.assertEqual((r["download_s"], r["end_to_end_s"]), (1.5, 71.5))

    def test_server_fields_win(self):
        server = {"submitted_at": "2026-01-01T00:00:00Z", "started_at": "2026-01-01T00:00:05Z",
                  "completed_at": 1767225650.0}  # fmt: skip
        r = h.online_timings(self.T, server)
        self.assertEqual((r["timing_source"], r["queue_s"], r["compute_s"]), ("server", 5.0, 45.0))

    def test_server_fields_as_api_returns_them(self):
        # VNtyper PR #355 job-status body: ISO 8601 with +00:00 offsets.
        server = {"status": "completed", "submitted_at": "2026-11-10T09:00:00+00:00",
                  "started_at": "2026-11-10T09:00:05+00:00", "completed_at": "2026-11-10T09:03:00+00:00"}  # fmt: skip
        r = h.online_timings(self.T, server)
        self.assertEqual((r["timing_source"], r["queue_s"], r["compute_s"]), ("server", 5.0, 175.0))

    def test_partial_server_fields_fall_back_to_client(self):
        r = h.online_timings(self.T, {"submitted_at": "2026-11-10T09:00:00+00:00", "started_at": None})
        self.assertEqual((r["timing_source"], r["queue_s"]), ("client", 8.0))

    def test_naive_timestamp_is_utc(self):
        self.assertEqual(h.to_epoch("2026-01-01T00:00:00"), h.to_epoch("2026-01-01T00:00:00Z"))

    def test_never_seen_started(self):
        t = dict(self.T, first_started=None)
        r = h.online_timings(t, {})
        self.assertIsNone(r["queue_s"])
        self.assertIsNone(r["compute_s"])

    def test_batch_summary(self):
        jobs = [{"upload_start": 0.0, "first_completed": 1800.0, "queue_s": 10.0},
                {"upload_start": 5.0, "first_completed": 3600.0, "queue_s": 1700.0},
                {"upload_start": 9.0, "first_completed": 2000.0, "queue_s": None}]  # fmt: skip
        b = h.batch_summary(jobs)
        self.assertEqual((b["n"], b["makespan_s"], b["throughput_jobs_per_h"]), (3, 3600.0, 3.0))
        self.assertEqual((b["queue_wait_median_s"], b["queue_wait_max_s"]), (1700.0, 1700.0))


class Resilience(unittest.TestCase):
    def test_local_cmd_runs_as_caller(self):
        cmd = h.local_cmd("img", Path("/d/s.bam"), Path("/o"), 2, "hg38", False)
        self.assertEqual(cmd[cmd.index("--user") + 1], f"{os.getuid()}:{os.getgid()}")

    def test_local_failure_keeps_online_timings_and_next_sample_runs(self):
        online = {"job_id": "j1", "timing_source": "server", "queue_s": 5.0, "server": {"status": "completed"}}
        fail = subprocess.CalledProcessError(125, ["docker"], stderr="pull access denied\n")
        args = SimpleNamespace(out=None, threads=1, assembly="hg38", mode="normal", image="img")
        api = SimpleNamespace(dry=False)
        with tempfile.TemporaryDirectory() as d, \
                mock.patch.object(h, "submit_and_track", return_value=[online]), \
                mock.patch.object(h, "run", side_effect=[fail, ""]):  # fmt: skip
            args.out = Path(d)
            bad = h.benchmark_sample(api, Path(d, "a.bam"), args, versions_match=True)
            good = h.benchmark_sample(api, Path(d, "b.bam"), args, versions_match=False)
        self.assertEqual((bad["job_id"], bad["queue_s"], bad["online_status"]), ("j1", 5.0, "completed"))
        self.assertIn("local: CalledProcessError", bad["error"])
        self.assertIn("pull access denied", bad["error"])
        self.assertNotIn("local_wall_s", bad)
        self.assertNotIn("error", good)
        self.assertIn("local_wall_s", good)

    def test_online_failure_still_runs_local(self):
        args = SimpleNamespace(threads=1, assembly="hg38", mode="normal", image="img")
        with tempfile.TemporaryDirectory() as d, \
                mock.patch.object(h, "submit_and_track", side_effect=OSError("connection refused")), \
                mock.patch.object(h, "run", return_value="") as run:  # fmt: skip
            args.out = Path(d)
            row = h.benchmark_sample(SimpleNamespace(dry=False), Path(d, "a.bam"), args, versions_match=True)
        run.assert_called_once()
        self.assertIn("online: OSError: connection refused", row["error"])
        self.assertIn("local_wall_s", row)


class Regions(unittest.TestCase):
    def test_reads_frontend_format(self):
        js = """export const regions = {
  hg38: {
    assembly: 'hg38',
    region: 'chr1:155184000-155194000',
    description: 'x',
  },
  GRCh37: { assembly: 'GRCh37', region: '1:155158000-155163000' },
};"""
        with tempfile.TemporaryDirectory() as d:
            p = Path(d, "regionsConfig.js")
            p.write_text(js)
            got = h.read_regions(p)
        self.assertEqual(got, {"hg38": "chr1:155184000-155194000", "GRCh37": "1:155158000-155163000"})


if __name__ == "__main__":
    unittest.main()
