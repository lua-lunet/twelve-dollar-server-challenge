#!/usr/bin/env bash
s=0; e=0
runstats() { COLLECT_PHASE="$1" bash collect_stats.sh || true; }
one() {
  N="$1"
  runstats "build:$N-retry-before"
  pushd twelve-dollar-server-challenge-main/submissions/$N >/dev/null 2>&1
  s=$(date +%s.%N)
  bash build.sh && echo "SUCCESS-retry: $N" || echo "FAILED-retry: $N"
  popd >/dev/null 2>&1
  e=$(date +%s.%N)
  echo "ELAPSED $(echo "$e - $s" | bc)"
  runstats "build:$N-retry-after"
}
one zig-iouring-marler8997
one csharp-aspnetcore-vijay-highlo
one bun-elysia-brocchirodrigo
one node-uwebsockets-zahidcakici
