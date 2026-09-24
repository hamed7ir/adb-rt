#!/bin/sh
# adb-rt :: fetch every upstream source this repo builds against.
#
# Nothing upstream is committed here. This script reconstructs deps/ from pinned, public refs,
# so the build is reproducible without redistributing anybody else's tree. The three source
# changes live in patches/ and are applied by this script, so the patch count stays visible.
#
# WHY GIT, NOT THE googlesource ARCHIVE TARBALL, FOR THE AOSP COMPONENTS
#   `https://android.googlesource.com/<repo>/+archive/<ref>.tar.gz` regenerates the tarball on
#   every request. MEASURED: two fetches of the same libbase archive seconds apart returned
#   different sha256 -- and differed after decompression too, so even a content pin fails. The
#   adb repo's archive endpoint answers 503 outright. A sha256 on those URLs would be a pin
#   that cannot hold. Git commit SHAs are the real pin, so this script uses them.
#
# The tarball pins below ARE stable, and every one was re-fetched from the URL written here and
# re-hashed before it was recorded.
set -u

ADB_SELF=$0
ADB_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ADB_ROOT/config.sh"

# Normalise to a POSIX path before tar sees it. GNU tar reads a leading "C:" in
# `-C C:/Users/...` as a REMOTE HOST: "Cannot connect to C: resolve failed". Measured.
DEPS=$(cygpath -u "$DEPS" 2>/dev/null || echo "$DEPS")
mkdir -p "$DEPS"

# ---- the pins ------------------------------------------------------------------------------
AOSP=https://android.googlesource.com/platform
AOSP_TAG=platform-tools-35.0.2
# These are the COMMIT SHAs the tag points at, not the tag objects.
# platform-tools-35.0.2 is an ANNOTATED tag, so `git ls-remote <url> refs/tags/<tag>` returns
# the TAG OBJECT's sha -- which `git rev-parse HEAD` in a clone will never equal. Measured: a
# first version of this script pinned 8d00a4f2 for libbase and rejected a perfectly correct
# checkout of 328768fa. Peel it with `refs/tags/<tag>^{}`.
ADB_SHA=ce9ea51f30f69f7560db692f7cb4d5d5502c3653      # platform/packages/modules/adb
LIBBASE_SHA=328768fabb054387ad7f64c984d4afcea70d25c9  # platform/system/libbase
CORE_SHA=90e4908e776d2be9b26b87af649e63e4208cf085     # platform/system/core

# BoringSSL at the revision AOSP itself pins for this drop, read from
# external/boringssl/BORINGSSL_REVISION. Chosen over main because adb 35.0.2 is written
# against that API and BoringSSL churns. There is no tag on it, hence clone_commit.
BSSL_URL=https://boringssl.googlesource.com/boringssl
BSSL_SHA=a0cb538b0d0d08371d3bd5712bbc8d474d28090a

# libusb 1.0.28, NOT 1.0.27: adb 35.0.2's client/usb_libusb.cpp calls the SuperSpeed+ BOS
# descriptor API, which 1.0.27 does not declare.
LIBUSB_URL=https://github.com/libusb/libusb/releases/download/v1.0.28/libusb-1.0.28.tar.bz2
LIBUSB_SHA=966bb0d231f94a474eaae2e67da5ec844d3527a1f386456394ff432580634b29

BROTLI_URL=https://github.com/google/brotli/archive/refs/tags/v1.1.0.tar.gz
BROTLI_SHA=e720a6ca29428b803f4ad165371771f5398faba397edf6778837a18599ea13ff

LZ4_URL=https://github.com/lz4/lz4/archive/refs/tags/v1.9.4.tar.gz
LZ4_SHA=0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b

ZSTD_URL=https://github.com/facebook/zstd/archive/refs/tags/v1.5.6.tar.gz
ZSTD_SHA=30f35f71c1203369dc979ecde0400ffea93c27391bfd2ac5a9715d2173d92ff7

# The protobuf RELEASE asset, not the tag archive: they are different tarballs with different
# hashes, and the release asset is the one that unpacks to protobuf-3.21.12/.
PROTOBUF_URL=https://github.com/protocolbuffers/protobuf/releases/download/v21.12/protobuf-cpp-3.21.12.tar.gz
PROTOBUF_SHA=4eab9b524aa5913c6fffb20b2a8abf5ef7f95a80bc0701f3a6dbb4c607f73460

