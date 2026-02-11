#!/usr/bin/env bash
#
# 在本机用 arm-none-eabi 工具链编译 Chrome EC（不依赖 Docker，占用空间小）
# 适用于：根分区空间不足、无法拉取 coreboot-sdk 镜像时。
#
# 依赖: make, gcc-arm-none-eabi
#   Fedora/RHEL: sudo dnf install make arm-none-eabi-gcc
#   Debian/Ubuntu: sudo apt-get install make gcc-arm-none-eabi
#
# 用法: ./build-ec-native.sh [ec_dir]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EC_DIR="${1:-$SCRIPT_DIR/../ec}"

if [ ! -d "$EC_DIR" ]; then
    echo "错误: EC 目录不存在: $EC_DIR"
    exit 1
fi

EC_DIR="$(cd "$EC_DIR" && pwd)"

if ! command -v arm-none-eabi-gcc &>/dev/null; then
    echo "未找到 arm-none-eabi-gcc。请安装："
    echo "  Fedora: sudo dnf install arm-none-eabi-gcc"
    echo "  Debian/Ubuntu: sudo apt-get install gcc-arm-none-eabi"
    exit 1
fi

echo "=========================================="
echo "Chrome EC 编译 (本机 arm-none-eabi)"
echo "  EC 目录: $EC_DIR"
echo "  Board:   puff (Kaisa)"
echo "=========================================="

cd "$EC_DIR"
make -j BOARD=puff CROSS_COMPILE_arm=arm-none-eabi-

echo ""
echo ">>> 编译完成"
echo "    固件: $EC_DIR/build/puff/ec.bin"
ls -la "$EC_DIR/build/puff/ec.bin" 2>/dev/null || true
