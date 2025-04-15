#!/bin/sh

./init-android-openssl.sh
./init-android.sh

cd android/contrib
./compile-openssl.sh armv7a
./compile-openssl.sh arm64
./compile-ffmpeg.sh clean
./compile-ffmpeg.sh armv7a
./compile-ffmpeg.sh arm64
cd ..
./compile-ijk.sh armv7a
./compile-ijk.sh arm64
