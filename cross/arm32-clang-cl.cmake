# adb-rt: CMake toolchain for armv7/thumbv7 Windows MSVC via rt2 clang-cl.
#
# NOTE: points at clang-cl.exe DIRECTLY, not at cross/cc-arm32.sh. Those .sh wrappers are
# MSYS shell scripts written for FFmpeg's configure; a NATIVE WINDOWS cmake cannot execute
# them. (BATCH-ADB-2 ADDENDUM 2 confirms: reuse ffmpeg-rt's KNOWLEDGE, not its wrappers.)
#
# -imsvc is IGNORED by clang-cl. Only -vctoolsdir / -winsdkdir / -winsdkversion pin the
# toolset; without them clang-cl silently selects 14.51, which hard-#errors on ARM32.

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR ARM)
set(CMAKE_SYSTEM_VERSION 6.3)

# PATHS COME FROM THE ENVIRONMENT, set by config.sh at the repo root.
# CMake cannot source a shell file, so it reads the same variables config.sh exports. The
# defaults below are the device-verified values, used only when nothing is exported -- which
# keeps this file usable standalone and keeps config.sh the single source of truth.
set(RT2 "D:/repo/llvm-rt/stage2/bin")
if(DEFINED ENV{RT2})
  set(RT2 "$ENV{RT2}")
endif()
set(_VCTOOLS "D:/Program Files/vs22buildtools/VC/Tools/MSVC/14.44.35207")
if(DEFINED ENV{VCTOOLS})
  set(_VCTOOLS "$ENV{VCTOOLS}")
endif()
set(_WINSDK "D:/Windows Kits/10")
if(DEFINED ENV{WINSDK})
  set(_WINSDK "$ENV{WINSDK}")
endif()
set(_SDKVER "10.0.19041.0")
if(DEFINED ENV{WINSDKVER})
  set(_SDKVER "$ENV{WINSDKVER}")
endif()

set(CMAKE_C_COMPILER   "${RT2}/clang-cl.exe")
set(CMAKE_CXX_COMPILER "${RT2}/clang-cl.exe")
set(CMAKE_ASM_COMPILER "${RT2}/clang.exe")
set(CMAKE_AR           "${RT2}/llvm-lib.exe")
set(CMAKE_LINKER       "${RT2}/lld-link.exe")
set(CMAKE_RC_COMPILER  "${RT2}/llvm-rc.exe")

# /FI the shim BEFORE any STL header. MSVC's <bit> (__msvc_bit_utils.hpp) calls
# _CountLeadingZeros / _CountLeadingZeros64 in its _M_ARM branch with no !__clang__ guard,
# and clang-cl does not declare them. Learned from the ARM32 OpenSSL build.
# The shim sits next to THIS file, whatever the repo is called or where it lives.
set(_SHIM "${CMAKE_CURRENT_LIST_DIR}/clang-cl-arm-shim.h")

set(_PIN "--target=thumbv7-unknown-windows-msvc -vctoolsdir \"${_VCTOOLS}\" -winsdkdir \"${_WINSDK}\" -winsdkversion ${_SDKVER}")

set(CMAKE_C_FLAGS_INIT   "${_PIN} /FI\"${_SHIM}\"")
set(CMAKE_CXX_FLAGS_INIT "${_PIN} /FI\"${_SHIM}\"")
# the clang GCC-driver assembler takes --target, not the clang-cl-only sysroot flags
set(CMAKE_ASM_FLAGS_INIT "--target=thumbv7-unknown-windows-msvc")

# CMake's compiler check would otherwise try to LINK a full ARM32 executable

# ★ STATIC CRT (/MT), not the CMake default /MD. Two reasons:
#   1. Our non-CMake objects (adb, libbase, the shims) are built by clang-cl with no /M flag,
#      which defaults to /MT. Mixing produced, at the first real link:
#        lld-link: error: /failifmismatch: mismatch detected for 'RuntimeLibrary':
#          libbase.lib(utf8.cpp.obj) has value MT_StaticRelease
#          ssl.lib(ssl_lib.cc.obj)   has value MD_DynamicRelease
#   2. /MD imports the UCRT DLLs. READING T18 requires the final adb.exe to have ZERO UCRT and
#      ZERO onecore imports -- that property is why it can run on RT 8.1 without KB2999226.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")

set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# CMake runs vs_link_exe -> mt.exe to embed a manifest whenever it links an EXE.
# rt2 does NOT ship llvm-mt.exe (the RECIPE-GAP: some LLVM_TOOLS were never built),
# so point CMAKE_MT at the SDK host tool. Static-library builds never hit this;
# the first EXE link does, with the opaque error "CMAKE_MT-NOTFOUND ... no such
# file or directory".
set(CMAKE_MT "${_WINSDK}/bin/${_SDKVER}/x64/mt.exe")
