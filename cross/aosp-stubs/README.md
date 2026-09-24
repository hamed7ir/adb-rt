# aosp-stubs — verified-minimal stand-ins for absent AOSP modules

Kept SEPARATE from `msvc-posix-compat/`, which closes the mingw-vs-MSVC libc gap. This
directory stands in for AOSP modules that are not vendored in `deps/` at all.

A stub is only ever added after **measuring** that the Windows host link graph references no
function from the real module — never to make an error disappear. Each file records that
measurement. If a stub ever hides a symbol that is genuinely needed, it will surface at link
(READING D6), not silently.
