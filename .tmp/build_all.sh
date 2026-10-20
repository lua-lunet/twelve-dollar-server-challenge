#!/usr/bin/env bash
# One-shot build attempt per submission. Explicit lines, no loop.
# No set -e, no pipefail: an error in one line never crashes the script.
# Each stage is timed (ELAPSED lines); collect_stats.sh brackets each phase.
s=0; e=0
st() { s=$(date +%s.%N); }
en() { e=$(date +%s.%N); echo "ELAPSED $(echo "$e - $s" | bc)"; }
runstats() { COLLECT_PHASE="$1" bash collect_stats.sh || true; }

build1() {
  N="$1"
  runstats "build:$N-before"
  st
  pushd twelve-dollar-server-challenge-main/submissions/$N >/dev/null 2>&1 && bash build.sh && echo "SUCCESS: $N" || echo "FAILED: $N"
  popd >/dev/null 2>&1
  en
  runstats "build:$N-after"
}

build1 lua-lunet-simbo1905
build1 fortran-microhttpd-tbsvttr
build1 python-fastapi-cknutson12
build1 rust-axum-mjc
build1 c-iouring-ssmurfgg04-gif
build1 c-iouring-27bhd
build1 zig-iouring-marler8997
build1 csharp-aspnetcore-vijay-highlo
build1 bun-elysia-brocchirodrigo
build1 go-nethttp-fi5HiE
build1 node-uwebsockets-zahidcakici
build1 bash-socat-framegrace
build1 lua-openresty-yar0slav
build1 java-nio-stohirov
build1 php-codeigniter-melroy89
