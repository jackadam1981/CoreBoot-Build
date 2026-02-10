#!/usr/bin/env bash
#
# 通过 cbmem 时间戳判断本次启动是否可能复用了 MRC 缓存。
# 若「FspMemoryInit」或「after RAM initialization」阶段耗时明显较短（通常 < 数百 ms），
# 说明很可能使用了 Flash 中的 MRC 缓存；首次冷启或换内存后该阶段会较长（常 > 1s）。
# 需在刷入 coreboot 的 Linux 下运行，且需 root（或 sudo）读取 /dev/mem。
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CBMEM_DIR="${CBMEM_DIR:-$SCRIPT_DIR/../coreboot/util/cbmem}"
CBMEM_BIN="$CBMEM_DIR/cbmem"

# 查找或编译 cbmem
if [ ! -x "$CBMEM_BIN" ]; then
	if [ -f "$CBMEM_DIR/Makefile" ]; then
		echo ">>> 正在编译 cbmem ..."
		(cd "$CBMEM_DIR" && make -q 2>/dev/null) || (cd "$CBMEM_DIR" && make) || {
			echo "编译 cbmem 失败。可安装依赖: sudo apt install build-essential libpci-dev"
			exit 1
		}
	else
		echo "未找到 cbmem 源码: $CBMEM_DIR"
		exit 1
	fi
fi

if [ ! -d /sys/firmware/coreboot ]; then
	echo "警告: 未检测到 /sys/firmware/coreboot，当前可能并非 coreboot 固件，cbmem 可能无效。"
fi

# 使用可解析格式：ID \t absolute_us \t relative_us \t name
RAW="$("$(which sudo 2>/dev/null || echo true)" "$CBMEM_BIN" -T 2>/dev/null)" || {
	echo "无法运行 cbmem（需要 root 读取 /dev/mem）。尝试: sudo $0"
	exit 1
}

# 提取与内存初始化相关的时间戳（relative_us 为相对上一时间戳的耗时，单位微秒）
# 951 = TS_FSP_MEMORY_INIT_END (returning from FspMemoryInit) -> 其 relative 即 FspMemoryInit 耗时
# 965 = TS_FSP_MULTI_PHASE_MEM_INIT_END
# 3   = TS_INITRAM_END (after RAM initialization)
mem_init_us=""
while IFS=$'\t' read -r id abs rel name; do
	case "$id" in
		951) mem_init_us="$rel"; name_found="FspMemoryInit"; break ;;
		965) [ -z "$mem_init_us" ] && { mem_init_us="$rel"; name_found="FspMultiPhaseMemInit"; } ;;
		3)   [ -z "$mem_init_us" ] && { mem_init_us="$rel"; name_found="after RAM init"; } ;;
	esac
done <<< "$RAW"

echo "========== MRC / 内存初始化 时间戳 =========="
echo ""

if [ -z "$mem_init_us" ] || ! [ "$mem_init_us" -ge 0 ] 2>/dev/null; then
	echo "未在 cbmem 时间戳中找到内存初始化阶段（FspMemoryInit / after RAM init）。"
	echo "可能原因: 固件未启用 CONFIG_COLLECT_TIMESTAMPS，或非 Intel FSP 平台。"
	echo ""
	echo "完整时间戳表（前 40 行）:"
	echo "$RAW" | head -40
	exit 0
fi

# 转为毫秒便于阅读
mem_init_ms=$((mem_init_us / 1000))
if [ "$mem_init_us" -ge 1000000 ]; then
	sec=$((mem_init_us / 1000000))
	ms=$(((mem_init_us % 1000000) / 1000))
	time_str="${sec}.${ms}s"
else
	time_str="${mem_init_ms}ms"
fi

echo "本次启动检测到: ${name_found:-memory init}"
echo "  耗时: ${time_str} (${mem_init_us} µs)"
echo ""

# 经验值：复用时通常 < 500ms，完整训练常 > 1s（视平台与内存而定）
if [ "$mem_init_us" -lt 500000 ]; then
	echo "结论: 耗时较短，本次启动很可能 **已使用 MRC 缓存**（未做完整内存训练）。"
elif [ "$mem_init_us" -lt 1000000 ]; then
	echo "结论: 耗时中等，可能使用了 MRC 缓存或进行了较快训练。"
else
	echo "结论: 耗时较长，本次启动很可能 **进行了完整内存训练**（未用缓存或首次冷启/换内存后）。"
fi

echo ""
echo "提示: 首次冷启或更换内存后会有一次完整训练并写入缓存；之后正常关机再开，此处耗时应明显变短。"
echo ""

# 可选：输出 romstage 相关时间戳便于人工对照
echo "========== romstage / FSP 相关时间戳（供参考）=========="
echo "$RAW" | awk -F'\t' -v OFS='\t' '
	$1 ~ /^(1|2|3|4|100|101|950|951|952|953|954|955|956|957|958|959|960|961|962|963|964|965)$/ {
		rel_ms = $3/1000
		printf "%s\t%sms\t%s\n", $1, (rel_ms>=1000 ? rel_ms/1000 "s" : rel_ms "ms"), $4
	}
'
exit 0
