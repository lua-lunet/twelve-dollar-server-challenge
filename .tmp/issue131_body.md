Hi,

I was curious as to whether any twelve-dollar-server challenge "speed demon submissions" are doing HTTP1.1 properly when hand-rolled. 

So I wrote a validation tool over at https://github.com/lua-lunet/twelve-dollar-challenge-Http11Probe/releases/tag/v1.0.0-M1

My own submission was not valid! I scanned a randomly selected handful of submissions as follows:

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

Older developers will understand that when you go "to bare metal" you risk hand-coding in protocol bugs that are often latent security bugs. The rules state that the server should support HTTP/1.1, but without a checker to ensure servers handle HTTP/1.1 per the spec for each endpoint, we risk a winning solution that is a security nightmare being copied by inexperienced devs or vibers as "best practice". 

To repeat, I found incorrect return codes in my own submission. These were in my own lua-lunet/lunet framework, so I closed those holes in my v0.14.2 release and bumped my submission. So thanks for the challenge; it was a great exercise. When it comes to fast, small, elegant and correct, it used to be that developers could pick only three. Thanks to this challenge, we can now see who supplies all four! 

