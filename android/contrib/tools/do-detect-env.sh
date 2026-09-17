#! /usr/bin/env bash
#
# Copyright (C) 2013-2014 Zhang Rui <bbcallen@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script is based on projects below
# https://github.com/yixia/FFmpeg-Android
# http://git.videolan.org/?p=vlc-ports/android.git;a=summary

#--------------------
set -e

UNAME_S=$(uname -s)
UNAME_SM=$(uname -sm)
echo "build on $UNAME_SM"

echo "ANDROID_NDK=$ANDROID_NDK"

if [ -z "$ANDROID_NDK" ]; then
    echo "You must define ANDROID_NDK before starting."
    echo "They must point to your NDK directories."
    echo ""
    exit 1
fi


#--------------------
# 确定 NDK 预构建 clang 工具链的 host tag。
# 注意: macOS 上即使用 Apple Silicon(M1/M2) 也仍然是 darwin-x86_64
# (NDK 提供的是包含 arm64 支持的胖二进制, 路径名沿用历史命名)。
case "$UNAME_S" in
    Darwin)
        IJK_HOST_TAG=darwin-x86_64
    ;;
    CYGWIN_NT-*|MSYS_NT-*|MINGW*)
        IJK_HOST_TAG=windows-x86_64
    ;;
    *)
        IJK_HOST_TAG=linux-x86_64
    ;;
esac
export IJK_HOST_TAG

if [ ! -d "$ANDROID_NDK/toolchains/llvm/prebuilt/$IJK_HOST_TAG" ]; then
    echo "ERROR: clang toolchain not found: $ANDROID_NDK/toolchains/llvm/prebuilt/$IJK_HOST_TAG"
    echo "A modern NDK (r23+) is required; the legacy standalone GCC toolchain is no longer used."
    exit 1
fi

export IJK_TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/$IJK_HOST_TAG"

# 供各编译脚本使用的公共工具(不含 target 前缀)
export IJK_AR="$IJK_TOOLCHAIN/bin/llvm-ar"
export IJK_RANLIB="$IJK_TOOLCHAIN/bin/llvm-ranlib"
export IJK_STRIP="$IJK_TOOLCHAIN/bin/llvm-strip"
export IJK_LD="$IJK_TOOLCHAIN/bin/ld"

# 尽可能保证 clang 在 PATH 中可用
export PATH="$IJK_TOOLCHAIN/bin:$PATH"


#--------------------
# NDK 版本打印(便于排障)
IJK_NDK_REL=$(grep -o '^Pkg\.Revision.*=[0-9]*.*' $ANDROID_NDK/source.properties 2>/dev/null | sed 's/[[:space:]]*//g' | cut -d "=" -f 2)
echo "IJK_NDK_REL=$IJK_NDK_REL"


case "$UNAME_S" in
    Darwin)
        export IJK_MAKE_FLAG=-j2 #`sysctl -n machdep.cpu.thread_count`
    ;;
    CYGWIN_NT-*)
        IJK_WIN_TEMP="$(cygpath -am /tmp)"
        export TEMPDIR=$IJK_WIN_TEMP/

        echo "Cygwin temp prefix=$IJK_WIN_TEMP/"
    ;;
esac
