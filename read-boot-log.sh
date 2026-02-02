#!/usr/bin/env bash
#
# 读取启动日志中的 PXE/网络相关信息
# 需在刷入 coreboot 后的 Linux 系统下运行
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBMEM_DIR="$SCRIPT_DIR/coreboot/util/cbmem"
CBMEM_BIN="$CBMEM_DIR/cbmem"

# 如果 cbmem 未编译，尝试编译
if [ ! -x "$CBMEM_BIN" ]; then
    echo ">>> cbmem 未编译，正在编译..."
    if [ -f "$CBMEM_DIR/Makefile" ]; then
        (cd "$CBMEM_DIR" && make) || {
            echo "编译 cbmem 失败，请手动执行: cd $CBMEM_DIR && make"
            echo "可能需要安装: sudo apt install build-essential libpci-dev"
            exit 1
        }
        echo ">>> cbmem 编译完成"
    else
        echo "未找到 cbmem 源码，请确保 coreboot 子模块已初始化"
        exit 1
    fi
fi

# 检查是否在 coreboot 固件上运行
if [ ! -d /sys/firmware/coreboot ]; then
    echo "警告: 未检测到 /sys/firmware/coreboot，可能未运行 coreboot 固件"
    echo "cbmem 仅在刷入 coreboot 固件后的系统上有效"
    echo ""
fi

echo "========== coreboot/cbmem 启动日志 (PXE/Network/EDK2 相关) =========="
sudo "$CBMEM_BIN" -c 2>/dev/null | grep -iE 'pxe|network|undi|rtl8168|r8168|realtek|snp|edk2|ip4|dhcp|boot' || echo "(未找到相关日志或 cbmem 不可用)"

echo ""
echo "========== dmesg 网卡相关 =========="
dmesg | grep -iE 'r8168|realtek|eth|enp|undi' 2>/dev/null || true

echo ""
echo "========== 完整 cbmem 日志（最后 150 行）=========="
sudo "$CBMEM_BIN" -c 2>/dev/null | tail -150 || echo "cbmem 读取失败，请确保：1) 正在运行 coreboot 固件 2) 以 root 权限执行"
