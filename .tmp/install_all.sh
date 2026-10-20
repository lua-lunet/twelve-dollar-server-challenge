#!/usr/bin/env bash
# One-shot install attempt per submission. Explicit lines, no loop.
# No set -e, no pipefail: an error in one line never crashes the script.
# Each stage is timed (ELAPSED lines); collect_stats.sh brackets each phase.
s=0; e=0
st() { s=$(date +%s.%N); }
en() { e=$(date +%s.%N); echo "ELAPSED $(echo "$e - $s" | bc)"; }
runstats() { COLLECT_PHASE="$1" bash collect_stats.sh || true; }

runstats baseline --deep || true

inst() {
  N="$1"
  runstats "install:$N-before"
  st
  pushd twelve-dollar-server-challenge-main/submissions/$N >/dev/null 2>&1 && sudo bash install.sh && echo "SUCCESS: $N install" || echo "FAILED: $N install"
  popd >/dev/null 2>&1
  en
  runstats "install:$N-after"
}

inst lua-lunet-simbo1905
inst fortran-microhttpd-tbsvttr
inst python-fastapi-cknutson12
inst rust-axum-mjc
inst c-iouring-ssmurfgg04-gif
inst c-iouring-27bhd
inst zig-iouring-marler8997
inst csharp-aspnetcore-vijay-highlo
inst bun-elysia-brocchirodrigo
inst go-nethttp-fi5HiE
inst node-uwebsockets-zahidcakici
inst bash-socat-framegrace
inst lua-openresty-yar0slav
inst java-nio-stohirov
inst php-codeigniter-melroy89
