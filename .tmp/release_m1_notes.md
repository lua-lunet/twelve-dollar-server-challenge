# twelve-dollar-challenge-Http11Probe v1.0.0-M1

The challenge fuzz rig stripped down from the ORIGINAL MDA2AV/Http11Probe (rebased onto its main): a compliance probe that fuzzes the five official twelve-dollar-server-challenge endpoints, bad requests first, the good request last, fail-fast per endpoint.

## What it tests
- `GET /health`, `GET /feed`, `GET /posts/:id`, `POST /posts`, `POST /posts/:id/like` — in that order.
- Per endpoint: transport fuzz (valid chunked body must be accepted; plain HTTP/1.0 with Host is served 2xx + connection close; pipelined pair 2xx+2xx; malformed request line closes the connection), then the app-level contract fuzz (exact spec error bodies), then the good value.
- Verdict: PASS iff every endpoint is fully green; every failure names the step, expected, and got.
- The probe is db-blind: it takes `--host`, `--port`, `--token`, `--known-post-id`. DB reset is the runner's job.
- `--profile subset` restores lunet's subset lens (501/400/hard-400); generic (default) applies the original probe's allow-list matrices.

## Provenance
- Fork lineage: MDA2AV/Http11Probe (original) -> uNetworkingAB fork -> this repo, rebased so this tree's parent is the ORIGINAL's main (47883da) with the strip + fix commits on top (50ad862, 5a92776, 86d77c3).
- Verified: positive control (compliant mock) passes the generic profile; negative control (lunet v0.14.1) honestly fails generic and passes subset. The full sweep runs against real challenge submissions in the lima box: six PASS (lua, fortran, python, bun, go, openresty), five named-cause FAILs, one arch-locked.
- Docs say the fork is customised to test a valid submission.

## Usage
```sh
dotnet src/Http11Probe.Cli --host 127.0.0.1 --port 3000 --token <bearer> --known-post-id 1
```
Build: `dotnet publish src/Http11Probe.Cli -c Release`.