# ---- the hash check, self-tested first -------------------------------------------------------
# A verifier that cannot fail is not a verifier. This project has shipped four instruments that
# reported PASS while broken, so the checker proves it can say NO before it says YES.
sha_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
_probe=$DEPS/.sha-selftest
printf 'abc' > "$_probe"; _pos=$(sha_of "$_probe")
printf 'abd' > "$_probe"; _neg=$(sha_of "$_probe")
rm -f "$_probe"
if [ "$_pos" != ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]; then
  echo "sha256sum self-test FAILED: the known vector came back as '$_pos'."
  echo "The checker is broken. Every 'matches the pin' below would be meaningless. Stop."
  exit 2
fi
if [ "$_neg" = "$_pos" ]; then
  echo "sha256sum self-test FAILED in the NEGATIVE direction: two different inputs hashed alike."
  exit 2
fi
echo "checker OK: matches the known vector, and rejects a one-byte change."

WIN() { cygpath -w "$1" 2>/dev/null || echo "$1"; }

# ---- helpers ---------------------------------------------------------------------------------
# curl and git here are NATIVE Windows binaries: a /d/... argument reaches them verbatim under
# MSYS2 and they cannot open it. curl reports "(23) client returned ERROR on write", git reports
# "repository does not exist" -- both are path faults wearing someone else's costume.

fetch_tar() {   # fetch_tar <url> <tarball-name> <expected-sha> <expected-top-dir> [tar-args...]
  _url=$1; _tbname=$2; _tb=$DEPS/$2; _sha=$3; _name=$4; _top=$DEPS/$4
  shift 4   # note: everything above reads $1..$4 BEFORE this, because set -u makes a
            # post-shift "$4" a fatal "unbound variable" rather than an empty string.
  echo "=== $_name ==="
  if [ -f "$_tb" ]; then
    echo "  have: $_tbname"
  else
    echo "  download: $_url"
    curl -fsSL --max-time 900 "$_url" -o "$(WIN "$_tb")" || { echo "  DOWNLOAD FAILED"; return 1; }
  fi
  _got=$(sha_of "$_tb")
  if [ "$_got" != "$_sha" ]; then
    echo "  sha256:    $_got"
    echo "  EXPECTED   $_sha"
    echo "  The pin did not match. Do not build from this tarball until you know why."
    return 1
  fi
  echo "  sha256 matches the pin."
  if [ -d "$_top" ]; then
    echo "  extracted already: deps/$_name"
  else
    # "$@" carries per-tarball tar arguments; see the zstd call for why one needs them.
    tar --force-local -xf "$_tb" -C "$DEPS" "$@" || { echo "  EXTRACT FAILED"; return 1; }
    [ -d "$_top" ] || { echo "  tarball did not produce deps/$_name"; return 1; }
    echo "  extracted: deps/$_name ($(find "$_top" -type f | wc -l) files)"
  fi
  return 0
}

clone_tag() {   # clone_tag <url> <tag> <dest> <expected-sha>
  _url=$1; _tag=$2; _dest=$DEPS/$3; _sha=$4
  echo "=== $3 @ $_tag ==="
  if [ -d "$_dest" ]; then
    echo "  have: deps/$3"
  else
    echo "  clone: $_url"
    # -c core.autocrlf=false: on Windows git's default rewrites every checked-out file to
    # CRLF, so the fetched tree would NOT be byte-identical to the tarball-extracted tree the
    # shipped binary was built from. Measured: content-identical, 126 bytes larger. Harmless
    # for C++, but it makes any hash comparison against upstream meaningless.
    git clone -q --depth 1 -c core.autocrlf=false -c core.eol=lf         --branch "$_tag" "$_url" "$(WIN "$_dest")" || { echo "  CLONE FAILED"; return 1; }
  fi
  _got=$(git -C "$(WIN "$_dest")" rev-parse HEAD 2>/dev/null)
  echo "  HEAD: ${_got:-<not a git checkout>}"
  if [ -n "$_got" ] && [ "$_got" != "$_sha" ]; then
    echo "  EXPECTED $_sha"
    echo "  The tag has moved, or this tree is not what the repo was built against. Stop."
    return 1
  fi
  return 0
}

