#!/bin/sh
# ffmpeg-rt: TARGET C compiler. clang-cl driver, MSVC ABI, ARM32, static CRT (-MT).
# The @rsp carries -vctoolsdir etc: their values contain a space and cannot
# survive configure's word splitting as bare flags.
# NEVER pass that rsp via --extra-cflags: configure feeds --extra-cflags to the
# ASSEMBLER too (configure:5509), and those flags are clang-cl-only.
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

exec "$RT2/clang-cl.exe" \
     "@$ADB_ROOT_W/cross/arm32-msvc.rsp" -MT "$@"
