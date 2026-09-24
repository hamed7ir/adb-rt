# adb-rt :: the ONE place absolute paths are configured.
#
# Every script under scripts/ sources this file. Nothing else in the repo hardcodes a
# location, and the repo root is derived from the script's own path -- so a clone builds
# wherever it is put.
#
# Every value uses the `: "${VAR:=default}"` form, so an exported environment variable always
# wins over the default. The four shared variables below (RT2, VCTOOLS, WINSDK, WINSDKVER)
# have the SAME NAMES in ffmpeg-rt, adb-rt and scrcpy-rt, so exporting them once configures
# all three:
#
#     export RT2=/c/toolchains/llvm-rt/stage2/bin
#     export VCTOOLS="/c/BuildTools/VC/Tools/MSVC/14.44.35207"
#
# The defaults are the values this project was actually built and device-verified with.

# ---- repo root, derived. Never hardcode it. -----------------------------------------------
if [ -z "${ADB_ROOT:-}" ]; then
  ADB_ROOT=$(cd "$(dirname "${ADB_SELF:-$0}")/.." 2>/dev/null && pwd)
  [ -f "$ADB_ROOT/config.sh" ] || ADB_ROOT=$(cd "$(dirname "$0")" && pwd)
fi
# Windows form, for anything handed to a native tool or written into a response file.
ADB_ROOT_W=$(cygpath -m "$ADB_ROOT" 2>/dev/null || echo "$ADB_ROOT")
export ADB_ROOT ADB_ROOT_W

# ---- 1. the compiler -- rt2, LLVM 23.1.1-rt2 ----------------------------------------------
# WARNING must report 23.1.1-rt2. LLVM 18.x also lives on the original build machine under a
# one-character-different path, and it builds everything silently and wrongly.
#
# The version string is the cheap check; these sha256 digests are the identifier, recorded
# from the build that produced every binary this project has shipped:
#   clang-cl.exe  ac6be213400d2449c53110b46bdae83b0fa41ea666ab27666ec46bc05c66465d
#   lld-link.exe  5f0903cab3d018f0d6b34e3b14ccb55292d5f6896d94c68abe6fe1c44b32e040
#   llvm-rc.exe   aa46ee08dfc41ecfba6925ccd55ef01b7c14a15713be98bfdd2f8f97ac6f59f0
: "${RT2:=D:/repo/llvm-rt/stage2/bin}"

# ---- 2. the MSVC toolset ------------------------------------------------------------------
# WARNING 14.51 (VS 2026) hard-#errors on ARM32 -- vadefs.h:15, "Support for 32-bit ARM has
# been permanently removed" -- and clang-cl auto-selects the NEWEST toolset unless pinned.
: "${VCTOOLS:=D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207}"

# ---- 3. the Windows SDK -------------------------------------------------------------------
# WARNING 10.0.19041.0 is the LAST SDK shipping ARM32 um/ucrt import libraries.
: "${WINSDK:=D:/Windows Kits/10}"
: "${WINSDKVER:=10.0.19041.0}"

# ---- 4. host build tools ------------------------------------------------------------------
# Native Windows cmake/ninja invoked from an MSYS2 shell. Do NOT substitute MSYS2's cmake.
: "${CMAKE:=D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe}"
: "${NINJA:=D:/Program Files/vs22buildtools/Common7/IDE/CommonExtensions/Microsoft/CMake/Ninja/ninja.exe}"

# ---- derived --------------------------------------------------------------------------------
: "${BUILD:=$ADB_ROOT/build}"
: "${DIST:=$ADB_ROOT/dist}"
: "${DEPS:=$ADB_ROOT/deps}"
export RT2 VCTOOLS WINSDK WINSDKVER CMAKE NINJA BUILD DIST DEPS
mkdir -p "$BUILD" 2>/dev/null || true

# ---- the gate ------------------------------------------------------------------------------
rt_check_config() {
  _bad=0
  for _v in RT2 VCTOOLS WINSDK CMAKE NINJA; do
    eval "_p=\$$_v"
    case "$_v" in
      CMAKE|NINJA) [ -f "$_p" ] || { echo "config: $_v not found: $_p"; _bad=1; } ;;
      *)           [ -d "$_p" ] || { echo "config: $_v not found: $_p"; _bad=1; } ;;
    esac
  done
  [ -d "$WINSDK/Lib/$WINSDKVER/um/arm" ] || {
    echo "config: no ARM32 import libraries at $WINSDK/Lib/$WINSDKVER/um/arm"
    echo "        SDK 10.0.19041.0 is the last one that ships them."; _bad=1; }
  if [ "$_bad" -eq 0 ]; then
    _v=$("$RT2/clang-cl.exe" --version 2>/dev/null | head -1)
    case "$_v" in
      *23.1.1-rt2*) echo "config OK: $_v" ;;
      "")  echo "config: clang-cl.exe not runnable at \$RT2 ($RT2)"; _bad=1 ;;
      *)   echo "config: WRONG COMPILER -- $_v (expected 23.1.1-rt2)"; _bad=1 ;;
    esac
  fi
  [ "$_bad" -eq 0 ] || { echo; echo "Edit config.sh, or export the variables. See README."; return 1; }
  return 0
}
