#!/usr/bin/env bash
# Fetches the pinned lunet v0.11.0 release archive and stages it into .lunet/.
# This is an install of a pinned official release, not a source build. Run as a
# normal user; re-running is safe.
set -euo pipefail

LUNET_VERSION=v0.11.0
BASE_URL="https://github.com/lua-lunet/lunet/releases/download/$LUNET_VERSION"

case "$(uname -s)-$(uname -m)" in
    Darwin-*)            ASSET=lunet-macos.tar.gz ;      DIGEST=0c252b0183ccc5f11ff042d3b28b253d99bc7ed9671697701684a77df689c344 ;;
    Linux-x86_64)        ASSET=lunet-linux-amd64.tar.gz; DIGEST=1f08344b882bdb98adb514b0ed1781f617c58282a115c7d13c9e5c905cf28317 ;;
    Linux-aarch64)       ASSET=lunet-linux-arm64.tar.gz; DIGEST=425899a2f1e137eebeb865b5f3b1ff6f6a786303d2166bf4d34d6c38e4544b5f ;;
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
