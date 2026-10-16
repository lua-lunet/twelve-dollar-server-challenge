# luna-lunet — Lua on lunet

The Feed API in plain Lua on [lunet](https://github.com/lua-lunet/lunet), a libuv + LuaJIT coroutine
runtime. The source is application logic only, in the
[realworld-lua app style](https://github.com/lua-lunet/realworld-lua/tree/main/app): `server.lua` plus
`app/` (routes, router, JWT, config, SQLite access) and `lib/` (HTTP/1.1 framing, libsodium FFI).

## Nginx or direct

**Behind nginx** ([`bench/nginx.conf`](../../bench/nginx.conf)). The app listens on `127.0.0.1:3000`,
loopback only; nginx terminates internet traffic on port 80.

One restriction stated up front: `lib/http.lua` implements a minimal HTTP/1.1 framing subset — one
request per connection. After every response the app sends `Connection: close` and closes the socket,
so it does not honor the spec's keep-alive contract itself. In this baseline that contract is left to
nginx: nginx holds client keep-alive connections on :80 and opens a fresh upstream connection per
request (the `keepalive 64` upstream cache therefore never reuses a connection). Everything runs
through that path; the k6 baseline (50 VUs) measured p99 under 1 ms with 0% errors against it.

## Runtime

lunet is not compiled from source. `build.sh` downloads the pinned release archive
(`lunet-linux-amd64.tar.gz`, tag `v0.10.1`), verifies its sha256 digest against a hash embedded in the
script, stages it into `.lunet/`, and smoke-tests the loader — the same way a Node submission
installs Node. No xmake, no cargo. Nothing prebuilt is committed.

## Build and run

```bash
sudo bash install.sh   # once, as root: apt libraries, re-run safe
bash build.sh          # fetch + verify + stage the pinned runtime (.lunet/)
bash start.sh          # foreground server, configured only by the SPEC.md env vars
```

Local helper: `bin/dev.sh start|stop|status` — pid-file managed, fresh copy of the seed database,
log in `target/server.log`.

## Requirements

Ubuntu 24.04 x86_64 and nothing to bootstrap: no compiler, no language toolchain. `install.sh` needs
curl plus apt packages only (`ca-certificates`, `libluajit-5.1-2`, `libuv1`, `zlib1g`,
`libsqlite3-0`, `libsodium23`) and symlinks `libsodium.so` so the FFI can load it.

## Design notes

- **SQLite in-process** at `$SQLITE_PATH` via lunet's bundled SQLite driver; opened with WAL and
  `synchronous=NORMAL` so writes are durable before a 201 is sent. No other service, no cache tiers.
- **No cross-request caching.** Every request runs its SQL against SQLite. Every JWT is verified
  fresh per request: signature recomputed and compared in constant time (libsodium via FFI), header
  and payload decoded and checked, `exp` checked.
- **Bytes-exact JSON.** Responses are rendered directly in the byte shapes the spec mandates
  (five fixed shapes assembled with one escaper sourced from jsonic's vendored dkjson), so the
  key order and bytes match by construction rather than by reordering a generic encode.
