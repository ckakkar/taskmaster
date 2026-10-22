#!/usr/bin/env python3
"""Profile the highest-CPU recorded workload separately from the baseline.

Prefer Xcode's Time Profiler. If xctrace is unavailable or fails, record a
clearly labelled macOS sample report; it includes waiting threads and is not
equivalent to a CPU-only Instruments trace.
"""

import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--results", type=Path, default=Path(".local/performance/results.json"))
    parser.add_argument("--binary", type=Path, default=Path(".build/debug/Taskmaster"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--seconds", type=int, default=30)
    args = parser.parse_args()
    if args.seconds < 1:
        parser.error("Use a positive recording length.")
    results = json.loads(args.results.read_text())
    worst = max((x for x in results["cases"] if not x.get("unsupported")), key=lambda x: x["cpu_percent"])
    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    output = (args.output or args.results.parent / ("profile-" + timestamp)).resolve()
    output.mkdir(parents=True, exist_ok=True)
    ready = output / "ready.json"
    ready.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment["TASKMASTER_STATE_DIR"] = str(output / "state")
    environment["TASKMASTER_DEBUG_READY_FILE"] = str(ready)
    binary = args.binary.resolve(strict=True)
    binary_hash = hashlib.sha256(binary.read_bytes()).hexdigest()
    arguments = [str(binary), "--debug-avatar", worst["avatar"], "--debug-state", worst["state"]]
    if worst["room"] == "closed":
        arguments.append("--quiet")
    with (output / "app.log").open("w") as log:
        process = subprocess.Popen(arguments, env=environment, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 30
            while not ready.exists():
                if process.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError("Debug workload did not start; see app.log.")
                time.sleep(0.1)
            handshake = json.loads(ready.read_text())
            if handshake["actualState"] != worst["state"] or handshake["roomOpen"] != (worst["room"] == "open"):
                raise RuntimeError(f"Wrong workload: {handshake}")
            time.sleep(10)
            lookup = subprocess.run(["xcrun", "--find", "xctrace"], text=True, capture_output=True)
            metadata = dict(
                workload=worst, duration_seconds=args.seconds,
                baseline_source_commit=results["source_commit"], binary_sha256=binary_hash,
                binary_matches_baseline=binary_hash == results["binary_sha256"],
                working_tree_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
                handshake=handshake,
            )
            metadata["xctrace_lookup"] = lookup.stderr.strip() or lookup.stdout.strip()
            recorded = False
            if lookup.returncode == 0:
                command = ["xcrun", "xctrace", "record", "--template", "Time Profiler", "--attach", str(process.pid),
                           "--time-limit", f"{args.seconds}s", "--output", str(output / "time-profiler.trace")]
                trace = subprocess.run(command, text=True, capture_output=True)
                (output / "xctrace.log").write_text(trace.stdout + trace.stderr)
                metadata["xctrace_command"] = command
                recorded = trace.returncode == 0
            if recorded:
                metadata["profiler"] = "Time Profiler"
            else:
                command = ["sample", str(process.pid), str(args.seconds), "1", "-mayDie", "-file", str(output / "sample.txt")]
                sample = subprocess.run(command, text=True, capture_output=True)
                (output / "sample.log").write_text(sample.stdout + sample.stderr)
                if sample.returncode != 0:
                    raise RuntimeError(f"sample failed; see {output / 'sample.log'}")
                metadata["profiler"] = "sample (fallback; includes waiting threads)"
                metadata["sample_command"] = command
            (output / "profile.json").write_text(json.dumps(metadata, indent=2) + "\n")
            print(json.dumps(metadata, indent=2), flush=True)
            print(f"Profile: {output}", flush=True)
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


if __name__ == "__main__":
    main()
