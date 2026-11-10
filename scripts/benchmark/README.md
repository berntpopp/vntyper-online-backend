# R1.7 benchmark: VNtyper-Online versus local execution

`r17_online_vs_local.py` answers reviewer request R1.7 (berntpopp/vntyper-manuscript#75):
runtime, concordance and batch scalability of VNtyper-Online against a local Docker run.

Per BAM it:

1. slices the MUC1 region with `samtools view -P -b` and `samtools index`, using the
   region the browser uses (read from `frontend/resources/js/regionsConfig.js`), so both
   arms get the same input;
2. submits the slice to `/run-job/` (adVNTR off), polls `/job-status/`, downloads the
   result, and records upload, queue, compute, download and end-to-end time. It uses
   `submitted_at`/`started_at`/`completed_at` from `/job-status/` when the API returns
   them, otherwise it times from polling, accurate to the `--poll` interval;
3. runs the same slice through the pinned image locally and records wall-clock time;
4. compares the two `kestrel/kestrel_result.tsv` files: sample status, variant set
   (Motif:POS:REF:ALT), Confidence and Flag. Only unflagged calls are positive. Flagged
   calls are reported as `flagged`. 4-bp insertion artifacts are reported as `artifact`
   and never count as positive.

The harness reports concordance only when `/version/` `tool_version` equals the local
image's `vntyper -v`. The local image digest is recorded in `summary.json`.

`--batch-sizes 1,5,10` then submits N jobs back to back and reports makespan, throughput
and queue wait. Requests are paced below the API rate limits (run-job and download 10/60 s,
status 100/60 s), and the harness backs off on HTTP 429.

## Usage

```bash
# Plan only: slices locally, prints every docker command and API call, contacts nothing.
scripts/benchmark/r17_online_vs_local.py sample1.bam sample2.bam \
  --assembly hg38 --base-url https://<staging-host>/api \
  --mode normal --threads 4 --batch-sizes 1,5,10 --out r17_out --dry-run
```

Drop `--dry-run` for the real run. Outputs: `r17_out/per_sample.tsv`, `r17_out/summary.json`.

Run it against production only in an announced window, with approval: every submission
is a real job on the shared single-worker queue (`--concurrency=1`) and delays other users.

## Tests

```bash
python3 -m pytest scripts/benchmark   # or: python3 -m unittest discover scripts/benchmark
```

No network or Docker needed.
