# MASTER PLAN — simbo1905 branch architecture + submission PR to arjaythedev

Authoritative overall plan for the twelve-dollar-server-challenge submission work. Sidecar task rows reference this gist as the overall plan.

## Context
Fork: lua-lunet/twelve-dollar-server-challenge (origin). Upstream: arjaythedev/twelve-dollar-server-challenge (remote `upstream`, main = c72d994). Our work (submission lunet v0.11.1, 42/42, docker CI trio) is at 967c231 on origin/main AND origin/simbo1905. Divergence vs upstream main among common files: ONLY README.md (operator's formatting fixes upstream: extra "**Correctness**" and "**VM Specs and Info**" subheaders). Ours-only: .dockerignore, .github/workflows/ci.yml, Dockerfile. Upstream-only: two other submissions (fortran-microhttpd-tbsvttr, python-fastapi-cknutson12). Challenge rule: the PR to upstream main must touch ONLY our submission folder, renamed per SPEC to submissions/lua-lunet-simbo1905 ("luna-lunet" was wrong: invented name).

## Target branch architecture
- simbo1905 = fork default branch (operator sets it) = our working/testing branch WITH the docker CI trio restored at tip.
- main = EXACT mirror of upstream/main (c72d994), force-set.
- submission/lua-lunet-simbo1905 = created from main (=c72d994); receives ONE squash-merged commit from simbo1905; its tree = c72d994 + submissions/lua-lunet-simbo1905 only; head of the upstream PR.
- Tags v2026.10.14 (62c7f30) and tuning-spec-2026.10.15 (88736b9) untouched. .env (empty, untracked, operator's) NEVER committed.

## Phases
1. SOAK (Task A then Task B): new lima VM lunet-soak (aarch64 ubuntu-24.04, 1 vCPU, 2GiB, 10GiB disk, vz, port-forward 3000→3000, no home mounts, swap disabled, NO kernel tuning — stock like the scoring droplet). Stage via git archive HEAD. make-seed.sh in-VM (must print OK). install.sh, build.sh (linux-arm64 digest 7b3d5662f1210c6ab0dc4b281f7e829f340c785b683ef27bf738a7661a0f39e9), bin/dev.sh start, curl sanity. Soak: k6 on macOS, VUS=2500, DURATION=5m (default RAMP_UP 60s), ONE leg, no fallback, no looping. Capture checks%, p95/p99, rps, errors, RSS/VmHWM before+after. Result note goes into the submission README (state the box: 1 vCPU/2GiB lima VM, linux-arm64, k6 from macOS host).
2. CLEANUP on simbo1905 (Task C stages; orchestrator commits): merge upstream/main (outside our folder upstream's version always wins); git mv submissions/luna-lunet submissions/lua-lunet-simbo1905; README title "# lua-lunet-simbo1905 — Lua on lunet"; git rm .dockerignore .github/workflows/ci.yml Dockerfile (temporary — restored in phase 5); deleting-dead-code sweep of the submission folder (contents: server.lua, lib/, app/, install.sh, build.sh, start.sh, bin/dev.sh, README.md, .gitignore; ignored: .lunet/, target/). Verify: 42/42 via `bash test/run.sh submissions/lua-lunet-simbo1905`; `git diff upstream/main...simbo1905 --stat` = only submissions/lua-lunet-simbo1905/. Push simbo1905 (triggers nothing: test.yml is main-push-only, ci.yml off tip).
3. FORCE-SET main := upstream/main: `git branch -f main upstream/main && git push --force origin main` (destructive, disclosed: all history remains on simbo1905 + tags). Push triggers upstream's test.yml in the fork testing THEIR fortran submission — expected green (passed upstream); delegated watcher gh-monitors it; sleep-on-fail, re-check once, no looping.
4. SUBMISSION PR (fork): `git checkout -b submission/lua-lunet-simbo1905 main` + push; PR base=submission/lua-lunet-simbo1905 head=simbo1905 (diff = only our folder; merge-base c72d994 after phase-2 merge); gh-monitor (their test.yml runs seed + our install.sh + test/run.sh on clean ubuntu-24.04 amd64 = the amd64 CI proof); sleep-on-fail once; `gh pr merge --squash` → exactly ONE commit; verify rev-list --count upstream/main..submission/lua-lunet-simbo1905 = 1 and diff = only our folder.
5. RESTORE CI on simbo1905: `git checkout <pre-removal simbo1905 commit> -- .dockerignore .github/workflows/ci.yml Dockerfile`, commit, push (CI live for PRs + v* tags). Operator sets default branch.
6. UPSTREAM PR: legality diff first (only our folder, README untouched = operator formatting double-check); `gh pr create --repo arjaythedev/twelve-dollar-server-challenge --head lua-lunet:submission/lua-lunet-simbo1905 --base main` title "Add submission: lua-lunet-simbo1905", factual body (pinned v0.11.1 archive install, SQLite WAL + rw/ro split, keep-alive, 42/42 local + fork CI, soak numbers + box specs); gh-monitor their test.yml; sleep-on-fail once, no looping.

## Constraints (binding)
- gh-monitor skill (lua ~/.agents/skills/git-monitor/gh_monitor/git_monitor.lua) for ALL CI watching; explicit sleeps on failure, re-check once, NO retry loops.
- Subagents NEVER commit or push; orchestrator does all commits/merges/PRs/destructive ops.
- All commits: explicit-path adds only (never git add -A; .env and .tmp/ must never be staged).
- Long commands backgrounded with pid files; tee captures to .tmp/clobber_me_NN.txt (fresh NN per file); never tail/pipe without tee.
- PR/commit messages: engineering tone, no co-author lines, no issue numbers in code/docs.
- nextcloud-dev lima VM is NOT ours: never touch it.
- Wrap: confirm lunet-soak VM disposition (keep/delete) with operator; local checkout ends on simbo1905; sidecar rows closed with outcomes.
