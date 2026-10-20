# Eval watchlist — twelve-dollar overhead exercise
Source: upstream PR heads (video-mentioned entries off main) + operator picks. DoD = verdict + disk delta + network total + time; memory where served. Attempt counts: install / build, one-shot unless noted.

| # | submission | stack | install | install t | build | build t | notes |
|---|-----------|-------|---------|-----------|-------|---------|-------|
| 1 | lua-lunet-simbo1905 | lua/lunet v0.14.1 | SUCCESS ×2 | 4.5s cold, 1.2s warm | SUCCESS ×2 | 0.46s | apt 1.9MB, disk +3.0MB |
| 2 | fortran-microhttpd-tbsvttr | fortran/libmicrohttpd | SUCCESS ×2 | 14.3s cold (DL 73MB) | SUCCESS ×2 | 26.4s cold, 0.6s warm | disk +320MB (toolchain) |
| 3 | python-fastapi-cknutson12 | python/uvicorn | SUCCESS ×2 | 266.2s cold | SUCCESS ×2 | 4.3s cold, 2.6s warm | venv+pip |
| 4 | rust-axum-mjc | rust/axum | SUCCESS | 379.6s | SUCCESS | 93.4s | toolchain ~4.5GB; disk was exhausted by this (cascade victims re-tried); target/ + /opt/rust-stable later cleaned post-verdict |
| 5 | c-iouring-27bhd | C io_uring | SUCCESS | 5.2s | SUCCESS | 30.2s | |
| 6 | bash-socat-framegrace | bash/socat | SUCCESS | 4.3s | SUCCESS | 0.002s | |
| 7 | csharp-aspnetcore-vijay-highlo | C# AOT | SUCCESS | 33.9s dotnet sdk | SUCCESS (retry after disk-free) | 36.1s | first build was disk-cascade victim, not its own |
| 8 | bun-elysia-brocchirodrigo | bun/elysia | SUCCESS | 6.2s | SUCCESS (retry) | 3.3s | first build = disk cascade |
| 9 | node-uwebsockets-zahidcakici | node/uWS | SUCCESS | 5.8s | SUCCESS (retry) | 48.0s | first build = disk cascade |
| 10 | go-nethttp-fi5HiE | go/net-http | FAILED attempt 1 (linux-amd64 go on arm64) → SUCCESS fix (go1.27.2.linux-arm64 official sha) | 18.4s fix | SUCCESS fix | 30.3s | single-attempt arch fix |
| 11 | zig-iouring-marler8997 | zig/io_uring | SUCCESS | 0.009s (nothing) | FAILED ×2 | 68.9s+45.1s | x86-only fiber asm (rsp/rbp/mxcsr); no arm64 path; verdict stands |
| 12 | c-iouring-ssmurfgg04-gif | C io_uring PGO | SUCCESS | 1.0s | FAILED attempt 1 (own bug: PGO train.c sqlite3.h include) → SUCCESS fix 47.2s ($COMMON_INC added on the two train.c compiles) | single-attempt script fix |
| 13 | lua-openresty-yar0slav | nginx + openresty lua | SUCCESS | 12.8s | SUCCESS | 0.003s | PR 94, operator pick |
| 14 | java-nio-stohirov | java/nio raw sockets | SUCCESS | 19.4s JDK | SUCCESS | 12.9s | PR 88, operator pick (JDK download measured) |
| 15 | php-codeigniter-melroy89 | PHP 8.5/frankenphp | FAILED attempt 1 (x86_64 binary on arm64) → SUCCESS attempt 2 (single-attempt fix: arch swap + pinned aarch64 sha) | 27.3s fail / 26.4s fix (DL ~174MB) | SUCCESS ×2 | 2.0s / 0.4s | PR 50, operator pick; compose+php+frankenphp in install.sh |

Running count: 14 good of 15 in tree (zig stands arch-locked FAILED). Both single-attempt fixes landed (go arch swap; c-iouring $COMMON_INC). Disk managed: apt lists+clean freed ~350MB; available ~700MB after go install.
Disk cascade history: rust toolchain ~4.5GB exhausted the 10GiB disk mid-build-pass; freed cargo target + /opt/rust-stable post-verdict (1.6GB reclaimed).

## HTTP/1.1 probe (rig v1.0.0-M1, generic profile) + soak (60s @ 500 VU, vm stop/start before each)

| server | http/1.1 | probe detail | soak k6 | steady VmRSS | VmHWM |
|---|:---:|---|---|---|---|
| lua-lunet-simbo1905 | ✅ 46/46 | all endpoints green | ✅ 4928 reqs, p95 2.4ms p99 3.95ms | 8.7 MB | 8.7 MB |
| rust-axum-mjc | ✅ 46/46 | all endpoints green (needs rust rebuild for any re-run; toolchain purged post-verdict) | ✅ 4916 reqs, p95 4.01ms p99 5.85ms | 7.6 MB | 7.6 MB |
| fortran-microhttpd-tbsvttr | ✅ 46/46 | all endpoints green | ✅ 4905 reqs, p95 2.18ms p99 3.87ms | 15.2 MB | 15.2 MB |
| python-fastapi-cknutson12 | ✅ 46/46 | all endpoints green | ✅ 4920 reqs, p95 2.59ms p99 4.09ms | 55.7 MB | 55.7 MB |
| bun-elysia-brocchirodrigo | ✅ 46/46 | all endpoints green | ✅ 4933 reqs, p95 3.01ms p99 14.05ms | 51.3 MB (GC dips) | 53.8 MB |
| go-nethttp-fi5HiE | ✅ 46/46 | all endpoints green | ✅ 4964 reqs, p95 2.63ms p99 4.57ms | 24.9 MB | 24.9 MB |
| lua-openresty-yar0slav | ✅ 46/46 | all endpoints green | ✅ 4910 reqs, p95 2.45ms p99 4.72ms | 10.3 MB master + 41.9 MB worker = 52.2 MB | 52.2 MB |
| csharp-aspnetcore-vijay-highlo | ❌ 33/34 | posts.bad-signature → 500 instead of 401 invalid-or-expired-token | — | (48.3 MB idle serve sample) | — |
| node-uwebsockets-zahidcakici | ❌ 25/30 | http10 rejected with 400 on all 5 endpoints (must serve 2xx+close) | — | — | — |
| java-nio-stohirov | ❌ 20/25 | te-chunked undecoded → 400 on all 5 | — | — | — |
| bash-socat-framegrace | ❌ 20/25 | te-chunked undecoded → 400 on all 5 | — | — | — |
| c-iouring-27bhd | ❌ 20/25 | te-chunked undecoded → 400 {"error":"malformed JSON body"} on all 5 | — | — | — |
| c-iouring-ssmurfgg04-gif | ❌ 20/25 | te-chunked undecoded → 400 {"error":"bad request"} on all 5 | — | — | — |
| php-codeigniter-melroy89 | ⏳ 45/46 | EVERYTHING green except feed.ok — RIG's own response parser lacks de-chunking (php's content is correct); true grade 46/46 pending rig fix | — | (105 MB serve sample) | — |
| zig-iouring-marler8997 | 🚫 | arch-locked: x86-only fiber asm; cannot serve on arm64 | — | — | — |

Soak note: think-time-bound load ≈ 41 rps by design (residency lane, not a ceiling number). All six/eight soak runs: 0 failed requests. Every sampled series plateaus in the late window — no leak signature anywhere.
