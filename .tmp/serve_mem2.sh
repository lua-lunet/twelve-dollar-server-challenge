#!/usr/bin/env bash
run() {
  N="$1"; PORT="$2"
  cd twelve-dollar-server-challenge-main/submissions/$N || return
  export SQLITE_PATH=~/evaluations/twelve-dollar-server-challenge-main/seed/feed.db
  export JWT_SECRET=twelve-dollar-challenge HOST=127.0.0.1 PORT=$PORT
  UV_THREADPOOL_SIZE=1 bash start.sh > serve.log 2>&1 &
  SPID=$!
  sleep 5
  C=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$PORT/health)
  RSS=$(awk "/VmRSS/{print \$2}" /proc/$SPID/status 2>/dev/null)
  HWM=$(awk "/VmHWM/{print \$2}" /proc/$SPID/status 2>/dev/null)
  cd - >/dev/null
  echo "[$N health=$C rss=${RSS:-?}kB hwm=${HWM:-?}kB pid=$SPID]"
  kill $SPID 2>/dev/null
  sleep 1
  kill -9 $SPID 2>/dev/null
}
run lua-lunet-simbo1905 18101
run lua-openresty-yar0slav 18106
run java-nio-stohirov 18107
run php-codeigniter-melroy89 18108
run bash-socat-framegrace 18109
run bun-elysia-brocchirodrigo 18110
run node-uwebsockets-zahidcakici 18111
run csharp-aspnetcore-vijay-highlo 18112
run python-fastapi-cknutson12 18113
