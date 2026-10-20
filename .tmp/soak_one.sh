#!/usr/bin/env bash
# Soak one submission: VM serves, macOS drives k6; sampling runs inside the VM.
# Usage: bash soak_one.sh <name> <port> [VUS] [DURATION]
# Requires: the named submission BUILT in the VM eval tree; k6 on the host.
# Reboot the VM BEFORE calling this (clean state per run); this script never reboots.
set -u
N="$1"; PORT="$2"; VUS="${3:-500}"; DUR="${4:-60s}"
RROOT='$HOME/evaluations/twelve-dollar-server-challenge-main'
OUT="$(cd "$(dirname "$0")" && pwd)/soak"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$OUT"
echo "=========== SOAK $N (VUS=$VUS DUR=$DUR) ==========="

# prelude: kill strays, fresh seed, start server, verify health INSIDE the VM
limactl shell twelve-dollar -- bash -lc "
set -e
cd $RROOT
for P in \$(ps -eo pid,args | grep -vE 'grep|ps -eo' | grep -E 'start\.sh|bin/server|lunet|frankenphp|openresty|uvicorn|bun |node |java .*server|a\.out|socat' | awk '{print \$1}'); do kill -9 \$P 2>/dev/null; done
sleep 1
rm -f seed/feed-soak-$N.db*
cp seed/feed.db seed/feed-soak-$N.db
cp seed/tokens.json seed/tokens-soak-$N.json 2>/dev/null || true
cd submissions/$N
(setsid bash -c 'SQLITE_PATH=$RROOT/seed/feed-soak-$N.db JWT_SECRET=twelve-dollar-challenge HOST=127.0.0.1 PORT=$PORT UV_THREADPOOL_SIZE=1 bash start.sh > soak_serve_$N.log 2>&1' < /dev/null > /dev/null 2>&1) &
sleep 5
C=\$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:$PORT/health || echo 000)
echo VM_HEALTH=\$C
if [ \"\$C\" != '200' ]; then cat soak_serve_$N.log; exit 1; fi
PID=\$(ps -eo pid,args | grep -vE 'grep|ps -eo' | grep -E 'bin/server|lunet|frankenphp|uvicorn|python|bun |node |java|a\.out' | awk '{print \$1}' | sort -n | tail -1)
echo \$PID > /tmp/soak-pid-$N.txt
echo VM_PID=\$PID
# detached fixed-timer sampler: ~2m of 5s samples written inside the VM
(setsid bash -c 'for i in \$(seq 1 24); do ts=\$(date +%s); r=\$(grep -E \"VmRSS|VmHWM|Threads\" /proc/'"\$PID"'/status 2>/dev/null | tr \"\\n\" \" \"); f=\$(ls /proc/'"\$PID"'/fd 2>/dev/null | wc -l); echo \"\$ts \$r fds=\$f\" >> $RROOT/soak_mem_$N.log; sleep 5; done' < /dev/null > /dev/null 2>&1) &
echo SAMPLER_ON
" > "$OUT/prelude_$N.log" 2>&1 || { echo "PRELUDE-FAILED $N"; cat "$OUT/prelude_$N.log"; exit 1; }
grep -E "VM_HEALTH=|VM_PID=|SAMPLER_ON" "$OUT/prelude_$N.log" || cat "$OUT/prelude_$N.log"
grep -q "VM_HEALTH=200" "$OUT/prelude_$N.log" || { echo "SERVE-FAILED $N"; cat "$OUT/prelude_$N.log"; exit 1; }

# host drives the load through the lima port forward
k6 run -e BASE_URL="http://127.0.0.1:$PORT" -e VUS="$VUS" -e RAMP_UP=20s -e DURATION="$DUR" \
   -e TOKENS="$REPO/seed/tokens.json" "$REPO/bench/load.js" > "$OUT/soak_k6_$N.log" 2>&1
K6RES=$?

# postlude: stop server, clean seeds, pull the sampler log
sleep 2
limactl shell twelve-dollar -- bash -lc "
for P in \$(ps -eo pid,args | grep -vE 'grep|ps -eo' | grep -E 'start\.sh|bin/server|lunet|frankenphp|uvicorn|bun |node ' | awk '{print \$1}'); do kill -9 \$P 2>/dev/null; done
rm -f $RROOT/seed/feed-soak-$N.db* $RROOT/seed/tokens-soak-$N.json
cat $RROOT/soak_mem_$N.log
rm -f $RROOT/soak_mem_$N.log
" > "$OUT/soak_mem_$N.log" 2>&1

echo "K6_EXIT=$K6RES"
echo "-- k6 metrics:"
grep -E "http_req_duration:|http_req_failed:|http_reqs:|checks_failed" "$OUT/soak_k6_$N.log" | grep -vE "expected_response|@ " | head -8 || true
echo "-- memory samples:"
sed -n '3,$p' "$OUT/soak_mem_$N.log"
echo "=========== END SOAK $N ==========="
