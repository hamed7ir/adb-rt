# adb-rt: HOST (x64 Windows) toolchain for build-time tools such as protoc.
# Same rt2 clang-cl and same pinned MSVC/SDK as the ARM32 target, so host and target
# tools come from one toolchain. Only the --target differs.
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
set(CMAKE_AR           "${RT2}/llvm-lib.exe")
set(CMAKE_LINKER       "${RT2}/lld-link.exe")
set(CMAKE_RC_COMPILER  "${RT2}/llvm-rc.exe")

set(_PIN "--target=x86_64-pc-windows-msvc -vctoolsdir \"${_VCTOOLS}\" -winsdkdir \"${_WINSDK}\" -winsdkversion ${_SDKVER}")

set(CMAKE_C_FLAGS_INIT   "${_PIN}")
set(CMAKE_CXX_FLAGS_INIT "${_PIN}")

# CMake runs vs_link_exe -> mt.exe to embed a manifest whenever it links an EXE.
# rt2 does NOT ship llvm-mt.exe (the RECIPE-GAP: some LLVM_TOOLS were never built),
# so point CMAKE_MT at the SDK host tool. Static-library builds never hit this;
# the first EXE link does, with the opaque error "CMAKE_MT-NOTFOUND ... no such
# file or directory".
set(CMAKE_MT "${_WINSDK}/bin/${_SDKVER}/x64/mt.exe")

# ★ STATIC CRT (/MT), matching cross/arm32-clang-cl.cmake.
# Without this, CMake defaults to /MD and anything built here imports the CRT via
# __declspec(dllimport). Linking that against a /MT object fails with a wall of
# "undefined symbol: __declspec(dllimport) realloc/getenv/fputs/..." -- which is what the
# x64 usbprobe link did until this line existed. Same /MT-vs-/MD class that cost five
# rebuilt libraries in BATCH-ADB-2C; the ARM32 toolchain got the fix then, this one did not.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded")
