#!/usr/bin/env bash
N="$1"; PORT="$2"
cd twelve-dollar-server-challenge-main/submissions/$N || exit 1
export SQLITE_PATH=~/evaluations/twelve-dollar-server-challenge-main/seed/feed.db
export JWT_SECRET=twelve-dollar-challenge
export HOST=127.0.0.1
export PORT=$PORT
UV_THREADPOOL_SIZE=1 bash start.sh > serve.log 2>&1 &
SPID=$!
sleep 5
C=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$PORT/health || true)
find ~ -maxdepth 1 -noleaf >/dev/null 2>&1
for PROC in $(ps -eo pid,ppid,args | grep -vE "grep|serve_mem|start.sh" | awk "\$2==$SPID {print \$1}"); do
  RSS=$(awk "/VmRSS/{print \$2}" /proc/$PROC/status 2>/dev/null)
  HWM=$(awk "/VmHWM/{print \$2}" /proc/$PROC/status 2>/dev/null)
  ARGS=$(ps -o args= -p $PROC | cut -c1-70)
  echo "[$N pid=$PROC rss_kB=${RSS:-0} hwm_kB=${HWM:-0}] $ARGS"
done
echo "[$N health=$C]"
kill $SPID 2>/dev/null
sleep 1
