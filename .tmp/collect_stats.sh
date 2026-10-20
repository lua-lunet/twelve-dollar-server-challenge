#!/usr/bin/env bash
# collect_stats.sh — one-shot, diff-friendly system sampler for evaluation phases.
#
# Runs INSIDE the eval VM, once per invocation (no daemon). Fast mode is pure
# /proc reads + coreutils (~tens of ms). Usage:
#
#   COLLECT_PHASE="install:lua-lunet-simbo1905" bash collect_stats.sh
#   COLLECT_PHASE="build:lua-lunet-simbo1905"   bash collect_stats.sh
#   COLLECT_PHASE="serve:lua-lunet-simbo1905"   bash collect_stats.sh
#   COLLECT_DEEP=1 COLLECT_PHASE="baseline"     bash collect_stats.sh --deep
#
# Options / env:
#   --deep              add the du-based durable-vs-scratch disk ledger (seconds,
#                       not ms — run at phase boundaries where that is fine)
#   COLLECT_DEEP=1      same as --deep
#   COLLECT_PHASE       free-form label printed in the header (diff key)
#   COLLECT_SCRATCH_EXTRA  extra paths to class as build-scratch (default: the
#                       extracted challenge tree, e.g. /root/twelve-dollar-server-challenge-main)
#
# Attribution model (why this shape):
#   Every counter below is CUMULATIVE SINCE BOOT. Two consecutive blocks define
#   a phase window; the DELTA between them attributes traffic/IO to that phase.
#   On a lima vz guest all non-loopback traffic shares ONE interface (eth0,
#   vzNAT): port-forwarded load-test traffic (SSH-tunneled by lima's ssh -L
#   forwarding) and the guest's own outbound apt/cargo/pip downloads both hit
#   it. Separation is therefore: phase window (paired snapshots) + direction
#   (install downloads are rx-dominated; served responses are tx-dominated)
#   + the loopback signature (the inner sshd->server hop shows up on lo during
#   serving, near zero during install). No package installs needed for any of
#   this: nf_conntrack accounting is off by default and nethogs needs libpcap
#   and a capture loop — both rejected as too invasive/slow for a clean box.
#
# Output: one stable, labeled block on stdout; parse with diff or grep.

set -u
LC_ALL=C

PHASE="${COLLECT_PHASE:-unset}"
DEEP=0
[ "${1:-}" = "--deep" ] && DEEP=1
[ "${COLLECT_DEEP:-0}" = "1" ] && DEEP=1

T0_NS="$(date +%s%N)"
EPOCH="$(date +%s)"
UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
UPTIME="$(cut -d' ' -f1 /proc/uptime)"

echo "=== collect_stats phase=$PHASE epoch=$EPOCH utc=$UTC uptime_s=$UPTIME deep=$DEEP ==="

# ---- [net] per-interface byte/packet counters since boot (/proc/net/dev) ----
# Fields: iface rx_bytes rx_pkts rx_errs rx_drop rx_fifo rx_frame rx_comp rx_mcast
#               tx_bytes tx_pkts tx_errs tx_drop ...
# Reading direction: rx = data INTO the guest (apt downloads, bench requests),
#                    tx = data OUT of the guest (served responses, small requests).
echo "[net] iface rx_bytes rx_pkts rx_drop tx_bytes tx_pkts tx_drop (since boot)"
awk 'NR>2 { sub(":", "", $1)
            printf "[net] %s rx_bytes=%s rx_pkts=%s rx_drop=%s tx_bytes=%s tx_pkts=%s tx_drop=%s\n", \
            $1, $2, $3, $5, $10, $11, $13 }' /proc/net/dev

# ---- [net-ip] global octet cross-check (IpExt; should track eth0 deltas) ----
awk '$1=="IpExt:" { if (h==0) { for (i=2;i<=NF;i++) ix[$i]=i; h=1 }
                    else { printf "[net-ip] InOctets=%s OutOctets=%s\n", $ix["InOctets"], $ix["OutOctets"]; exit } }' \
    /proc/net/netstat 2>/dev/null

# ---- [tcp] connection-activity counters since boot (/proc/net/snmp) ----
# ActiveOpens delta across a serve phase ~ number of accepted connections.
awk '$1=="Tcp:" { if (h==0) { for (i=2;i<=NF;i++) ix[$i]=i; h=1 }
                  else { printf "[tcp] ActiveOpens=%s PassiveOpens=%s AttemptFails=%s EstabResets=%s CurrEstab=%s RetransSegs=%s\n", \
                         $ix["ActiveOpens"], $ix["PassiveOpens"], $ix["AttemptFails"], \
                         $ix["EstabResets"], $ix["CurrEstab"], $ix["RetransSegs"]; exit } }' \
    /proc/net/snmp 2>/dev/null

# ---- [load] cheapest load snapshot (kernel keeps the averages for free) ----
read -r L1 L2 L3 RTOT _ < /proc/loadavg
RUNNING="${RTOT%%/*}"; TOTAL="${RTOT##*/}"
echo "[load] load1=$L1 load5=$L2 load15=$L3 running=$RUNNING total=$TOTAL"

