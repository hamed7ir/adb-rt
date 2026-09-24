# msvc-posix-compat — the mingw-w64 gap, as build infrastructure

AOSP builds Windows adb with **mingw-w64**, whose libc ships `unistd.h`, `dirent.h` and
`sys/cdefs.h`. **MSVC's UCRT ships none of them.** adb and libbase include them
unconditionally, so 38 of adb's 49 sources fail at the first include under clang-cl.

This directory supplies them **from outside both source trees**, so closing the mingw gap
costs **no source change at all**. `deps/libbase` stays byte-identical to upstream;
`deps/adb-35.0.2` carries only patches 0001 and 0003, and neither is a mingw-vs-MSVC fix —
both are portability bugs that are upstreamable to AOSP.

Safe by construction: `sysdeps.h` pulls the libbase headers at lines 35-41, explicitly
"before open/close/isatty/unlink are defined as macros below" — the POSIX-name poison block
starts at line 95. These headers therefore land *before* the poisoning, never after.

None of these names collide with a real UCRT header; each file MSVC actually provides is
left alone.
