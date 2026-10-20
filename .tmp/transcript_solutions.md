# Transcript solutions — every submission/solution mentioned in the three $12-server videos

Source: auto-generated captions (YouTube ASR, Dutch audio auto-translated to English — `kind=asr lang=nl(-NL) tlang=en`).
ASR mangles occasional words; mangled tokens are flagged inline (`[ASR: …]`). Positions are rough (mm:ss of cues near the mention; VTT/clean-text files in `.tmp/videos_cc/`).

Videos:
- **V1** `QGWKCaglSBI` — "I Asked Expert Programmers to Max Out a $12 Server" (22:56, 5 days old at capture). The community challenge results review. 13 languages, 28 entries, 26 benchmarked. Best: 64,000 concurrent users.
- **V2** `GFtFIxrAjIs` — "How Many Users Can a $12 Server Handle?" (13:18, Sep 25 2026). Original baseline: Nginx + Node.js + Postgres on one droplet. No submissions — pre-challenge.
- **V3** `sQXFhh_PiG4` — "Which Programming Language Can Handle the Most Users on a $12 Server?" (14:46, 2w before capture). 8-language standard-setup benchmark, then a Postgres→SQLite swap on the top 3. No submissions — pre-challenge.

---

## A. Challenge entries (V1) — the long candidate list

Announced language list (V1 ~03:23): C, C++, Rust, Zig, Go, TypeScript, Python, Bun, PHP, Ruby, Erlang, Fortran, R, plus "TypeScript running on Bun" counted as a separate entry. Zero Java entries, zero Node entries. Notably: **no Lua among the 13 languages.**

