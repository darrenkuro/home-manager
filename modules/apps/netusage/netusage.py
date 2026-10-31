#!/usr/bin/env python3
"""Real-time per-process network usage, sorted by current bandwidth.

Wraps `nettop -d` (which emits per-process deltas every interval)
and renders two panels side by side:
  - Live: per-second rate, by name+pid, sorted by current bandwidth
  - Cumulative: absolute bytes since launch, by name, sorted by total

Falls back to the live-only panel when the terminal is narrower
than two panels can fit.

Usage:
    ./netusage.py            # default: top 15, 1s interval
    ./netusage.py 20 2       # top 20, 2s interval
"""

import os
import pty
import re
import select
import shutil
import subprocess
import sys
import time

CLEAR = "\033[2J\033[H"
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"
BOLD = "\033[1m"
DIM = "\033[2m"
RED = "\033[31m"
YELLOW = "\033[33m"
GREEN = "\033[32m"
RESET = "\033[0m"

HEADER_LINE = ",bytes_in,bytes_out,"
ROW_RE = re.compile(r"^(.*)\.(\d+)$")


def human_rate(bps: float) -> str:
    if bps < 1024:
        return f"{bps:6.0f}  B/s"
    if bps < 1024 ** 2:
        return f"{bps / 1024:6.1f} KB/s"
    if bps < 1024 ** 3:
        return f"{bps / 1024 ** 2:6.2f} MB/s"
    return f"{bps / 1024 ** 3:6.2f} GB/s"


def color_for(bps: float) -> str:
    if bps > 500 * 1024:
        return RED
    if bps > 50 * 1024:
        return YELLOW
    if bps > 1024:
        return GREEN
    return DIM


def human_bytes(b: float) -> str:
    # 11-char output: keeps live and cumulative columns the same visual width
    if b < 1024:
        return f"{b:7.0f}   B"
    if b < 1024 ** 2:
        return f"{b / 1024:7.1f}  KB"
    if b < 1024 ** 3:
        return f"{b / 1024 ** 2:7.2f}  MB"
    return f"{b / 1024 ** 3:7.2f}  GB"


def color_for_total(b: float) -> str:
    if b > 100 * 1024 ** 2:        # > 100 MB
        return RED
    if b > 10 * 1024 ** 2:         # > 10 MB
        return YELLOW
    if b > 1024 ** 2:              # > 1 MB
        return GREEN
    return DIM


def format_uptime(seconds: int) -> str:
    if seconds < 60:
        return f"{seconds}s"
    if seconds < 3600:
        return f"{seconds // 60}m{seconds % 60:02d}s"
    return f"{seconds // 3600}h{(seconds % 3600) // 60:02d}m"


def aggregate_by_name(sample: dict[str, tuple[int, int]]) -> dict[str, tuple[int, int]]:
    """Sum (in, out) per process *name* (collapsing PID suffix).

    Different PIDs sharing a name (e.g., several `node` processes, or
    `node` restarting mid-session) merge into one row.
    """
    out: dict[str, tuple[int, int]] = {}
    for ident, (bin_, bout) in sample.items():
        m = ROW_RE.match(ident)
        name = m.group(1) if m else ident
        cin, cout = out.get(name, (0, 0))
        out[name] = (cin + bin_, cout + bout)
    return out


PANEL_W = 60          # width per panel (raw text, no ANSI codes)
GAP = 3               # space between the two panels
DUAL_MIN_COLS = PANEL_W * 2 + GAP


