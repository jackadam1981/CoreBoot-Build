#!/usr/bin/env bash
#
# 将编译好的 EC RW 固件 (ec.RW.flat) 复制到 coreboot 的 blobs 目录，
# 这样后续编译 coreboot 时会把新 EC 打进 ROM。
# 改过 EC 风扇配置后必须先编 EC，再执行本脚本，再编 coreboot。
#
# 用法: ./replace-ec-blob.sh [ec_dir]
#   ec_dir: EC 源码目录，默认与 CoreBoot-Build 同级的 ec
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EC_DIR="${1:-$SCRIPT_DIR/../ec}"
COREBOOT_BLOBS="$SCRIPT_DIR/coreboot/3rdparty/blobs/mainboard/google/puff/puff"
EC_RW_FLAT="$EC_DIR/build/puff/RW/ec.RW.flat"

if [ ! -f "$EC_RW_FLAT" ]; then
    echo "错误: 未找到 EC RW 固件: $EC_RW_FLAT"
    echo "请先编译 EC: ./build-ec.sh $EC_DIR  或  ./build-ec-native.sh $EC_DIR"
    exit 1
fi

mkdir -p "$COREBOOT_BLOBS"
cp -v "$EC_RW_FLAT" "$COREBOOT_BLOBS/ec.RW.flat"
echo "已替换: $COREBOOT_BLOBS/ec.RW.flat"
echo "接下来执行 ./docker-build.sh kaisa 编出的 ROM 将包含此 EC。"
