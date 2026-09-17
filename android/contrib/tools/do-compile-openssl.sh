#! /usr/bin/env bash
#
# Copyright (C) 2014 Miguel Botón <waninkoko@gmail.com>
# Copyright (C) 2014 Zhang Rui <bbcallen@gmail.com>
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

#--------------------
set -e

if [ -z "$ANDROID_NDK" ]; then
    echo "You must define ANDROID_NDK before starting."
    echo "They must point to your NDK directories.\n"
    exit 1
fi

#--------------------
# common defines
FF_ARCH=$1
if [ -z "$FF_ARCH" ]; then
    echo "You must specific an architecture 'arm, armv7a, x86, ...'.\n"
    exit 1
fi


FF_BUILD_ROOT=`pwd`
# NDK r23+ 最低支持 API 21, 不能再使用 android-9
FF_ANDROID_PLATFORM=android-21


FF_BUILD_NAME=
FF_SOURCE=
FF_CROSS_PREFIX=

# clang 交叉编译目标三元组(不含 API 后缀)
FF_CLANG_TARGET=

FF_CFG_FLAGS=
FF_PLATFORM_CFG_FLAGS=

FF_EXTRA_CFLAGS=
FF_EXTRA_LDFLAGS=



#--------------------
echo ""
echo "--------------------"
echo "[*] detect NDK clang toolchain"
echo "--------------------"
. ./tools/do-detect-env.sh
FF_MAKE_FLAGS=$IJK_MAKE_FLAG


#----- arch begin -----
if [ "$FF_ARCH" = "armv7a" ]; then
    FF_BUILD_NAME=openssl-armv7a
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CLANG_TARGET=armv7a-linux-androideabi

    FF_PLATFORM_CFG_FLAGS="android-armv7"

elif [ "$FF_ARCH" = "armv5" ]; then
    FF_BUILD_NAME=openssl-armv5
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CLANG_TARGET=armv7a-linux-androideabi

    FF_PLATFORM_CFG_FLAGS="android"

elif [ "$FF_ARCH" = "x86" ]; then
    FF_BUILD_NAME=openssl-x86
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CLANG_TARGET=i686-linux-android

    FF_PLATFORM_CFG_FLAGS="android-x86"

    FF_CFG_FLAGS="$FF_CFG_FLAGS no-asm"

elif [ "$FF_ARCH" = "x86_64" ]; then
    FF_ANDROID_PLATFORM=android-21

    FF_BUILD_NAME=openssl-x86_64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CLANG_TARGET=x86_64-linux-android

    FF_PLATFORM_CFG_FLAGS="linux-x86_64"

elif [ "$FF_ARCH" = "arm64" ]; then
    FF_ANDROID_PLATFORM=android-21

    FF_BUILD_NAME=openssl-arm64
    FF_SOURCE=$FF_BUILD_ROOT/$FF_BUILD_NAME

    FF_CLANG_TARGET=aarch64-linux-android

    FF_PLATFORM_CFG_FLAGS="linux-aarch64"

else
    echo "unknown architecture $FF_ARCH";
    exit 1
fi

FF_PREFIX=$FF_BUILD_ROOT/build/$FF_BUILD_NAME/output

mkdir -p $FF_PREFIX