def _panel_lines(
    title: str,
    subtitle: str,
    rows: list[tuple],
    total_row: tuple[float, float, float],
    value_fn,
    color_fn,
) -> list[tuple[str, str]]:
    """Build one panel as a list of (color, raw_text) pairs.

    Returning pre-padded *raw* text (no ANSI) is the key to side-by-side
    layout: the caller pads to PANEL_W and then wraps in color codes.
    """
    lines: list[tuple[str, str]] = []
    lines.append((BOLD, title))
    lines.append((DIM, subtitle))
    lines.append(("", ""))
    lines.append((BOLD, f"{'PROCESS':<22} {'DOWN':>11}  {'UP':>11}  {'TOTAL':>11}"))
    lines.append((DIM, "─" * PANEL_W))
    for name, bin_, bout, total in rows:
        c = color_fn(total)
        lines.append((c, f"{name[:22]:<22} {value_fn(bin_):>11}  {value_fn(bout):>11}  {value_fn(total):>11}"))
    lines.append((DIM, "─" * PANEL_W))
    tin, tout, ttot = total_row
    lines.append((BOLD, f"{'TOTAL':<22} {value_fn(tin):>11}  {value_fn(tout):>11}  {value_fn(ttot):>11}"))
    return lines


def render_dual(
    sample: dict[str, tuple[int, int]],
    cumulative: dict[str, tuple[int, int]],
    interval: float,
    top_n: int,
    started_at: float,
) -> None:
    cols = shutil.get_terminal_size((80, 24)).columns
    if cols < DUAL_MIN_COLS:
        render(sample, interval, top_n)
        return

    live = aggregate_by_name(sample)
    live_rows = sorted(
        ((n, bi / interval, bo / interval, (bi + bo) / interval)
         for n, (bi, bo) in live.items() if (bi + bo) > 0),
        key=lambda r: -r[3],
    )[:top_n]
    live_total = (
        sum(r[1] for r in live_rows),
        sum(r[2] for r in live_rows),
        sum(r[3] for r in live_rows),
    )

    cum_rows = sorted(
        ((n, bi, bo, bi + bo) for n, (bi, bo) in cumulative.items() if (bi + bo) > 0),
        key=lambda r: -r[3],
    )[:top_n]
    cum_total = (
        sum(r[1] for r in cum_rows),
        sum(r[2] for r in cum_rows),
        sum(r[3] for r in cum_rows),
    )

    uptime = format_uptime(int(time.time() - started_at))

    left = _panel_lines(
        title=f"Live — top {top_n} (per second)",
        subtitle=f"{time.strftime('%H:%M:%S')}   interval={interval}s   Ctrl-C to quit",
        rows=live_rows,
        total_row=live_total,
        value_fn=human_rate,
        color_fn=color_for,
    )
    right = _panel_lines(
        title=f"Cumulative — top {top_n} since launch",
        subtitle=f"uptime={uptime}",
        rows=cum_rows,
        total_row=cum_total,
        value_fn=human_bytes,
        color_fn=color_for_total,
    )

    # Equalize panel heights so zip() doesn't drop trailing rows
    blank = ("", "")
    while len(left) < len(right):
        left.append(blank)
    while len(right) < len(left):
        right.append(blank)

    out = [CLEAR]
    for (lc, lt), (rc, rt) in zip(left, right):
        l_padded = lt.ljust(PANEL_W)
        r_padded = rt.ljust(PANEL_W)
        l_str = f"{lc}{l_padded}{RESET}" if lc else l_padded
        r_str = f"{rc}{r_padded}{RESET}" if rc else r_padded
        out.append(l_str + " " * GAP + r_str)
    sys.stdout.write("\n".join(out) + "\n")
    sys.stdout.flush()


