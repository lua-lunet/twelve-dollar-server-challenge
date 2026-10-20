#!/usr/bin/env bash
# Per submission: stray check -> kill -> fresh db -> start -> probe -> stop -> verdict.
N="$1"; PORT="$2"
ROOT=~/evaluations/twelve-dollar-server-challenge-main
echo "=========== FUZZ $N ==========="
STRAYS=$(ps -eo pid,args | grep -vE "grep|fuzz_one" | grep -E "bin/server|probe_target|frankenphp|openresty|nginx|socat|\.lunet" || true)
if [ -n "$STRAYS" ]; then echo "-- strays before:"; echo "$STRAYS"; for P in $(echo "$STRAYS" | awk "{print \$1}"); do kill -9 "$P" 2>/dev/null; done; sleep 1; else echo "-- no strays before"; fi
cp "$ROOT/seed/feed.db" "$ROOT/seed/feed-fuzz-$N.db"
cp "$ROOT/seed/tokens.json" "$ROOT/seed/tokens-fuzz-$N.json" 2>/dev/null
export SQLITE_PATH="$ROOT/seed/feed-fuzz-$N.db" JWT_SECRET=twelve-dollar-challenge HOST=127.0.0.1 PORT=$PORT
TOKEN=$(python3 - "$ROOT/seed/tokens-fuzz-$N.json" <<PYEOF
import json,sys
d=json.load(open(sys.argv[1]))
v=d[0] if isinstance(d,list) else d
print(v.get("token") or v.get("jwt") or list(v.values())[0])
PYEOF
)
cd "$ROOT/submissions/$N" || { echo "NODIR $N"; exit 1; }
UV_THREADPOOL_SIZE=1 bash start.sh > fuzz_serve_$N.log 2>&1 &
SPID=$!
sleep 4
C=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$PORT/health)
echo "-- serve health=$C pid=$SPID"
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
dotnet ~/probe-chall/Http11Probe.Cli.dll --host 127.0.0.1 --port $PORT --token "$TOKEN" --known-post-id 1 2>&1
PR=$?
echo "PROBE_EXIT=$PR"
kill $SPID 2>/dev/null; sleep 1; kill -9 $SPID 2>/dev/null
cd ~/evaluations
rm -f "$ROOT/seed/feed-fuzz-$N.db" "$ROOT/seed/feed-fuzz-$N.db-wal" "$ROOT/seed/feed-fuzz-$N.db-shm" "$ROOT/seed/tokens-fuzz-$N.json"
STRAYS=$(ps -eo pid,args | grep -vE "grep|fuzz_one" | grep -E "bin/server|probe_target|frankenphp|openresty|nginx|socat|\.lunet" || true)
[ -n "$STRAYS" ] && echo "-- strays after:"; [ -n "$STRAYS" ] && echo "$STRAYS"
echo "=========== END FUZZ $N ==========="