# ---- [cpu] jiffies since boot + runqueue depth + context switches ----
awk '/^cpu /   { u=$2; n=$3; s=$4; i=$5; w=$6; q=$7; so=$8; st=$9 }
     /^procs_running/ { r=$2 } /^procs_blocked/ { b=$2 } /^ctxt/ { c=$2 }
     END { printf "[cpu] user=%s nice=%s sys=%s idle=%s iowait=%s softirq=%s steal=%s running=%s blocked=%s ctxt=%s (since boot)\n", \
           u, n, s, i, w, q, so, st, r+0, b+0, c }' /proc/stat

# ---- [mem] kB; Cached/SReclaimable show build page-cache pressure on 2GiB ----
awk '/^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SReclaimable|Shmem):/ { printf "[mem] %s=%s_kB\n", $1, $2 }' /proc/meminfo

# ---- [io] per-disk since boot (/proc/diskstats); sectors are 512B units ----
# w_sec delta across a phase = bytes written by that phase (build scratch etc).
awk '$3 !~ /^(loop|ram|zram|fd|sr)/ { printf "[io] %s reads=%s r_sec=%s writes=%s w_sec=%s inflight=%s io_ms=%s\n", \
      $3, $4, $6, $8, $10, $12, $13 }' /proc/diskstats

# ---- [fs] filesystem-level usage (df; instant, includes reserved blocks) ----
df -k -l -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 2>/dev/null \
  | awk 'NR>1 { printf "[fs] fs=%s mount=%s used_kB=%s avail_kB=%s\n", $1, $6, $3, $4 }'

# ---- [ss] optional: socket summary if iproute2 happens to be present ----
if command -v ss >/dev/null 2>&1; then
    ss -s 2>/dev/null | sed 's/^/[ss] /'
fi

# ---- [conntrack] informational: shows whether the module is even loaded ----
if [ -r /proc/sys/net/netfilter/nf_conntrack_count ]; then
    echo "[conntrack] count=$(cat /proc/sys/net/netfilter/nf_conntrack_count) (accounting off by default; no byte counters)"
fi

# ---- [du] deep ledger: durable vs scratch disk (seconds — opt-in) ----
# Scratch-vs-durable classification (excludes-list philosophy):
#   DURABLE = things that persist on a prod-ish image and do not come back:
#     packages under /usr (+/etc, /opt, /srv), venvs wherever created, JVMs
#     under /usr/lib/jvm, and language toolchain/home caches that keep
#     persisting (cargo ~/.cargo, gradle ~/.gradle, gems /var/lib/gems) —
#     they are a real image cost even if deletable in principle.
#   SCRATCH = things a prod build would clear or never carry: the apt download
#     cache (/var/cache/apt — `apt clean` reclaims it), apt package lists
#     (/var/lib/apt/lists), /tmp and /var/tmp, generic download caches
#     (~/.cache: pip/uv/http), and the evaluation tree itself with its build
#     outputs (compilers write target/, node_modules, .class files there —
#     dev tax, not prod tax).
# Mechanism: rather than du --exclude (whose pattern anchoring semantics are
# easy to get wrong), we sum disjoint durable trees, then SUBTRACT every
# scratch path that lives inside them. Exact, no pattern-matching edge cases.
if [ "$DEEP" = "1" ]; then
    DURABLE_TREES="/etc /opt /root /home /srv /usr /var"
    [ -d /boot ] && DURABLE_TREES="$DURABLE_TREES /boot"
    SCRATCH_PATHS="/tmp /var/tmp /var/cache /var/lib/apt/lists /root/.cache /home/*/.cache"
    SCRATCH_PATHS="$SCRATCH_PATHS ${COLLECT_SCRATCH_EXTRA:-/root/twelve-dollar-server-challenge-main}"
    # NB: paths are deliberately word-split; globbed entries with no match are
    # skipped by the -e guard. Keep trees disjoint from each other.
    # shellcheck disable=SC2086
    DU_TREES="$(du -xsk $DURABLE_TREES 2>/dev/null)"
    printf '%s\n' "$DU_TREES" | awk '{ printf "[du] durable_tree=%s kb=%s\n", $2, $1; s+=$1 }
                                     END { printf "[du] durable_trees_total_kb=%d\n", s }'
    TREE_TOTAL="$(printf '%s\n' "$DU_TREES" | awk '{ s+=$1 } END { printf "%d", s+0 }')"
    SUB=0; SCR=0
    for p in $SCRATCH_PATHS; do
        [ -e "$p" ] || continue
        s="$(du -xsk "$p" 2>/dev/null | awk '{ s+=$1 } END { printf "%d", s+0 }')"
        ov=no
        for t in $DURABLE_TREES; do
            case "$p" in "$t"|"$t"/*) ov=yes; break ;; esac
        done
        printf "[du] scratch=%s kb=%s inside_durable_trees=%s\n" "$p" "$s" "$ov"
        SCR=$((SCR + s))
        [ "$ov" = "yes" ] && SUB=$((SUB + s))
    done
    DURABLE=$((TREE_TOTAL - SUB))
    awk -v d="$DURABLE" -v s="$SCR" 'BEGIN { printf "[du] durable_total_kb=%d (%.0f MB) scratch_total_kb=%d (%.0f MB)\n", d, d/1024, s, s/1024 }'
fi

T1_NS="$(date +%s%N)"
awk -v a="$T0_NS" -v b="$T1_NS" 'BEGIN { printf "[end] self_ms=%.0f\n", (b-a)/1000000 }'
