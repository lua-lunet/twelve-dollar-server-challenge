#!/usr/bin/env bash
# Fetches the pinned lunet v0.9.2 release archive and stages it into .lunet/.
# This is an install of a pinned official release, not a source build. Run as a
# normal user; re-running is safe.
set -euo pipefail

LUNET_VERSION=v0.9.2
BASE_URL="https://github.com/lua-lunet/lunet/releases/download/$LUNET_VERSION"

case "$(uname -s)-$(uname -m)" in
    Darwin-*)            ASSET=lunet-macos.tar.gz ;      DIGEST=f8b795d02e4c6860da84ba23d52db34007fe474e82be16789c6665d1dfa5e878 ;;
    Linux-x86_64)        ASSET=lunet-linux-amd64.tar.gz; DIGEST=d242a272ac9940f976a7df9d021d5c8c5d956a8763a4047594e98eadc7bed31a ;;
    Linux-aarch64)       ASSET=lunet-linux-arm64.tar.gz; DIGEST=087422bb091ef70ddf89d4cc1f069e6192a8159f035f363a8afd2f3dea940fc4 ;;
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
