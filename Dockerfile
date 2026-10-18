# The $12 Server Challenge submission "lua-lunet": lunet fetched from the
# pinned release (no xmake, no cargo, no compiler toolchain, no Postgres),
# the submission's Lua source on top. No seed data is baked in: mount the
# database and point SQLITE_PATH at it.
#
#   docker run --rm -p 8080:3000 \
#     --mount source=$HOME/.../seed/feed.db,target=/data/feed.db,readonly \
#     -e SQLITE_PATH=/data/feed.db -e JWT_SECRET=... \
#     ghcr.io/<owner>/<repo>:<tag>
#
# The server start carries --dangerously-skip-loopback-restriction: inside a
# container the boundary is the container's, the same posture as the
# realworld-lua image.
# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

COPY submissions/luna-lunet /app

WORKDIR /app

RUN bash install.sh

RUN useradd -m app && chown -R app:app /app

USER app

RUN bash build.sh

ENV HOST=0.0.0.0 PORT=3000

EXPOSE 3000

CMD ["/app/.lunet/lunet-run", "--dangerously-skip-loopback-restriction", "server.lua"]
