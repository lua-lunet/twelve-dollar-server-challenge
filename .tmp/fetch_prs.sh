#!/usr/bin/env bash
# Fetch PR-head submissions into the eval tree. One explicit block per PR, no loops, no set -e/pipefail.
cd ~/evaluations
VENT=.vent_extract

grab() {
  OWNER="$1"; REPO="$2"; REF="$3"; NAME="$4"
  curl -sL -o "$NAME.zip" "https://codeload.github.com/$OWNER/$REPO/zip/refs/heads/$REF"
  rm -rf "$VENT" && mkdir -p "$VENT"
  unzip -qo "$NAME.zip" -d "$VENT" || { echo "UNZIPFAIL $NAME"; return 1; }
  SRC=$(find "$VENT" -type d -path "*/submissions/$NAME" | head -1)
  if [ -z "$SRC" ]; then SRC=$(find "$VENT" -maxdepth 2 -type d -name "$NAME" | head -1); fi
  if [ -z "$SRC" ]; then echo "NOPATH $NAME: $(ls "$VENT")"; return 1; fi
  rm -rf "twelve-dollar-server-challenge-main/submissions/$NAME"
  cp -r "$SRC" twelve-dollar-server-challenge-main/submissions/
  echo "OK $NAME -> $(ls twelve-dollar-server-challenge-main/submissions/$NAME | tr '\n' ' ')"
}

rm -rf "$VENT"

grab mjc twelve-dollar-server-challenge rust-axum-mjc rust-axum-mjc
rm -rf "$VENT"
grab ssmurfgg04-gif twelve-dollar-server-challenge c-iouring-pr c-iouring-ssmurfgg04-gif
rm -rf "$VENT"
grab 27bhd twelve-dollar-server-challenge submission/c-iouring-27bhd c-iouring-27bhd
rm -rf "$VENT"
grab marler8997 twelve-dollar-server-challenge zig-iouring-marler8997 zig-iouring-marler8997
rm -rf "$VENT"
grab Vijay-Highlo twelve-dollar-server-challenge csharp-aspnetcore-vijay-highlo csharp-aspnetcore-vijay-highlo
rm -rf "$VENT"
grab brocchirodrigo twelve-dollar-server-challenge bun-elysia-brocchirodrigo bun-elysia-brocchirodrigo
rm -rf "$VENT"
grab fi5HiE twelve-dollar-server-challenge add-go-nethttp-fi5HiE go-nethttp-fi5HiE
rm -rf "$VENT"
grab zahidcakici twelve-dollar-server-challenge node-uwebsockets-zahidcakici node-uwebsockets-zahidcakici
rm -rf "$VENT"
grab framegrace twelve-dollar-server-challenge bash-socat-framegrace bash-socat-framegrace
rm -rf "$VENT"
grab yar0slav twelve-dollar-server-challenge main nginx-brrrrr-yar0slav
rm -rf "$VENT"
grab stohirov twelve-dollar-server-challenge java-nio-stohirov java-nio-stohirov
rm -rf "$VENT"
grab melroy89 twelve-dollar-server-challenge php-codeigniter-melroy89 php-codeigniter-melroy89
rm -rf "$VENT"

ls twelve-dollar-server-challenge-main/submissions/
