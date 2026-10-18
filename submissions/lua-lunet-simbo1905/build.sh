#!/usr/bin/env bash
# Fetches the pinned lunet v0.13.0 release archive and stages it into .lunet/.
# This is an install of a pinned official release, not a source build. Run as a
# normal user; re-running is safe.
set -euo pipefail

LUNET_VERSION=v0.13.0
BASE_URL="https://github.com/lua-lunet/lunet/releases/download/$LUNET_VERSION"

case "$(uname -s)-$(uname -m)" in
    Darwin-*)            ASSET=lunet-macos.tar.gz ;      DIGEST=8cc883cc87cfe06c37362448c0dab981053b98641e9fc31ab0fd538e4b5a36bb ;;
    Linux-x86_64)        ASSET=lunet-linux-amd64.tar.gz; DIGEST=c3c43094ca919be244e26fe1962e16c02e327f2e724a29dc1c96c0638c9e71d7 ;;
    Linux-aarch64)       ASSET=lunet-linux-arm64.tar.gz; DIGEST=eaf3ae2860b51b7d80559bd7b0f6e5bd7b829a02346ef5ab6126024787ed715f ;;
    *) echo "build.sh: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

URL="$BASE_URL/$ASSET"
ARCHIVE="$(mktemp -d)/$ASSET"

cd "$(dirname "$0")"

echo "== fetching $URL"
curl -fsSL -o "$ARCHIVE" "$URL"

echo "== verifying sha256"
actual="$(sha256sum "$ARCHIVE" 2>/dev/null || shasum -a 256 "$ARCHIVE")"
actual="${actual%% *}"
[ "$actual" = "$DIGEST" ] || { echo "sha256 mismatch: want $DIGEST got $actual" >&2; exit 1; }
echo "   ok"

echo "== staging .lunet/"
rm -rf .lunet
mkdir .lunet
tar -xzf "$ARCHIVE" -C .lunet

# smoke test
echo 'require("lunet"); require("lunet.socket"); require("lunet.sqlite3"); require("lunet.jsonic"); print("ok")' > .lunet/.smoke.lua
./.lunet/lunet-run .lunet/.smoke.lua
rm .lunet/.smoke.lua

echo "build.sh: $LUNET_VERSION staged in .lunet/ from $ASSET"