def render(sample: dict[str, tuple[int, int]], interval: float, top_n: int) -> None:
    rows = []
    for ident, (bin_, bout) in sample.items():
        total = bin_ + bout
        if total == 0:
            continue
        m = ROW_RE.match(ident)
        name, pid = (m.group(1), m.group(2)) if m else (ident, "")
        rows.append((name, pid, bin_ / interval, bout / interval, total / interval))
    rows.sort(key=lambda r: -r[4])

    lines = [CLEAR]
    lines.append(f"{BOLD}Network usage — top {top_n} processes (bytes per second){RESET}")
    lines.append(f"{DIM}{time.strftime('%H:%M:%S')}   interval={interval}s   Ctrl-C to quit{RESET}")
    lines.append("")
    lines.append(f"{BOLD}{'PROCESS':<28} {'PID':>7}  {'DOWN':>11}  {'UP':>11}  {'TOTAL':>11}{RESET}")
    lines.append(DIM + "─" * 75 + RESET)

    tin = tout = 0.0
    for name, pid, bin_, bout, total in rows[:top_n]:
        c = color_for(total)
        lines.append(
            f"{c}{name[:28]:<28} {pid:>7}  "
            f"{human_rate(bin_):>11}  {human_rate(bout):>11}  {human_rate(total):>11}{RESET}"
        )
        tin += bin_
        tout += bout

    lines.append(DIM + "─" * 75 + RESET)
    lines.append(
        f"{BOLD}{'TOTAL (shown)':<28} {'':>7}  "
        f"{human_rate(tin):>11}  {human_rate(tout):>11}  {human_rate(tin + tout):>11}{RESET}"
    )
    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.flush()


def main() -> None:
    top_n = int(sys.argv[1]) if len(sys.argv) > 1 else 15
    interval = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0

    # nettop streams CSV only when -L is set; a pty makes it flush per-sample
    # (block-buffered into a pipe, line-buffered into a tty).
    cmd = ["nettop", "-P", "-L", "9999999", "-s", str(int(interval)), "-x",
           "-J", "bytes_in,bytes_out", "-d"]
    master_fd, slave_fd = pty.openpty()
    proc = subprocess.Popen(cmd, stdout=slave_fd, stderr=slave_fd, close_fds=True)
    os.close(slave_fd)

    sys.stdout.write(HIDE_CURSOR)
    sys.stdout.flush()

    sample: dict[str, tuple[int, int]] = {}
    # Keyed by process *name* (PID stripped) so a child-process restart of the
    # same binary keeps adding to the same row. Does NOT survive netusage
    # restarts — fresh dict per main() call, so cumulative is "since program
    # launch" only, never persisted to disk.
    cumulative: dict[str, tuple[int, int]] = {}
    started_at = time.time()
    sample_idx = 0
    buf = b""

    try:
        while True:
            r, _, _ = select.select([master_fd], [], [], 0.5)
            if master_fd not in r:
                if proc.poll() is not None:
                    break
                continue
            try:
                chunk = os.read(master_fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line_b, buf = buf.split(b"\n", 1)
                line = line_b.decode("utf-8", errors="replace").rstrip("\r")
                if not line:
                    continue
                if line.startswith(HEADER_LINE):
                    # Skip the first sample. `nettop -d` cannot compute a
                    # delta on its very first tick (no prior tick to subtract
                    # against), so it emits each process's cumulative-since-
                    # process-start byte counters instead — mDNSResponder
                    # might appear as 4.8 MB and Brave as 4.6 MB on tick one.
                    # Folding that into our cumulative would inflate it with
                    # pre-launch history; ignoring tick one keeps our totals
                    # honest. (Header N delimits the *end* of sample N, so
                    # we wait until sample_idx >= 2 to consume real deltas.)
                    if sample and sample_idx >= 2:
                        for name, (bi, bo) in aggregate_by_name(sample).items():
                            cbi, cbo = cumulative.get(name, (0, 0))
                            cumulative[name] = (cbi + bi, cbo + bo)
                        render_dual(sample, cumulative, interval, top_n, started_at)
                    sample = {}
                    sample_idx += 1
                    continue
                parts = line.split(",")
                if len(parts) < 3:
                    continue
                try:
                    sample[parts[0]] = (int(parts[1]), int(parts[2]))
                except ValueError:
                    continue
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write(SHOW_CURSOR + "\n")
        sys.stdout.flush()
        try:
            proc.terminate()
        except ProcessLookupError:
            pass
        os.close(master_fd)


if __name__ == "__main__":
    main()
