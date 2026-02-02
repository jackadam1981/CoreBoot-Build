#!/usr/bin/env bash
#
# 手动刷写 CoreBoot/MrChromebox 固件脚本
# 基于: https://docs.mrchromebox.tech/docs/firmware/manual-flashing.html
#
# 适用: Intel 设备 (kaisa/dooly 等 CML)，仅刷写 BIOS 区域
#
# 用法:
#   sudo ./flash.sh [rom文件]
#   不指定 rom 时自动使用 roms/ 下最新的 .rom
#
# 流程: 备份当前固件 -> 从备份提取 VPD/HWID 并注入到待刷 ROM -> 刷写 -> 可选验证
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROMS_DIR="${SCRIPT_DIR}/roms"
BACKUP_DIR="${SCRIPT_DIR}/backups"
UTIL_DIR="${SCRIPT_DIR}/util"
# MrChromebox 工具下载地址（备用，当系统无 flashrom/cbfstool/gbb_utility 时）
FLASHROM_URL="https://mrchromebox.tech/files/util/flashrom_ups_libpci37_20240418.tar.gz"
CBFSTOOL_URL="https://mrchromebox.tech/files/util/cbfstool.tar.gz"
GBB_UTILITY_URL="https://mrchromebox.tech/files/util/gbb_utility.tar.gz"

# Intel 设备刷写参数（仅 BIOS 区域）
FLASHROM_READ_OPTS="-p internal -r"
FLASHROM_WRITE_OPTS="-p internal --ifd -i bios -w"
FLASHROM_VERIFY_OPTS="-p internal --ifd -i bios -v"
FLASHROM_FAST="-N"  # 不验证未写入区域，加快速度

red()    { echo -e "\033[1;31m$*\033[0m"; }
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }

usage() {
    echo "用法: sudo $0 [rom文件]"
    echo "  不指定 rom 时使用 roms/ 下最新的 .rom 文件"
    echo ""
    echo "示例:"
    echo "  sudo $0"
    echo "  sudo $0 roms/coreboot_edk2-kaisa-mrchromebox_20250101.rom"
    exit 1
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        red "请使用 root 运行此脚本: sudo $0 [rom]"
        exit 1
    fi
}

check_linux() {
    if [ "$(uname -s)" != "Linux" ]; then
        red "此脚本仅支持在 Linux 下运行（本机或 Live USB）。"
        exit 1
    fi
}

find_tool() {
    local name="$1"
    local path
    # 优先用 PATH（sudo 下 PATH 可能被重置，再检查常见路径）
    path=$(command -v "$name" 2>/dev/null)
    [ -n "$path" ] && echo "$path" && return
    if [ -x "${UTIL_DIR}/${name}" ]; then
        echo "${UTIL_DIR}/${name}"
        return
    fi
    for dir in /usr/bin /usr/local/bin; do
        [ -x "${dir}/${name}" ] && echo "${dir}/${name}" && return
    done
    echo ""
}

