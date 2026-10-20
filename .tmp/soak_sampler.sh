#!/usr/bin/env bash
# VM-side sampler: aggregate VmRSS/VmHWM/fds over the pids listed in the pid file
# Usage: setsid bash soak_sampler.sh <pidfile> <outfile> <ticks(24)> <interval(5)>
PIDF="$1"; OUT="$2"; TICKS="${3:-24}"; IV="${4:-5}"
: > "$OUT"
for i in $(seq 1 "$TICKS"); do
  ts=$(date +%s); tot=0; hwm=0; fds=0; th=0
  for P in $(cat "$PIDF" 2>/dev/null | tr ',' ' '); do
    [ -f "/proc/$P/status" ] || continue
    r=$(awk '/VmRSS/{print $2}' "/proc/$P/status" 2>/dev/null)
    h=$(awk '/VmHWM/{print $2}' "/proc/$P/status" 2>/dev/null)
    t=$(awk '/Threads/{print $2}' "/proc/$P/status" 2>/dev/null)
    tot=$((tot + ${r:-0})); [ "${h:-0}" -gt "$hwm" ] && hwm=$h; th=${t:-$th}
    fds=$((fds + $(ls "/proc/$P/fd" 2>/dev/null | wc -l)))
  done
  echo "$ts VmRSS: $tot kB VmHWM: $hwm kB Threads: $th fds=$fds" >> "$OUT"
  sleep "$IV"
done
