#!/usr/bin/env bash
# Local development runner: pid-file managed start/stop of the submission.
# test/run.sh never calls this; start.sh stays the harness entry point.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TARGET="$ROOT/target"
PID_FILE="$TARGET/lunet.pid"
LOG_FILE="$TARGET/server.log"
DB_FILE="$TARGET/feed.db"

SEED_DB=""
search="$ROOT"
while [ "$search" != "/" ]; do
    if [ -f "$search/seed/feed.db" ]; then SEED_DB="$search/seed/feed.db"; break; fi
    search="$(dirname "$search")"
done
if [ -z "$SEED_DB" ]; then echo "seed/feed.db not found above $ROOT"; exit 1; fi

HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-3000}"
JWT_SECRET="${JWT_SECRET:-twelve-dollar-challenge}"
SQLITE_PATH="${SQLITE_PATH:-$DB_FILE}"

mkdir -p "$TARGET"

running_pid() {
    [ -f "$PID_FILE" ] || return 1
    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null)"
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    echo "$pid"
}

healthy() {
    curl -sf -m 3 "http://$HOST:$PORT/health" >/dev/null 2>&1
}

wait_healthy() {
    local deadline=$(($(date +%s) + $1))
    while [ "$(date +%s)" -lt "$deadline" ]; do
        healthy && return 0
        sleep 1
    done
    healthy
}

kill_pid() {
    kill "$1" 2>/dev/null
    local i
    for i in 1 2 3 4 5; do
        kill -0 "$1" 2>/dev/null || return 0
        sleep 1
    done
    kill -9 "$1" 2>/dev/null
    sleep 1
    kill -0 "$1" 2>/dev/null
}

cmd_start() {
    local pid
    if pid="$(running_pid)"; then
        echo "already running (pid $pid)"
        return 0
    fi
    if healthy; then
        echo "http://$HOST:$PORT already answers /health — refusing to start a second server"
        return 1
    fi
    rm -f "$PID_FILE"

    if [ "$SQLITE_PATH" = "$DB_FILE" ]; then
        echo "refreshing $DB_FILE from $SEED_DB"
        rm -f "$DB_FILE" "$DB_FILE-shm" "$DB_FILE-wal"
        cp "$SEED_DB" "$DB_FILE"
    fi

    : > "$LOG_FILE"
    export HOST PORT JWT_SECRET SQLITE_PATH
    bash start.sh >>"$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    pid="$(cat "$PID_FILE")"

    sleep 2
    if ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PID_FILE"
        echo "server died at startup (pid $pid); log tail:"
        tail -30 "$LOG_FILE"
        return 1
    fi

    if wait_healthy 8; then
        echo "running (pid $pid) on http://$HOST:$PORT, log $LOG_FILE, db $SQLITE_PATH"
        return 0
    fi

    echo "no healthy /health after 10 s (pid $pid); log tail:"
    tail -30 "$LOG_FILE"
    if kill_pid "$pid"; then
        rm -f "$PID_FILE"
        echo "killed the unhealthy server (pid $pid)"
    else
        echo "pid $pid would not die — pid file left at $PID_FILE"
    fi
    return 1
}

cmd_stop() {
    local pid
    if ! pid="$(running_pid)"; then
        if healthy; then
            echo "no live pid in $PID_FILE, but http://$HOST:$PORT answers /health — leaving it alone"
            return 1
        fi
        rm -f "$PID_FILE"
        echo "not running"
        return 0
    fi
    if kill_pid "$pid"; then
        rm -f "$PID_FILE"
        echo "stopped (pid $pid)"
    else
        echo "pid $pid would not die"
        return 1
    fi
}

cmd_status() {
    local pid
    if pid="$(running_pid)"; then
        echo "running (pid $pid) on http://$HOST:$PORT"
    else
        echo "not running"
    fi
}

case "${1:-}" in
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_stop; cmd_start ;;
    status)  cmd_status ;;
    *)       echo "usage: $0 start|stop|restart|status"; exit 2 ;;
esac
