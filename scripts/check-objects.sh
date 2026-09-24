#!/bin/sh
# adb-rt: verify a build tree's objects. EXIT 0 IS NOT EVIDENCE.
#
# Three checks, in order of how cheaply they catch a whole failure class:
#
#   1. UNIFORM-SIZE DETECTOR. If N objects from N different sources share one exact byte
#      size, they are empty shells -- a preprocessor guard excluded every body for this
#      target. Measured instance: BoringSSL's 7 ARM32 .S files, gated on defined(__ELF__),
#      each produced exactly 252 bytes with 0 instructions and 0 symbols, exit 0, silent.
#   2. EMPTY-OBJECT CONFIRMATION on the most-repeated size.
#   3. MACHINE-WORD SWEEP with a denominator, because llvm-windres has silently emitted
#      AMD64 objects into an ARM32 build.
#
# ! PATHS: the rt2 tools are NATIVE WINDOWS binaries. Under MSYS2 with
#   MSYS2_ARG_CONV_EXCL='*' (which the builds need) POSIX paths are NOT converted, so a
#   native tool given /d/repo/... opens nothing and reports 0 instructions, 0 symbols,
#   no machine word -- INDISTINGUISHABLE from a genuinely empty or corrupt object.
#   Measured: this reported "12 UNREADABLE + EMPTY OBJECTS" for a libusb build that was
#   in fact perfect. Every path handed to a native tool therefore goes through cygpath -w,
#   and a READER SELF-TEST runs first so a broken reader can never masquerade as a finding.

set -u
# ---- configuration -------------------------------------------------------------------------
# Every absolute path lives in config.sh at the repo root, and the root is derived from THIS
# script's own location, so a clone builds wherever it is placed.
ADB_SELF=$0
ADB_ROOT=$(cd "$(dirname "$0")/.." && pwd)
. "$ADB_ROOT/config.sh"
rt_check_config || exit 1
B="${1:?usage: check-objects.sh <build-dir> [ARMNT|AMD64]}"
WANT="${2:-ARMNT}"
RO="$RT2/llvm-readobj.exe"
OD="$RT2/llvm-objdump.exe"
NM="$RT2/llvm-nm.exe"

w() { cygpath -w "$1"; }

echo "### object check: $B   (expecting $WANT)"

find "$B" \( -name '*.obj' -o -name '*.o' \) > /tmp/objcheck_list.txt
TOTAL=$(wc -l < /tmp/objcheck_list.txt)
echo "objects found = $TOTAL"
[ "$TOTAL" -gt 0 ] || { echo "!!! ZERO OBJECTS - the sweep inspected NOTHING. Not a pass."; exit 1; }

# --- 0. READER SELF-TEST: prove the reader can open a file at all before trusting a zero
PROBE=$(head -1 /tmp/objcheck_list.txt)
if ! "$RO" --file-headers "$(w "$PROBE")" >/dev/null 2>&1; then
  echo "!!! READER SELF-TEST FAILED - llvm-readobj cannot open $PROBE"
  echo "    This is a TOOL/PATH fault, NOT a finding about the build. Fix it before reading"
  echo "    anything below as evidence. (Usual cause: POSIX path handed to a native tool.)"
  exit 2
fi
echo "reader self-test OK (llvm-readobj opened a sample object)"

echo
echo "--- 1. uniform-size detector (most repeated sizes) ---"
find "$B" \( -name '*.obj' -o -name '*.o' \) -printf '%s\n' | sort | uniq -c | sort -rn | head -5 > /tmp/objcheck_sizes.txt
while read -r n sz; do
  if [ "$n" -ge 3 ]; then
    printf "   %4s objects share size %-10s <-- SUSPECT, confirming\n" "$n" "$sz"
  else
    printf "   %4s objects share size %s\n" "$n" "$sz"
  fi
done < /tmp/objcheck_sizes.txt
TOPN=$(head -1 /tmp/objcheck_sizes.txt | awk '{print $1}')
TOPSZ=$(head -1 /tmp/objcheck_sizes.txt | awk '{print $2}')
if [ "$TOPN" -lt 3 ]; then
  echo "   -> max repeat is $TOPN: every object has a distinct size. No empty-shell signal."
fi

echo
echo "--- 2. is the most-repeated size ($TOPN objects at $TOPSZ bytes) empty? ---"
S=$(find "$B" \( -name '*.obj' -o -name '*.o' \) -size "${TOPSZ}c" | head -1)
if [ -n "$S" ]; then
  SW=$(w "$S")
  I=$("$OD" -d "$SW" 2>/dev/null | grep -c '^ *[0-9a-f]*:')
  D=$("$NM" --defined-only "$SW" 2>/dev/null | wc -l)
  echo "   sample: $S"
  echo "   instructions = $I   defined symbols = $D"
  if [ "$I" -eq 0 ] && [ "$D" -eq 0 ]; then
    if [ "$TOPN" -lt 3 ]; then
      echo "   note: only $TOPN object(s) at this size - not the empty-shell pattern, but a"
      echo "   zero-instruction object is still worth a look."
    else
      echo "   !!! EMPTY OBJECTS - $TOPN files compiled to nothing. INVESTIGATE THE GUARDS."
    fi
  else
    echo "   OK - non-empty"
  fi
fi

echo
echo "--- 3. machine-word sweep, with denominator ---"
: > /tmp/objcheck_bad.txt
INSP=0; GOOD=0; BAD=0; UNREAD=0
while read -r o; do
  INSP=$((INSP+1))
  M=$("$RO" --file-headers "$(w "$o")" 2>/dev/null | grep -m1 -i 'Machine:')
  case "$M" in
    "")        UNREAD=$((UNREAD+1)); echo "UNREADABLE $o" >> /tmp/objcheck_bad.txt ;;
    *"$WANT"*) GOOD=$((GOOD+1)) ;;
    *)         BAD=$((BAD+1)); echo "$M  $o" >> /tmp/objcheck_bad.txt ;;
  esac
  printf '%s %s %s %s\n' "$INSP" "$GOOD" "$BAD" "$UNREAD" > /tmp/objcheck_counts.txt
done < /tmp/objcheck_list.txt
read -r INSP GOOD BAD UNREAD < /tmp/objcheck_counts.txt
echo "objects found = $TOTAL, inspected = $INSP, $WANT = $GOOD, other = $BAD, unreadable = $UNREAD"
if [ "$TOTAL" -eq "$INSP" ]; then echo "DENOMINATOR OK"; else echo "!!! DENOMINATOR MISMATCH"; fi
[ -s /tmp/objcheck_bad.txt ] && { echo "--- non-$WANT / unreadable ---"; head -20 /tmp/objcheck_bad.txt; }
if [ "$BAD" -eq 0 ] && [ "$UNREAD" -eq 0 ]; then echo "PASS"; else echo "FAIL"; fi