#--------------------
echo ""
echo "--------------------"
echo "[*] check openssl env"
echo "--------------------"
# clang 交叉编译: 通过 CC/AR/RANLIB 指定工具, 不使用 standalone gcc toolchain。
# API level 从 FF_ANDROID_PLATFORM(android-NN) 中提取。
# 使用 NDK 带 target 前缀的 clang wrapper, 避免把 --target 塞进 CC 导致
# 部分构建系统(如 ffmpeg configure)把额外参数误判为自身选项。
FF_API_LEVEL=${FF_ANDROID_PLATFORM#android-}

export CC="$IJK_TOOLCHAIN/bin/${FF_CLANG_TARGET}${FF_API_LEVEL}-clang"
export AR="$IJK_AR"
export RANLIB="$IJK_RANLIB"

if [ ! -x "$CC" ]; then
    echo "ERROR: clang wrapper not found or not executable: $CC"
    exit 1
fi

echo "CC=$CC"
echo "AR=$AR"

export COMMON_FF_CFG_FLAGS=

FF_CFG_FLAGS="$FF_CFG_FLAGS $COMMON_FF_CFG_FLAGS"

#--------------------
# Standard options:
# openssl 1.0.2 在 NDK clang 下不使用 --cross-compile-prefix(会去找 gcc),
# 改用上方 CC/AR/RANLIB 环境变量。
# no-asm: openssl 1.0.2 的 arm 汇编在 clang/新版 binutils 下易失败, 关闭以保证可编译。
# -fPIC : libssl.a/libcrypto.a 会被合并进 libijkffmpeg.so(动态库), 必须使用
#         位置无关代码, 否则链接报 relocation R_ARM_REL32 ... recompile with -fPIC。
FF_CFG_FLAGS="$FF_CFG_FLAGS zlib-dynamic"
FF_CFG_FLAGS="$FF_CFG_FLAGS no-shared"
FF_CFG_FLAGS="$FF_CFG_FLAGS no-asm"
FF_CFG_FLAGS="$FF_CFG_FLAGS no-async"
FF_CFG_FLAGS="$FF_CFG_FLAGS -fPIC"
FF_CFG_FLAGS="$FF_CFG_FLAGS --openssldir=$FF_PREFIX"
FF_CFG_FLAGS="$FF_CFG_FLAGS $FF_PLATFORM_CFG_FLAGS"

#--------------------
echo ""
echo "--------------------"
echo "[*] configurate openssl"
echo "--------------------"
cd $FF_SOURCE
    echo "./Configure $FF_CFG_FLAGS"
    ./Configure $FF_CFG_FLAGS

# openssl 1.0.2 对 Android 平台会在生成的 Makefile 中硬编码老 gcc 专有 flag
# -mandroid, clang 不识别会报 "unknown argument: '-mandroid'"。此处统一移除。
echo "[*] strip gcc-only '-mandroid' flag from generated Makefile"
sed -i.bak 's/ -mandroid//g' Makefile
rm -f Makefile.bak
grep -n -- "-mandroid" Makefile && echo "WARNING: -mandroid still present" || echo "-mandroid removed"

# 强制确保 CFLAG 含 -fPIC(静态库需被链接进 libijkffmpeg.so 动态库)
echo "[*] ensure -fPIC in generated Makefile"
if grep -q '^CFLAG=' Makefile; then
    sed -i.bak '/^CFLAG=/ s/^CFLAG=/CFLAG=-fPIC /' Makefile
    rm -f Makefile.bak
fi
grep -n '^CFLAG=' Makefile | head -1

#--------------------
echo ""
echo "--------------------"
echo "[*] compile openssl"
echo "--------------------"
make depend
# 只编译静态库(libcrypto.a/libssl.a), 跳过 build_apps(openssl 命令行工具)。
# OpenSSL 1.0.2 在 NDK 交叉编译环境下链接 apps 会因 libobjects.a 未正确并入
# 而报大量 "undefined reference to 'OBJ_xxx'", 而 ijkplayer 只需要这两个静态库。
make $FF_MAKE_FLAGS build_libs

#--------------------
echo ""
echo "--------------------"
echo "[*] install openssl (libs + headers only)"
echo "--------------------"
# 手动安装 libcrypto.a / libssl.a 与头文件到 output/，不用 install_sw，
# 避免其因 apps 未编译而执行 cp $(PROGRAMS) 失败。
# ijkplayer/ffmpeg 只依赖 output/include + output/lib。
mkdir -p $FF_PREFIX/lib $FF_PREFIX/include/openssl
cp -f libcrypto.a libssl.a $FF_PREFIX/lib/
cp -f include/openssl/*.h $FF_PREFIX/include/openssl/
echo "---- installed openssl libs ----"
ls -l $FF_PREFIX/lib
echo "---- installed openssl headers (count) ----"
ls -1 $FF_PREFIX/include/openssl/*.h | wc -l

#--------------------
echo ""
echo "--------------------"
echo "[*] link openssl"
echo "--------------------"
