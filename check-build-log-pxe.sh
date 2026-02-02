#!/usr/bin/env bash
#
# 从 build.log 判断 EDK2 PXE / iPXE 相关是否编译成功
#
# 用法: ./check-build-log-pxe.sh [build.log]
#   不指定时使用 roms/ 下最新目录中的 build.log
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROMS_DIR="${SCRIPT_DIR}/roms"

red()    { echo -e "\033[1;31m$*\033[0m"; }
green()  { echo -e "\033[1;32m$*\033[0m"; }
yellow() { echo -e "\033[1;33m$*\033[0m"; }

resolve_log() {
    local log="$1"
    if [ -n "$log" ]; then
        [ -f "$log" ] || { red "文件不存在: $log"; exit 1; }
        echo "$log"
        return
    fi
    local latest
    latest=$(find "$ROMS_DIR" -maxdepth 2 -name "build.log" -type f 2>/dev/null | sort -r | head -1)
    [ -z "$latest" ] && { red "未找到 build.log，请指定: $0 <path/to/build.log>"; exit 1; }
    echo "$latest"
}

main() {
    local log_path
    log_path=$(resolve_log "${1:-}")
    echo "build.log: $log_path"
    echo ""

    # 0) 判断模式：标准 PXE（SNP）、iPXE、或混合（两者都启用）
    ipxe_enabled=0
    standard_pxe_enabled=0
    if grep -q "Option:.*NETWORK_IPXE=TRUE" "$log_path" 2>/dev/null; then
        ipxe_enabled=1
    fi
    if grep -q "NETWORK_PXE_BOOT_ENABLE=TRUE" "$log_path" 2>/dev/null; then
        standard_pxe_enabled=1
    fi

    if [ "$ipxe_enabled" -eq 1 ] && [ "$standard_pxe_enabled" -eq 1 ]; then
        green "[EDK2 模式] 混合模式：标准 PXE（SNP）+ iPXE 均已启用"
    elif [ "$ipxe_enabled" -eq 1 ]; then
        green "[EDK2 模式] 仅 iPXE 已启用 (Option: NETWORK_IPXE=TRUE)"
    else
        green "[EDK2 模式] 仅标准 PXE（SNP/NetworkPkg），未启用 iPXE"
    fi

    # 1) EDK2 选项：PXE/网络
    if [ "$standard_pxe_enabled" -eq 1 ]; then
        green "[EDK2 选项] NETWORK_PXE_BOOT_ENABLE=TRUE"
    else
        [ "$ipxe_enabled" -eq 1 ] && yellow "[EDK2 选项] 未发现 NETWORK_PXE_BOOT_ENABLE=TRUE（仅 iPXE 时可能无）"
        [ "$ipxe_enabled" -eq 0 ] && red "[EDK2 选项] 未发现 NETWORK_PXE_BOOT_ENABLE=TRUE"
    fi

    if grep -q "NETWORK_SNP_ENABLE=TRUE" "$log_path" 2>/dev/null; then
        green "[EDK2 选项] NETWORK_SNP_ENABLE=TRUE"
    else
        [ "$ipxe_enabled" -eq 1 ] && [ "$standard_pxe_enabled" -eq 0 ] && yellow "[EDK2 选项] 未发现 NETWORK_SNP_ENABLE=TRUE（仅 iPXE 时可无 SNP）"
        [ "$standard_pxe_enabled" -eq 1 ] && red "[EDK2 选项] 未发现 NETWORK_SNP_ENABLE=TRUE"
    fi

    # 1b) iPXE：是否包含外部 iPXE 镜像（iPXE 或混合模式时必检）
    ipxe_ok=0
    if [ "$ipxe_enabled" -eq 1 ]; then
        if grep -q "Including externally built iPXE\|ipxe\.efi\|ipxe\.rom" "$log_path" 2>/dev/null; then
            green "[EDK2 iPXE] 已包含外部 iPXE（Including externally built iPXE / ipxe.efi）"
            ipxe_ok=1
        else
            red "[EDK2 iPXE] 已启用 NETWORK_IPXE=TRUE 但未发现包含 iPXE 镜像的日志行"
        fi
    else
        ipxe_ok=1
    fi

    # 2) SNP 驱动已编译（标准 PXE 或混合模式依赖）
    snp_ok=0
    if grep -q "Building.*NetworkPkg/SnpDxe/SnpDxe\.inf" "$log_path" 2>/dev/null; then
        green "[EDK2 编译] SnpDxe (网络协议) 已参与构建"
        snp_ok=1
    else
        [ "$standard_pxe_enabled" -eq 1 ] && red "[EDK2 编译] 未发现 SnpDxe 构建行"
        [ "$standard_pxe_enabled" -eq 0 ] && yellow "[EDK2 编译] 未发现 SnpDxe（仅 iPXE 时可无）"
    fi

    # 3) EDK2 构建成功
    if grep -q "^- Done -" "$log_path" 2>/dev/null && grep -q "^Success!" "$log_path" 2>/dev/null; then
        green "[EDK2] 构建完成: - Done - / Success!"
    else
        red "[EDK2] 未发现构建成功标记 (- Done - / Success!)"
    fi

    # 4) coreboot 整体构建成功
    if grep -q "Built google/puff" "$log_path" 2>/dev/null; then
        green "[coreboot] Built google/puff (Kaisa)"
    else
        yellow "[coreboot] 未发现 'Built google/puff'（若板型非 Kaisa 可忽略）"
    fi

    # 5) RtkUndi / RTL8168 标准 PXE 驱动（标准 PXE 或混合模式时检查；仅 iPXE 时不要求）
    pxe_driver_ok=0
    if [ "$standard_pxe_enabled" -eq 0 ]; then
        yellow "[RTL8168 PXE] 仅 iPXE 模式，不检查 RtkUndiDxe"
        pxe_driver_ok=1
    elif grep -q "Add RtkUndiDxe\.efi for RTL8168 PXE" "$log_path" 2>/dev/null; then
        green "[RTL8168 PXE] RtkUndiDxe 已直接包含（edk2 直接包含版本）"
        pxe_driver_ok=1
    elif grep -q "Make RtkUndiDxe inclusion conditional on RTKUNDI_ENABLE" "$log_path" 2>/dev/null; then
        if grep -q "Option:.*RTKUNDI_ENABLE=TRUE\|Building.*RtkUndiDxe\.inf" "$log_path" 2>/dev/null; then
            green "[RTL8168 PXE] RtkUndiDxe 已启用/已参与构建（条件包含且已传 RTKUNDI_ENABLE）"
            pxe_driver_ok=1
        else
            red "[RTL8168 PXE] edk2 为条件包含 RtkUndiDxe，但未启用 RTKUNDI_ENABLE，RTL8168 PXE 驱动未包含"
        fi
    else
        yellow "[RTL8168 PXE] 日志中无 RtkUndi/条件包含相关记录（若非 RTL8168 或预编译 .efi 可忽略）"
        pxe_driver_ok=1
    fi

    echo ""
    # 结论：按模式汇总，混合模式时 PXE 与 iPXE 均需通过
    success_marker=0
    grep -q "^Success!" "$log_path" 2>/dev/null && success_marker=1

    if [ "$ipxe_enabled" -eq 1 ] && [ "$standard_pxe_enabled" -eq 1 ]; then
        # 混合模式：iPXE 包含 + 标准 PXE（SnpDxe + RtkUndi 如适用） + Success
        if [ "$success_marker" -eq 1 ] && [ "$ipxe_ok" -eq 1 ] && [ "$snp_ok" -eq 1 ] && [ "$pxe_driver_ok" -eq 1 ]; then
            green "结论: 混合模式（标准 PXE + iPXE）均已参与构建且 EDK2 构建成功；iPXE 已包含，RTL8168 PXE 驱动已包含或无需检查。"
        else
            [ "$ipxe_ok" -ne 1 ] && red "结论: 混合模式中 iPXE 未包含或未发现日志。"
            [ "$snp_ok" -ne 1 ] && red "结论: 混合模式中标准 PXE（SnpDxe）未参与构建。"
            [ "$pxe_driver_ok" -ne 1 ] && red "结论: 混合模式中 RTL8168 PXE 驱动未包含。"
            [ "$success_marker" -ne 1 ] && red "结论: EDK2 未构建成功。"
            exit 1
        fi
    elif [ "$ipxe_enabled" -eq 1 ]; then
        if [ "$success_marker" -eq 1 ] && [ "$ipxe_ok" -eq 1 ]; then
            green "结论: iPXE 已启用且已包含，EDK2 构建成功。"
        else
            red "结论: iPXE 已启用但未发现包含 iPXE 镜像或 EDK2 未构建成功，请检查配置与错误信息。"
            exit 1
        fi
    else
        if [ "$success_marker" -eq 1 ] && [ "$standard_pxe_enabled" -eq 1 ] && [ "$snp_ok" -eq 1 ] && [ "$pxe_driver_ok" -eq 1 ]; then
            green "结论: 标准 PXE 已参与构建且 EDK2 构建成功；RTL8168 PXE 驱动已包含或无需检查。"
        elif [ "$pxe_driver_ok" -ne 1 ]; then
            red "结论: PXE 协议栈已构建，但 RTL8168 PXE 驱动未包含（edk2 条件包含且未传 RTKUNDI_ENABLE），无法从该网卡 PXE 启动。"
            exit 1
        else
            red "结论: 日志中缺少标准 PXE 启用或构建成功的关键行，请检查配置与错误信息。"
            exit 1
        fi
    fi
}

main "$@"