download_tool() {
    local name="$1"
    local url="$2"
    local tarball="${UTIL_DIR}/.${name}.tar.gz"
    mkdir -p "$UTIL_DIR"
    yellow ">>> 自动下载 $name..."
    if command -v wget &>/dev/null; then
        wget -q -O "$tarball" "$url" || { red "下载失败: $url"; rm -f "$tarball"; return 1; }
    elif command -v curl &>/dev/null; then
        curl -sL -o "$tarball" "$url" || { red "下载失败: $url"; rm -f "$tarball"; return 1; }
    else
        red "需要 wget 或 curl 才能自动下载，请安装后重试"
        return 1
    fi
    (cd "$UTIL_DIR" && tar -xzf "$tarball" 2>/dev/null) || { red "解压失败"; rm -f "$tarball"; return 1; }
    rm -f "$tarball"
    # 支持解压到根目录或子目录
    local found
    found=$(find "$UTIL_DIR" -maxdepth 2 -name "$name" -type f 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        [ "$(dirname "$found")" != "$UTIL_DIR" ] && mv "$found" "${UTIL_DIR}/"
        chmod +x "${UTIL_DIR}/${name}"
        green "  $name 已下载到 util/"
        return 0
    fi
    red "解压后未找到可执行文件 $name"
    return 1
}

ensure_tools() {
    FLASHROM=$(find_tool flashrom)
    CBFSTOOL=$(find_tool cbfstool)
    GBB_UTILITY=$(find_tool gbb_utility)

    [ -z "$FLASHROM" ] && download_tool flashrom "$FLASHROM_URL" && FLASHROM="${UTIL_DIR}/flashrom"
    [ -z "$CBFSTOOL" ] && download_tool cbfstool "$CBFSTOOL_URL" && CBFSTOOL="${UTIL_DIR}/cbfstool"
    [ -z "$GBB_UTILITY" ] && download_tool gbb_utility "$GBB_UTILITY_URL" && GBB_UTILITY="${UTIL_DIR}/gbb_utility"

    if [ -z "$FLASHROM" ] || [ ! -x "$FLASHROM" ]; then
        red "无法获取 flashrom，请手动安装: apt install flashrom"
        exit 1
    fi
    if [ -z "$CBFSTOOL" ] || [ ! -x "$CBFSTOOL" ]; then
        red "无法获取 cbfstool，请从 https://mrchromebox.tech/files/util/ 手动下载到 util/"
        exit 1
    fi
    if [ -z "$GBB_UTILITY" ] || [ ! -x "$GBB_UTILITY" ]; then
        red "无法获取 gbb_utility，请从 https://mrchromebox.tech/files/util/ 手动下载到 util/"
        exit 1
    fi
    green "使用: flashrom=$FLASHROM cbfstool=$CBFSTOOL gbb_utility=$GBB_UTILITY"
}

resolve_rom() {
    local rom="$1"
    if [ -n "$rom" ]; then
        if [ ! -f "$rom" ]; then
            red "找不到 ROM 文件: $rom"
            exit 1
        fi
        echo "$(realpath "$rom")"
        return
    fi
    if [ ! -d "$ROMS_DIR" ]; then
        red "未找到 roms/ 目录，请先编译固件或指定 ROM 路径"
        exit 1
    fi
    local latest
    # 支持 roms/ 及 roms/YYYYMMDDHHMMSS/ 子目录
    latest=$(find "$ROMS_DIR" -name "*.rom" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    if [ -z "$latest" ]; then
        red "roms/ 及其子目录下没有 .rom 文件，请先编译或指定 ROM 路径"
        exit 1
    fi
    echo "$(realpath "$latest")"
}

# 刷写前必须校验 ROM 文件 SHA1，无 .sha1 或校验失败均中止，避免砖
verify_rom_sha1() {
    local rom="$1"
    local sha1_file="${rom}.sha1"
    if [ ! -f "$sha1_file" ]; then
        red "未找到 ${sha1_file}，为安全起见必须校验，已中止刷写。"
        red "请使用带 .sha1 的编译产物，或将该 ROM 的 sha1sum 写入同目录下的 ${sha1_file}"
        exit 1
    fi
    yellow ">>> 校验 ROM SHA1: $sha1_file"
    local dir rom_name
    dir=$(dirname "$rom")
    rom_name=$(basename "$rom")
    if (cd "$dir" && sha1sum -c --quiet "${rom_name}.sha1" 2>/dev/null); then
        green "SHA1 校验通过"
        return 0
    fi
    red "SHA1 校验失败！ROM 文件可能损坏，请勿刷写。"
    exit 1
}

backup_firmware() {
    local backup_path="$1"
    mkdir -p "$BACKUP_DIR"
    yellow ">>> 备份当前固件到: $backup_path"
    if ! $FLASHROM $FLASHROM_READ_OPTS "$backup_path" --ifd -i bios; then
        red "备份失败，已中止"
        exit 1
    fi
    if [ ! -s "$backup_path" ]; then
        red "备份文件为空，已中止"
        exit 1
    fi
    green "备份成功: $(ls -lh "$backup_path" | awk '{print $5}')"
}

prepare_rom() {
    local backup="$1"
    local rom_in="$2"
    local rom_out="$3"
    local vpd_file="${BACKUP_DIR}/vpd_$$.bin"
    local hwid_file="${BACKUP_DIR}/hwid_$$.txt"

    cp -f "$rom_in" "$rom_out"

    # 从备份中提取 VPD 并注入
    if $CBFSTOOL "$backup" read -r RO_VPD -f "$vpd_file" 2>/dev/null; then
        yellow ">>> 注入 VPD 到待刷 ROM"
        $CBFSTOOL "$rom_out" write -r RO_VPD -f "$vpd_file"
        green "VPD 已注入"
    else
        yellow "备份中无 RO_VPD，跳过"
    fi
    rm -f "$vpd_file"

    # 从备份中提取 HWID 并注入
    if $CBFSTOOL "$backup" extract -n hwid -f "$hwid_file" 2>/dev/null; then
        :
    elif $GBB_UTILITY "$backup" --get --hwid > "$hwid_file" 2>/dev/null; then
        :
    else
        yellow "无法从备份提取 HWID，跳过"
        rm -f "$hwid_file"
        return
    fi
    if [ -s "$hwid_file" ]; then
        yellow ">>> 注入 HWID 到待刷 ROM"
        $CBFSTOOL "$rom_out" remove -n hwid 2>/dev/null || true
        $CBFSTOOL "$rom_out" add -n hwid -f "$hwid_file" -t raw
        green "HWID 已注入"
    fi
    rm -f "$hwid_file"
}

do_flash() {
    local rom="$1"
    yellow ">>> 刷写固件: $rom"
    yellow "    命令: $FLASHROM $FLASHROM_WRITE_OPTS $rom $FLASHROM_FAST"
    echo ""
    read -p "确认刷写? 输入 yes 继续: " confirm
    if [ "$confirm" != "yes" ]; then
        red "已取消"
        exit 0
    fi
    if ! $FLASHROM $FLASHROM_WRITE_OPTS "$rom" $FLASHROM_FAST; then
        red "刷写失败！若有备份可尝试恢复。"
        exit 1
    fi
    green "刷写完成"
}

do_verify() {
    local rom="$1"
    yellow ">>> 验证闪存内容..."
    $FLASHROM $FLASHROM_VERIFY_OPTS "$rom" && green "验证通过" || { red "验证失败"; exit 1; }
}

main() {
    local rom_arg="$1"
    if [ "$rom_arg" = "-h" ] || [ "$rom_arg" = "--help" ]; then
        usage
    fi

    check_root
    check_linux

    ensure_tools

    ROM_IN=$(resolve_rom "$rom_arg")
    green "待刷 ROM: $ROM_IN"

    verify_rom_sha1 "$ROM_IN" || exit 1

    BACKUP_PATH="${BACKUP_DIR}/backup_$(date +%Y%m%d_%H%M%S).rom"
    ROM_PREPARED="${BACKUP_DIR}/rom_to_flash_$$.rom"

    echo ""
    red "*** 刷写固件有变砖风险，请确保已关闭写保护、有备份或恢复手段 ***"
    echo ""
    # 备份必须执行：用于提取 VPD/HWID 注入到待刷 ROM
    backup_firmware "$BACKUP_PATH"
    prepare_rom "$BACKUP_PATH" "$ROM_IN" "$ROM_PREPARED"
    ROM_TO_FLASH="$ROM_PREPARED"

    do_flash "$ROM_TO_FLASH"
    do_verify "$ROM_TO_FLASH"

    rm -f "$ROM_PREPARED"
    yellow "建议将备份妥善保存: $BACKUP_PATH"
    read -p "是否现在重启? [y/N]: " do_reboot
    if [ "$do_reboot" = "y" ] || [ "$do_reboot" = "Y" ]; then
        reboot
    fi
    green "完成。请手动重启使新固件生效。"
}

main "$@"
