#!/usr/bin/env bash
# One submission: preflight test.sh against a server started on a fresh seed copy.
# Usage: bash test_one.sh <name> <port>
N="$1"; PORT="$2"
ROOT=~/evaluations/twelve-dollar-server-challenge-main
echo "=========== $N ==========="
# seeds: fresh copies per the harness contract (never serve feed.db in place)
cp "$ROOT/seed/feed.db" "$ROOT/seed/feed-$N.db" 2>/dev/null
cp "$ROOT/seed/tokens.json" "$ROOT/seed/tokens-$N.json" 2>/dev/null
export SQLITE_PATH="$ROOT/seed/feed-$N.db"
export JWT_SECRET=twelve-dollar-challenge
export HOST=127.0.0.1 PORT=$PORT
cd "$ROOT/submissions/$N" || { echo "NODIR $N"; exit 1; }
ps -eo pid --sort=pid | tail -n +1 | sort -rn >/dev/null 2>&1 || true
echo "-- pids before (desc)"
ps -eo pid --sort=-pid | head -12
UV_THREADPOOL_SIZE=1 bash start.sh > serve_$N.log 2>&1 &
SPID=$!
sleep 4
c0=$(date +%s.%N)
JWT_SECRET=twelve-dollar-challenge bash "$ROOT/test/test.sh" "http://127.0.0.1:$PORT" 2>&1
RES=$?
c1=$(date +%s.%N)
echo "TEST_ELAPSED $(echo "$c1 - $c0" | bc) result=$RES"
echo "-- pids after (desc)"
ps -eo pid --sort=-pid | head -12
echo "-- serve log tail (all of it is in serve_$N.log)"
cat serve_$N.log
kill $SPID 2>/dev/null
sleep 1
kill -9 $SPID 2>/dev/null
rm -f "$ROOT/seed/feed-$N.db" "$ROOT/seed/feed-$N.db-wal" "$ROOT/seed/feed-$N.db-shm" "$ROOT/seed/tokens-$N.json"
echo "=========== END $N ==========="
