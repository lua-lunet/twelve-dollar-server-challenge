#!/usr/bin/env bash
s=0; e=0
runstats() { COLLECT_PHASE="$1" bash collect_stats.sh || true; }
one() {
  P="$1"; N="$2"; CMD="$3"
  runstats "$P:$N-before"
  pushd twelve-dollar-server-challenge-main/submissions/$N >/dev/null 2>&1
  s=$(date +%s.%N)
  eval "$CMD" && echo "SUCCESS-$P: $N" || echo "FAILED-$P: $N"
  popd >/dev/null 2>&1
  e=$(date +%s.%N)
  echo "ELAPSED $(echo "$e - $s" | bc)"
  runstats "$P:$N-after"
}
one install php-codeigniter-melroy89 "sudo bash install.sh"
one build php-codeigniter-melroy89 "bash build.sh"