clone_commit() { # clone_commit <url> <sha> <dest>   -- for a revision with no tag
  _url=$1; _sha=$2; _dest=$DEPS/$3
  echo "=== $3 @ $_sha ==="
  if [ -d "$_dest/.git" ]; then
    echo "  have: deps/$3"
  else
    mkdir -p "$_dest"
    git -C "$(WIN "$_dest")" init -q || return 1
    # BoringSSL carries paths like pki/testdata/verify_certificate_chain_unittest/
    # intermediate-wrong-signature-no-authority-key-identifier/generate-chains.py. On Windows
    # that exceeds MAX_PATH once the clone is more than a couple of directories deep, and the
    # checkout dies with "Filename too long" -- MEASURED here, on a deep scratch directory.
    git -C "$(WIN "$_dest")" config core.longpaths true
    # see clone_tag for why autocrlf is forced off
    git -C "$(WIN "$_dest")" config core.autocrlf false
    git -C "$(WIN "$_dest")" config core.eol lf
    git -C "$(WIN "$_dest")" remote add origin "$_url" 2>/dev/null
    echo "  fetching one commit; the server packs it on demand, so this takes a few minutes"
    git -C "$(WIN "$_dest")" fetch -q --depth 1 origin "$_sha" || { echo "  FETCH FAILED"; return 1; }
    git -C "$(WIN "$_dest")" checkout -q FETCH_HEAD || return 1
  fi
  # rev-parse ECHOES ITS ARGUMENT when HEAD is unborn, so a failed checkout reports
  # "HEAD: HEAD" rather than an error. Reject anything that is not 40 hex characters.
  _got=$(git -C "$(WIN "$_dest")" rev-parse HEAD 2>/dev/null)
  case "$_got" in
    [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]*) : ;;
    *) echo "  NO CHECKOUT: rev-parse returned '${_got:-}' -- the checkout did not complete"
       return 1 ;;
  esac
  echo "  HEAD: $_got"
  [ "$_got" = "$_sha" ] || { echo "  EXPECTED $_sha"; return 1; }
  return 0
}

get_file() {    # get_file <repo-url> <commit> <path-in-repo> <dest> <expected-sha>
  _repo=$1; _rev=$2; _path=$3; _dest=$4; _sha=$5
  if [ ! -f "$_dest" ]; then
    mkdir -p "$(dirname "$_dest")"
    # googlesource answers 503 under load. MEASURED: one of these four files failed that way
    # on the first run of this script while the other three succeeded. Retry, do not give up.
    _try=1
    while [ "$_try" -le 5 ]; do
      if curl -fsSL --max-time 120 "$_repo/+/$_rev/$_path?format=TEXT" -o "$(WIN "$_dest.b64")"; then
        break
      fi
      [ "$_try" -lt 5 ] && echo "  retry $_try/5 after 503 or timeout: $_path"
      sleep $((_try * 3))
      _try=$((_try + 1))
    done
    [ -s "$_dest.b64" ] || { echo "  FETCH FAILED after 5 tries: $_path"; return 1; }
    base64 -d "$_dest.b64" > "$_dest" 2>/dev/null || return 1
    rm -f "$_dest.b64"
  fi
  _got=$(sha_of "$_dest")
  if [ "$_got" != "$_sha" ]; then
    printf '  %-46s sha256 MISMATCH\n     got %s\n     exp %s\n' "$_path" "$_got" "$_sha"
    return 1
  fi
  printf '  %-46s ok (%s lines)\n' "$_path" "$(wc -l < "$_dest")"
  return 0
}

# ---- fetch ------------------------------------------------------------------------------------
FAIL=0

clone_tag "$AOSP/packages/modules/adb" "$AOSP_TAG" adb-35.0.2 "$ADB_SHA"     || FAIL=1
clone_tag "$AOSP/system/libbase"       "$AOSP_TAG" libbase    "$LIBBASE_SHA" || FAIL=1

# Two small AOSP libraries live inside platform/system/core, which is large and mostly
# irrelevant here. Four files, pinned by commit and by content hash, is the proportionate fetch.
echo "=== libdiagnose_usb + libcrypto_utils @ $CORE_SHA ==="
CORE=$AOSP/system/core
get_file "$CORE" "$CORE_SHA" diagnose_usb/diagnose_usb.cpp \
         "$DEPS/libdiagnose_usb/diagnose_usb.cpp" \
         0c96b58e230a6c8dc537391893d40a3e848016632808cc7313f25e84ab880b47 || FAIL=1
