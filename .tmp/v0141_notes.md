## Highlights


- **`lunet.http` connections are persistent by default.** Responses no
  longer declare `Connection: close`: the response builders leave the
  connection persistent per HTTP/1.1 (no `Connection` header), and a new
  final `persistent` argument on `http.response`, `http.json_response`,
  `http.error_response` and `http.preflight_response` — `persistent=false`
  — declares `Connection: close`. The connection loop serves sequential
  requests on one connection until the client's EOF, a framing error, or a
  request-declared `Connection: close`, which is honoured with a close
  response and a loop exit (framing errors always answer with a close
  response: a desynchronised stream cannot be resynced). Pipelining stays
  excluded — bytes running past the end of a request body remain a hard
  400. `examples/08_http.lua` serves with the new loop and demonstrates a
  two-requests-one-connection exchange; the connection-loop reference in
  `docs/HTTP.md` / `HTTP-CN.md` shows the wiring.

## Binaries

- `lunet-linux-amd64.tar.gz`
- `lunet-linux-arm64.tar.gz`
- `lunet-macos.tar.gz`
- `lunet-windows-amd64.zip`

## Embeddable SDKs

- `lunet-linux-amd64-sdk.tar.gz`
- `lunet-linux-arm64-sdk.tar.gz`
- `lunet-macos-sdk.tar.gz`
- `lunet-windows-amd64-sdk.zip`

## Quick Start

Fetch a verified, project-local runtime with the release fetcher (SHA-256 checked against the release metadata before extraction):

```bash
curl -fsSLO https://github.com/lua-lunet/lunet/releases/download/v0.14.1/lunet_fetch_release_v0.14.1.lua
lua lunet_fetch_release_v0.14.1.lua   # installs into .lunet/v0.14.1/
.lunet/v0.14.1/lunet-run path/to/app.lua
```


## Defect notice — withdraw when v0.14.2 is adopted

v0.14.1 ships the ext/http framing subset that refuses three transport cases the generic Http11Probe contract requires (tracked upstream as the generic-framing defect, LANDed in v0.14.2 via the http-framing fix): valid `Transfer-Encoding: chunked` bodies are refused 501, plain HTTP/1.0 requests with a Host header are refused 400, and a pipelined request pair is refused with a hard 400. A compliant server must accept valid chunked bodies, serve HTTP/1.0 with Host and then close, and answer a pipelined pair sequentially (2xx+2xx).

This release WILL BE WITHDRAWN once v0.14.2 is available and consumers have moved to it. Pin v0.14.2 in your build of the pinned official release; the digests there cover the fixed framing.
