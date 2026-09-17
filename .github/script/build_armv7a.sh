#!/bin/sh

# 任何一步失败立即中断并返回非 0，避免编译失败被静默忽略、最终打出不含 .so 的空包。
set -e

echo "==== init android openssl & ffmpeg source ===="
./init-android-openssl.sh
./init-android.sh

cd android
./compile-ijk.sh clean
cd ..

echo "==== build armv7a (openssl + ffmpeg + ijk) ===="
cd android/contrib
./compile-openssl.sh armv7a
./compile-ffmpeg.sh clean
./compile-ffmpeg.sh armv7a
cd ..
./compile-ijk.sh armv7a

echo "==== build arm64 (openssl + ffmpeg + ijk) ===="
cd contrib
./compile-openssl.sh arm64
./compile-ffmpeg.sh clean
./compile-ffmpeg.sh arm64
cd ..
./compile-ijk.sh arm64

# 回到仓库根目录
cd ..

# 校验 .so 产物确实生成，缺失则让流水线明确失败（而不是继续打空包）
echo "==== verify .so outputs ===="
ARMV7A_LIB="android/ijkplayer/ijkplayer-armv7a/src/main/libs/armeabi-v7a"
ARM64_LIB="android/ijkplayer/ijkplayer-arm64/src/main/libs/arm64-v8a"

fail=0
for dir in "$ARMV7A_LIB" "$ARM64_LIB"; do
    if [ -d "$dir" ] && ls "$dir"/*.so >/dev/null 2>&1; then
        echo "OK: $dir"
        ls -l "$dir"/*.so
    else
        echo "ERROR: no .so found in $dir"
        fail=1
    fi
done

if [ "$fail" -ne 0 ]; then
    echo "==== .so build verification FAILED ===="
    exit 1
fi

echo "==== .so build verification PASSED ===="
