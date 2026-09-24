#!/bin/sh
# ffmpeg-rt: ASSEMBLER. clang GCC-driver + integrated assembler, which CAN consume
# FFmpeg's GAS-syntax ARM .S files. Replacing --toolchain=msvc's armasm.exe with
# this is the entire reason this port can carry NEON.
# Paths come from config.sh at the repo root; this wrapper derives that root from its own
# location, so it works from any checkout and from whatever cwd configure invokes it in.
_d=$(cd "$(dirname "$0")/.." && pwd)
. "$_d/config.sh"

exec "$RT2/clang.exe" --target=armv7-pc-windows-msvc "$@"
