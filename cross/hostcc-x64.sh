#!/bin/sh
# ffmpeg-rt: HOST compiler for the x64 tools FFmpeg runs during the build.
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

exec "$RT2/clang-cl.exe" \
     "@$ADB_ROOT_W/cross/x64-msvc.rsp" -MT "$@"
