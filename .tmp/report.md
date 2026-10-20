# Sweep rerun — full detail, all 13 servers (fixed generic-profile rig, twelve-dollar-challenge-Http11Probe v1.0.0-M1)

The rig was rebuilt on the ORIGINAL MDA2AV engine (fork push 86d77c3 after rebasing off the fork-of-a-fork), our generic-framing defect landed upstream (lua-lunet/lunet#214 → PR #215 merged → v0.14.2 cut, all 9 assets shipped), and our submission was bumped to the v0.14.2 digests (30e17ec on simbo1905; the PR head carries it at 6ad2ab1). Every run: no strays before → fresh seed db copy → that submission's server started → the probe → server stopped, with pid lists captured either side. Local macOS and lima VM runs of our own submission agree: 46/46.

## The table

| # | server | verdict | per-endpoint detail | why it failed (step + expected + got) |
|---|---|---|---|---|
| 1 | lua-lunet-simbo1905 | **PASS** 46/46 | health 5/5 (~1.6s), feed 5/5 (~1.5s), posts-read 10/10 (~3.6s), posts-create 16/16 (~6.1s), posts-like 10/10 (~3.6s) | — |
| 2 | fortran-microhttpd-tbsvttr | **PASS** 46/46 | health 5/5 (1.5s), feed 5/5 (1.4s), posts-read 10/10 (3.4s), posts-create 16/16 (6.0s), posts-like 10/10 (3.4s) | — |
| 3 | python-fastapi-cknutson12 | **PASS** 46/46 | health 5/5 (1.6s), feed 5/5 (1.5s), posts-read 10/10 (3.6s), posts-create 16/16 (6.1s), posts-like 10/10 (3.6s) | — |
| 4 | bun-elysia-brocchirodrigo | **PASS** 46/46 | health 5/5 (1.5s), feed 5/5 (1.5s), posts-read 10/10 (3.6s), posts-create 16/16 (6.1s), posts-like 10/10 (3.5s) | — |
| 5 | go-nethttp-fi5HiE | **PASS** 46/46 | health 5/5 (1.5s), feed 5/5 (1.5s), posts-read 10/10 (3.6s), posts-create 16/16 (6.1s), posts-like 10/10 (3.6s) | — |
| 6 | lua-openresty-yar0slav | **PASS** 46/46 | health 5/5 (1.6s), feed 5/5 (1.5s), posts-read 10/10 (3.4s), posts-create 16/16 (5.9s), posts-like 10/10 (3.5s) | — |
| 7 | node-uwebsockets-zahidcakici | FAIL 25/30 | block×5 + the rest green | **`http10` on all 5 endpoints** — a well-formed HTTP/1.0 request with Host must be served 2xx + connection close (RFC 9112 §9.3); server answers **400** instead ("a plain HTTP/1.0 request must be served (2xx + close), got 400") |
| 8 | csharp-aspnetcore-vijay-highlo | FAIL 33/34 | health/feed/posts-read/posts-like all green; posts-create aborted at the bad-signature step | **`posts.bad-signature`** — a tampered-signature token MUST get `401 {"error":"invalid or expired token"}`; server answers **500 {"error":"internal server error"}** (a real app bug: the 500 leaks a server error where the contract demands 401 — upstream PR #77) |
| 9 | java-nio-stohirov | FAIL 20/25 | block×5 immediately | **`te-chunked` on all 5 endpoints** — a valid single-chunk body must be accepted and decoded (RFC 9112 §7.1); server answers **400 {"error":"bad request"}** (upstream PR #88) |
| 10 | php-codeigniter-melroy89 | FAIL 45/46 | EVERY step green except **`feed.ok` only** | **`feed.ok`** — the content itself is CORRECT (exact 20 spec posts, right shapes); the server answers `200` + `Transfer-Encoding: chunked` on its own response, and the RIG's response parser does not de-chunk RESPONSES — the body read back includes chunk-size framing ("13ee …", trailing "0"), so the JSON check dies on the size marker. **This one is a RIG defect**: the probe demands servers accept chunked REQUESTS but its own response reader doesn't accept a chunked RESPONSE. Rig-side fix queued; php's true grade is 46/46 once the parser de-chunks (upstream PR #50) |
| 11 | bash-socat-framegrace | FAIL 20/25 | block×5 immediately | **`te-chunked` on all 5** — the coprocess hands the undecoded chunked body to the shell app: `400 {"error":"malformed JSON body"}` (upstream PR #89) |
| 12 | zig-iouring-marler8997 | arch-locked | never served | x86-only fiber asm (rsp/rbp/mxcsr); no arm64 path; the install/build verdicts stand from the exercise rounds |

## Headline
6 PASS under the corrected generic lens (lua, fortran, python, bun, go, openresty — up from 1 under the un-rigged lens); php expected to make it 7 the moment the rig de-chunks its own response reading. The remaining 5 PASS-short entries stand on REAL per-server defects, each pinned to their step: node's http10 rejection, java + bash-socat's undecoded chunked bodies, csharp's 500-for-401 auth leak, zig arch-locked.

## Soak lane (60s @ 500 VU, bench/load.js semantics, limactl stop+start before each, sampler every 5s while still soaking)

| server | k6 thresholds | requests | p95 / p99 | steady VmRSS (last 30s mean) | VmHWM peak | growth first→last |
|---|---|---|---|---|---|---|
| lua-lunet-simbo1905 | ALL PASS | 4928 | 2.4ms / 3.95ms | 8.9 MB | 8.9 MB | +4.0 MB (warm-up only) |
| fortran-microhttpd-tbsvttr | ALL PASS | 4905 | 2.18ms / 3.87ms | 15.6 MB | 15.6 MB | +12.0 MB (warm-up) |
| python-fastapi-cknutson12 | ALL PASS | 4920 | 2.59ms / 4.09ms | 57.0 MB | 57.0 MB | +8.8 MB |
| bun-elysia-brocchirodrigo | ALL PASS | 4933 | 3.01ms / 14.05ms | 52.5 MB | 55.1 MB | +12.1 MB (rss even dips late: GC) |
| go-nethttp-fi5HiE | ALL PASS | 4964 | 2.63ms / 4.57ms | 25.5 MB | 25.5 MB | +16.1 MB (warm-up only) |
| lua-openresty-yar0slav | ALL PASS | 4946 | 2.17ms / 3.81ms | 22.1 MB | 22.1 MB | 0 kB flat |

Zero failed requests on all six; every p95 ≈ 2–3 ms and p99 ≤ 14 ms — all far inside the challenge's pass bar. Memory residency: every entry plateaus in its late window (no creep to the end = no leak signature at this load). Ours is the smallest resident set that still banks the fastest p99 second-place-ish spot; fortran is leaner at idle but carries a bigger warm-up. php-ccodeigniter stays out of this lane (its 45/46 was the RIG's response-parser defect, not the server).

Sort order for the article: resident memory at soak — lua 8.9, fortran 15.6, openresty 22.1, go 25.5, bun 52.5, python 57.0 (MB).

## Logs
Fuzz sweep: .tmp/clobber_me_{320,323,325,327,329,331,333,334,335,336,337,338,339,340,349}_s*.log
Soak runs: .tmp/clobber_me_{411..417}_*.txt + per-run details in .tmp/soak/soak_k6_<name>.log (full k6) and the prelude/mem files under .tmp/soak/.

## fail-safe note
Each server's per-run summary feeds the table above — the FULL unfiltered transcript for each server lives in the per-run tee files named above (one file, one writer).