| # | Entry (as described) | Stack / key libs | What the author said | Video / rough position |
|---|---|---|---|---|
| A1 | Ruby Rails entry 1 | Ruby, Rails | 3,000 users. "Not bad." Would have placed on the slower side of the V3 baseline. | V1 ~03:55 |
| A2 | Ruby Rails entry 2 | Ruby, Rails | 3,500 users. Kept Nginx (one of the submissions that retained it). | V1 ~03:55 |
| A3 | Ruby "fastest" entry | Ruby, **Iodine** (C web server), 1 worker / 1 thread, YJIT on | 14,000 users — 4× the best Rails result, "hardly resembles Ruby". SQLite builds the JSON response directly, Ruby just ships it. P95 50ms / P99 154ms / 0 errors / 62% CPU at 14k; collapse at 15k (P99 2.5s). | V1 ~04:10 |
| A4 | Erlang entry | Erlang, **Cowboy** | 15,000 users. One scheduler configured, single process owns the SQLite connection; JSON generated inside SQLite. CPU 83%, 600MB RAM ("one of the highest in this entire batch"). P95 171ms / P99 320ms; past 16k P95 > 4s. | V1 ~05:30 |
| A5 | Python FastAPI (first submission) | Python, FastAPI + SQLite + **UVloop** + **orjson** | 11,000 users. "Fairly normal FastAPI application" except SQLite/UVloop/orjson. | V1 ~06:40 |
| A6 | Python stripped-FastAPI | Python, Uvicorn → handler directly (FastAPI/Starlette layers removed) | 22,000 users. Another dev took A5 and doubled it by removing routing/dependency-injection/middleware/request-object overhead. "One of the most interesting results of this entire experiment." CPU 91% at 22k; P95 353ms / P99 653ms; 23k fails (P95 > 1s). | V1 ~07:00 |
| A7 | Go entry (only one) | Go | 22,000 users — tied with Python ("bizarre", but he blames the implementation, not Go). Single goroutine owns the DB, collects up to 256 requests, commits batch = **group commit**. Limitation: >16,000 open connections → asks clients to reconnect, expensive at scale. Error rate 0.5% at 22k (limit 1%), CPU only 78% → connection-limited, not CPU. Invites Go devs to PR it faster. | V1 ~08:00 |
| A8 | C# entry | C#, **Kestrel** (ASP.NET Core), everything else stripped | 32,000 users (baseline 4,400). No middleware, no routing layer, no standard HTTP context; talks to Kestrel's low-level interfaces. Pooled buffers for JSON; stack-allocated memory for token auth. CPU 93% (highest of the top 15). | V1 ~09:40 |
| A9 | Fortran entry | Fortran + **libmicrohttpd** (C) with small C glue | 38,000 users — beat Python, Go and C#. JSON parsed/built via SQLite's JSON functions, no Fortran JSON library; token validation done in SQL; group commit. "How important application architecture can be, regardless of the language." CPU 85%, 700MB RAM; fails at ~39k (P99 1.7s). | V1 ~10:40 |
| A10 | PHP Swoole entry 1 | PHP, **Swoole** (long-running server), JIT enabled, ~250 lines | 40,000 users vs Laravel's 750 baseline (50×+). App starts once, prepares queries, keeps running; no per-request framework boot. P95 189ms / P99 853ms / 0 errors at 40k. | V1 ~11:35 |
| A11 | PHP Swoole entry 2 | PHP, modified Swoole | 39,000 users. Modified Swoole to reduce memory usage of inactive connections. | V1 ~12:30 |
| A12 | C entry | C, **io_uring** | 46,000 users. Batched kernel ops. Profile-guided optimization: ran a representative workload through SQLite at build time and compiled SQLite for those paths. Rewrote the feed query so per-post likes aren't recounted per row. 39MB RAM — fewest of all entries. Failed at 47k with only 36% CPU: suspects design bottleneck — 8 worker threads on 1 CPU all contending on a single DB lock, waits for 128 events per batch. Asks devs to explain in comments. | V1 ~13:00 |
| A13 | TypeScript-on-Bun entry | TypeScript on **Bun**, raw TCP sockets, hand-rolled minimal HTTP parsing, ~350 lines | 47,000 users vs 4,200 Bun baseline (11×). Scans incoming bytes for needed headers; SQLite returns JSON as raw bytes straight to the socket; reusable output buffer; calls a C library to raise the connection backlog. "Extreme example of leaving out everything you don't need" — wouldn't do it for a general production API. P95 96ms / P99 356ms / 72% CPU / 150MB. 48k fails (P95 12s). | V1 ~14:20 |
| A14 | Rust Axum entry | Rust, **Axum** (same framework as his V3 benchmark) | 43,000 users. Single thread + one assigned task handling the DB and bundling writes (like Go's group commit). Also started closing connections above 40,000 — likely the ceiling cause. Most memory of all entries: 1.1GB on a 2GB box. | V1 ~15:40 |
| A15 | Rust io_uring entry | Rust, **io_uring**, kernel-managed socket references | 64,000 users, P99 224ms, <100MB RAM, ~50% CPU — **the winner** ("fastest language in the community benchmark"). Event loop collects a batch of DB writes, commits once, responds (group commit again). Ran into the Linux conntrack limit (~65k table), not an app limit. ~2,400 lines, "a lot of unsafe Rust". | V1 ~16:20 |
| A16 | Zig entry | Zig, **uSockets** (C network library) | 61,000 users, ~680 lines. Group commit. Dev-set hard cap of 60,000 persistent connections → forced reconnects → conntrack entries linger → same 64k wall. "If we had changed that setting, Zig could have reached 64,000 as well." CPU 69%, P99 268ms at 62k; failed on 1.02% errors from reconnections. | V1 ~17:40 |
| A17 | C++ entry 1 (same dev as Zig) | C++ | ~61,000 users — "virtually the same limit" as the Zig entry. | V1 ~18:30 |
| A18 | C++ entry 2 (same dev) | C++ | ~61,000 users, same limit behavior. (A16+A17+A18 all reached 61k per his wording.) | V1 ~18:30 |
| A19 | C++ single-file winner entry | C++, one thread / one event loop / direct SQLite, own HTTP + JSON parser, >1,300 lines in a single file | 64,000 users — tied for first on score. Shrunk SQLite's own cache to ~nothing and mmap'd the DB so reads hit the OS page cache (ruled allowed — warmed file cache, not an in-memory DB); moved WAL checkpoints off the response path. Uses WAL with `synchronous=NORMAL` — he flags the durability trade-off and puts an "asterisk" on it. P99 910ms at 64k vs Rust's 224ms → Rust ranked fastest overall. | V1 ~19:00 |
| A20 | C++ in-memory DB entry | C++, **disqualified** | Did not use SQLite — loaded everything into an in-memory database, against the rules. "Really cool submission. Check it out on my GitHub." Not benchmarked (26 of 28 benchmarked because of A20 + A21). | V1 ~03:38 |
| A21 | R entry | R | Could not start on the test machine — missing system library. Not benchmarked. | V1 ~03:45 |
| A22 | (non-existent) Java entries | Java | Zero received. "Java developers, you have let me down. Better luck next time." Wants Java submissions. | V1 ~03:49 |
| A23 | (non-existent) Node entries | Node.js | Zero received. Wants Node submissions. | V1 ~03:50 |

Cross-cutting optimizations he credits for the wins (V1 ~21:00): remove Nginx (top entries serve HTTP directly; Axum entry and a Rails entry kept it), prepared SQLite statements + one reused connection, SQLite builds the JSON directly, group commit, and replacing the framework with a purpose-built server.

Final ranking he gave (V1): Rust 64k (winner, most headroom, P99 224ms) ≈ C++ 64k (tied on score, asterisk: worse P99, durability trade-off) > Zig 61k ≈ C++ 61k×2 > Bun/TS 47k > C 46k > PHP Swoole 40k/39k > Fortran 38k > C# 32k > Python 22k = Go 22k > Erlang 15k > Ruby 14k. Conntrack ~65k table capped several entries.

## B. Baseline stacks (V3 — the 8-language video, no submissions)

| # | Stack | What he said | Video / rough position |
|---|---|---|---|
| B1 | Node 22 + Express 5, single process | 3,250 users, ~300 rps, median 14ms / P95 330 / P99 610. Baseline. | V3 ~01:40 |
| B2 | Bun (same JS app, no rewrite) | 4,200 users (~389 rps), +30% vs Node. "I will definitely use Bun in the future." | V3 ~02:20 |
| B3 | Python FastAPI + Uvicorn (3 workers) | 2,150 users, ~200 rps; at 2,300 users 15% of requests failed — connections froze waiting on the DB pool. "Disappointing" (he's a Python dev). | V3 ~03:00 |
| B4 | PHP Laravel [ASR: "Laravel 13"] + PHP-FPM (10 workers, opcache/config/route cache) | 750 users — "terrible result"; framework boot dominates for a light API. Worst-case scenario for Laravel, he concedes. | V3 ~03:50 |
| B5 | Laravel Octane (attempt) | 1,250 users, raw throughput +50% — app stays in memory. | V3 ~04:30 |
| B6 | Bare PHP + PHP-FPM (Laravel removed) | 2,700 users, ~4× Laravel. | V3 ~04:45 |
| B7 | C# ASP.NET Core | 4,400 users (+35% vs Node), P95 442 / P99 789. Npgsql resets pooled connections with `discard all` — driver default generated huge extra DB work; left unoptimized to stay default. App ~25% CPU vs Postgres ~60%. | V3 ~05:10 |
| B8 | Java 21 + Spring Boot 3 (MVC, Tomcat) | 5,100 users (~500 rps), +57% vs Node. JVM peaked ~600MB on a 2GB box. | V3 ~07:00 |
| B9 | Go (standard net/http) | 6,500 users, 600+ rps. Go 24% CPU, Postgres 60% — DB became the bottleneck. | V3 ~07:40 |
| B10 | Rust Axum + SQLx | 6,900 users, ~640 rps [ASR garbles this as "609,000 users"]. Beat Go by 6% — within run noise; "same speed category". Rust 22% CPU, Postgres ~60%. | V3 ~08:10 |
| B11 | Postgres→SQLite swap (WAL mode) | Java 5,100→**10,250**; Go 6,500→**11,750**; Rust 6,900→**14,050** (P95 242 / P99 ~459, 1,300 rps, ~5ms median). 14,050 = the V1-referenced "14,000" best of the old video. | V3 ~09:00–11:00 |

## C. Baseline setup (V2 — the original video, no submissions)

| # | Stack | What he said | Video |
|---|---|---|---|
| C1 | Nginx + Node.js + Postgres, all on one $12 DigitalOcean droplet (1 vCPU shared, 2GB RAM, 50GB SSD, Ubuntu); 50k users / 500k posts / 2M likes (~360MB DB); K6 virtual users (~0.1 rps each); thresholds P95<500ms, P99<1s, errors<1% over 5 min | ~2,500 concurrent users sustained. Bottleneck CPU (~80%). Raw feed throughput 280 rps. | V2 (whole video) |
| C2 | + in-Node feed cache | 4,000 users; raw feed 1,200 rps. | V2 ~09:00 |
| C3 | + Nginx cache | ~5,200 users; raw feed >10,000 rps (load generator became the bottleneck). | V2 ~10:15 |

## D. Cross-check: transcript mentions vs upstream main vs local eval folders

Upstream `arjaythedev/twelve-dollar-server-challenge` `submissions/` (via `gh api`, 2026-10-19): `README.md`, `fortran-microhttpd-tbsvttr`, `python-fastapi-cknutson12`. Local eval folders: `lua-lunet-simbo1905`, `fortran-microhttpd-tbsvttr`, `python-fastapi-cknutson12`.

| Transcript-mentioned solution | On upstream main? | Notes |
|---|---|---|
| Ruby Rails #1 / #2 (A1, A2) | absent | not in submissions/ |
| Ruby Iodine (A3) | absent | not in submissions/ |
| Erlang Cowboy (A4) | absent | not in submissions/ |
| Python FastAPI (A5/A6) | **present** as `python-fastapi-cknutson12` | one of the two FastAPI entries (11k or 22k variant — folder present both upstream and locally) |
| Go (A7) | absent | he explicitly invited Go PRs |
| C# Kestrel (A8) | absent | |
| Fortran libmicrohttpd (A9) | **present** as `fortran-microhttpd-tbsvttr` | folder present both upstream and locally |
| PHP Swoole #1/#2 (A10, A11) | absent | |
| C io_uring (A12) | absent | |
| TypeScript-on-Bun raw sockets (A13) | absent | |
| Rust Axum (A14) | absent | |
| Rust io_uring (A15) | absent | |
| Zig uSockets (A16) | absent | |
| C++ entries ×2 @61k (A17, A18) | absent | |
| C++ single-file winner (A19) | absent | |
| C++ in-memory DQ (A20) | absent | lives "on my GitHub" per author |
| R entry (A21) | absent | never started |
| Java / Node entries (A22, A23) | absent (zero ever received) | |
| Lua (our `lua-lunet-simbo1905`) | not on upstream main (local only, PR pending) | **Lua is not among the 13 languages he lists in V1** — our submission is outside the video's field |

## E. Capture notes / failures

- No manual (human-made) subs exist on any of the three videos; all captions are auto-ASR (Dutch audio), translated to English.
- Local `yt-dlp` subtitle downloads 429'd on every client (default/tv/android) — IP-level rate limit on `youtube.com/api/timedtext`. Worked around by fetching the caption tracks from inside a real Chrome session on youtube.com (cookies) — succeeded.
- The browser transcript panel itself failed (`POST /youtubei/v1/get_transcript` → 400 FAILED_PRECONDITION, YouTube-side); the timedtext track fetch was the working path.
- Files: `.tmp/videos_cc/QGWKCaglSBI.en.vtt|en.txt|en.flow.txt`, `.tmp/videos_cc/GFtFIxrAjIs.en.vtt|en.txt|en.flow.txt`, `.tmp/videos_cc/sQXFhh_PiG4.en.vtt|en.txt|en.flow.txt` (+ probe/debug JSONs).
