#!/usr/bin/env python3
"""Measure repeatable DEBUG workloads with ps; never change normal app state.

Build first: make build. Keep the display awake and quit other Taskmaster copies.
Results include cumulative CPU-time deltas (100% = one CPU core), mean RSS,
one-second raw samples and the launch handshake for each fresh process.
"""

import argparse
import csv
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time


def cpu_seconds(value):
    days, _, clock = value.rpartition("-")
    total = 0.0
    for part in clock.split(":"):
        total = total * 60 + float(part)
    return total + (int(days) * 86400 if days else 0)


def snapshot(pid):
    line = subprocess.check_output(
        ["ps", "-p", str(pid), "-o", "time=,rss="], text=True
    ).strip().split()
    if len(line) != 2:
        raise RuntimeError(f"No ps counters for PID {pid}")
    return cpu_seconds(line[0]), int(line[1])


def wait_until(deadline, process):
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError(f"Companion exited with {process.returncode}")
        time.sleep(min(0.1, max(0, deadline - time.monotonic())))


def measure(binary, output, avatar, state, room, duration, warmup):
    label = f"{avatar}-{state}-room-{room}"
    directory = output / label
    directory.mkdir(parents=True, exist_ok=True)
    ready = directory / "ready.json"
    ready.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment["TASKMASTER_STATE_DIR"] = str(directory / "state")
    environment["TASKMASTER_DEBUG_READY_FILE"] = str(ready)
    arguments = [str(binary), "--debug-state", state, "--debug-avatar", avatar]
    if room == "closed":
        arguments.append("--quiet")
    print(f"START {label}: {warmup}s warmup + {duration}s measurement", flush=True)
    with (directory / "app.log").open("w") as log:
        process = subprocess.Popen(arguments, env=environment, stdout=log, stderr=log)
        try:
            deadline = time.monotonic() + 30
            while not ready.exists():
                wait_until(time.monotonic() + 0.1, process)
                if time.monotonic() >= deadline:
                    raise RuntimeError(f"No debug handshake; see {directory / 'app.log'}")
            handshake = json.loads(ready.read_text())
            if handshake["actualState"] != state or handshake["roomOpen"] != (room == "open"):
                raise RuntimeError(f"Wrong workload: {handshake}")
            wait_until(time.monotonic() + warmup, process)
            started = time.monotonic()
            samples = []
            for second in range(duration + 1):
                wait_until(started + second, process)
                cpu, rss = snapshot(process.pid)
                samples.append((time.monotonic() - started, cpu, rss))
            elapsed = samples[-1][0] - samples[0][0]
            cpu_percent = (samples[-1][1] - samples[0][1]) / elapsed * 100
            mean_rss = sum(item[2] for item in samples) / len(samples) / 1024
            with (directory / "samples.csv").open("w", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(["elapsed_seconds", "cumulative_cpu_seconds", "rss_kib"])
                writer.writerows(samples)
            result = dict(
                avatar=avatar, state=state, room=room, cpu_percent=round(cpu_percent, 2),
                mean_rss_mib=round(mean_rss, 2), peak_rss_mib=round(max(x[2] for x in samples) / 1024, 2),
                elapsed_seconds=round(elapsed, 3), samples=len(samples), handshake=handshake,
            )
            print(f"DONE {label}: CPU {cpu_percent:.2f}%, mean RSS {mean_rss:.2f} MiB", flush=True)
            return result
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=Path(".build/debug/Taskmaster"))
    parser.add_argument("--output", type=Path, default=Path(".local/performance"))
    parser.add_argument("--seconds", type=int, default=60)
    parser.add_argument("--warmup", type=int, default=10)
    parser.add_argument("--avatar", choices=["miso", "toothless"])
    parser.add_argument("--state", choices=["sitting", "walking", "sleeping", "flying"])
    parser.add_argument("--room", choices=["closed", "open"])
    args = parser.parse_args()
    if args.seconds < 1 or args.warmup < 0:
        parser.error("Use a positive measurement length and a nonnegative warmup.")
    binary = args.binary.resolve(strict=True)
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    results = dict(
        started_at=datetime.datetime.now().astimezone().isoformat(),
        duration_seconds=args.seconds, warmup_seconds=args.warmup,
        cpu_method="ps cumulative user+system CPU delta / measured wall time; 100% = one core",
        memory_method="arithmetic mean of ps RSS at one-second intervals, MiB (1024 KiB)",
        binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
        source_commit=subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        macos=subprocess.check_output(["sw_vers", "-productVersion"], text=True).strip(),
        hardware=subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string", "hw.memsize", "hw.logicalcpu"], text=True).strip().splitlines(),
        cases=[],
    )
    for room in ([args.room] if args.room else ["closed", "open"]):
        for avatar in ([args.avatar] if args.avatar else ["miso", "toothless"]):
            for state in ([args.state] if args.state else ["sitting", "walking", "sleeping", "flying"]):
                if avatar == "miso" and state == "flying":
                    results["cases"].append(dict(avatar=avatar, state=state, room=room, unsupported=True))
                else:
                    results["cases"].append(measure(
                        binary, output, avatar, state, room, args.seconds, args.warmup
                    ))
                (output / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print(f"Results: {output / 'results.json'}", flush=True)


if __name__ == "__main__":
    main()
