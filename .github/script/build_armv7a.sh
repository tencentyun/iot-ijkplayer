#!/bin/sh

./init-android-openssl.sh
./init-android.sh

cd android/contrib
./compile-openssl.sh arm64
./compile-ffmpeg.sh clean
./compile-ffmpeg.sh arm64
cd ..
./compile-ijk.sh arm64

cd contrib
./compile-openssl.sh armv7a
./compile-ffmpeg.sh clean
./compile-ffmpeg.sh armv7a
cd ..
./compile-ijk.sh armv7a