get_file "$CORE" "$CORE_SHA" diagnose_usb/include/diagnose_usb.h \
         "$DEPS/libdiagnose_usb/include/diagnose_usb.h" \
         a77d70fd616d4c70ba1790253bf20fa0e3ae3ccf02eccc8171caff2c3af3f03a || FAIL=1
# NOTE: android_pubkey.CPP at this tag, not .c -- the file was converted to C++ upstream.
get_file "$CORE" "$CORE_SHA" libcrypto_utils/android_pubkey.cpp \
         "$DEPS/libcrypto_utils/android_pubkey.cpp" \
         31068871b013c250c8cc3595560d415cdc4256c8bda4c9c2401d93835b86a9c5 || FAIL=1
get_file "$CORE" "$CORE_SHA" libcrypto_utils/include/crypto_utils/android_pubkey.h \
         "$DEPS/libcrypto_utils/include/crypto_utils/android_pubkey.h" \
         5e04b026c14f0fe94e2403008a1819dd9796b0afffef5ceef953411f1bee66a0 || FAIL=1

clone_commit "$BSSL_URL" "$BSSL_SHA" boringssl-pinned || FAIL=1

fetch_tar "$LIBUSB_URL"   libusb-1.0.28.tar.bz2   "$LIBUSB_SHA"   libusb-1.0.28    || FAIL=1
fetch_tar "$BROTLI_URL"   brotli-1.1.0.tar.gz     "$BROTLI_SHA"   brotli-1.1.0     || FAIL=1
fetch_tar "$LZ4_URL"      lz4-1.9.4.tar.gz        "$LZ4_SHA"      lz4-1.9.4        || FAIL=1
# zstd's tarball contains SYMLINKS under tests/cli-tests/bin/, and Windows tar cannot create
# them without the developer-mode or SeCreateSymbolicLink privilege: it fails the whole
# extraction with "Cannot create symlink to 'zstd'". Only lib/ is built here, so excluding the
# test tree is both the fix and the honest scope. Measured on the first run of this script.
fetch_tar "$ZSTD_URL"     zstd-1.5.6.tar.gz       "$ZSTD_SHA"     zstd-1.5.6           --exclude='zstd-1.5.6/tests/*' || FAIL=1
fetch_tar "$PROTOBUF_URL" protobuf-3.21.12.tar.gz "$PROTOBUF_SHA" protobuf-3.21.12 || FAIL=1

[ "$FAIL" -eq 0 ] || { echo; echo "One or more components did not match their pin. Stop here."; exit 1; }

# ---- patches -----------------------------------------------------------------------------------
# Applied here rather than vendored, so `ls patches/` stays the honest patch count: 3.
echo
echo "=== patches ==="
apply() {  # apply <patch-file> <tree-under-deps>
  _p=$ADB_ROOT/patches/$1; _t=$DEPS/$2
  [ -f "$_p" ] || { echo "  MISSING: patches/$1"; return 1; }
  [ -d "$_t" ] || { echo "  MISSING TREE: deps/$2"; return 1; }
  # A reverse dry-run is the cheapest "is it already in?" test, and it does not touch the tree.
  if git -C "$(WIN "$_t")" apply --check -p1 --reverse "$(WIN "$_p")" 2>/dev/null; then
    echo "  already applied: $1"; return 0
  fi
  if git -C "$(WIN "$_t")" apply -p1 "$(WIN "$_p")" 2>/dev/null; then
    echo "  applied: $1"; return 0
  fi
  # Not every tree here is a git checkout -- the tarball ones are not -- so fall back to patch(1).
  if (cd "$_t" && patch -p1 -N -r - --silent < "$_p") 2>/dev/null; then
    echo "  applied: $1"; return 0
  fi
  echo "  FAILED TO APPLY: $1 -- the upstream tree is not what this patch was based on"
  return 1
}
apply 0001-adb-from_chars-portable-iterators.patch     adb-35.0.2    || FAIL=1
apply 0002-libusb-backport-windows-hotplug.patch       libusb-1.0.28 || FAIL=1
apply 0003-adb-flush-stdio-before-_exit-in-wmain.patch adb-35.0.2    || FAIL=1
[ "$FAIL" -eq 0 ] || { echo; echo "A patch did not apply. Stop here."; exit 1; }

echo
echo "deps ready. Next:"
echo "  sh scripts/gen-rsp.sh        # expand cross/*.rsp.in against config.sh"
echo "  sh scripts/build-libbase.sh  # then the other build-*.sh, then scripts/link-adb.sh"
