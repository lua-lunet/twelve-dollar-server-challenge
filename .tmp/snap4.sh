#!/usr/bin/env bash
s=0; e=0
runstats() { COLLECT_PHASE="$1" bash collect_stats.sh || true; }
one() {
  P="$1"; N="$2"; CMD="$3"
  runstats "$P:$N-fix-before"
  pushd twelve-dollar-server-challenge-main/submissions/$N >/dev/null 2>&1
  s=$(date +%s.%N)
  eval "$CMD" && echo "SUCCESS-$P-fix: $N" || echo "FAILED-$P-fix: $N"
  popd >/dev/null 2>&1
  e=$(date +%s.%N)
  echo "ELAPSED $(echo "$e - $s" | bc)"
  runstats "$P:$N-fix-after"
}
one install go-nethttp-fi5HiE "sudo bash install.sh"
one build go-nethttp-fi5HiE "bash build.sh"
one build c-iouring-ssmurfgg04-gif "bash build.sh"
