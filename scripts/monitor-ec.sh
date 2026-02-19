#!/usr/bin/env bash
# 定期打印：温度、PWM 占空比（若支持）、风扇转速 RPM、CPU 频率、CPU 负载

INTERVAL=5   # 每隔多少秒刷新一次

# 指定 Chrome EC ectool 的绝对路径
ECTOOL="${ECTOOL:-$HOME/bin/ectool-cec}"

if [ ! -x "$ECTOOL" ]; then
    echo "找不到 Chrome EC ectool: $ECTOOL"
    echo "请先下载并 chmod +x（参考 docs/linux-ectool-fan.md 第 1 节）"
    exit 1
fi

# 读取 CPU 当前频率（kHz -> MHz），兼容 scaling_cur_freq / cpuinfo_cur_freq
get_cpu_freq() {
    local i=0
    local freq
    local any=0
    while [ -d "/sys/devices/system/cpu/cpu$i" ]; do
        freq=""
        [ -r "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" ] && freq=$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/scaling_cur_freq" 2>/dev/null)
        [ -z "$freq" ] && [ -r "/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_cur_freq" ] && freq=$(cat "/sys/devices/system/cpu/cpu$i/cpufreq/cpuinfo_cur_freq" 2>/dev/null)
        if [ -n "$freq" ]; then
            echo "  CPU$i: $((freq / 1000)) MHz"
            any=1
        fi
        i=$((i + 1))
    done
    [ "$i" -gt 0 ] && [ "$any" -eq 0 ] && echo "  (无 cpufreq 或需 root)"
}

# 读取 CPU 负载（1/5/15 分钟平均）
get_cpu_load() {
    if [ -r /proc/loadavg ]; then
        read -r load1 load5 load15 _ _ </proc/loadavg
        echo "  load average: $load1 $load5 $load15 (1/5/15 min)"
    else
        echo "  (无法读取 /proc/loadavg)"
    fi
}

# 尝试读取风扇 PWM 占空比（仅当 ectool 支持时显示）
# 若输出为 raw 0-65535，则换算为百分比显示
get_fan_duty() {
    local out raw pct
    out=$(sudo "$ECTOOL" pwmgetfanduty all 2>&1) && { echo "$out" | sed 's/^/  /'; return 0; }
    out=$(sudo "$ECTOOL" pwmgetduty all 2>&1) && {
        while read -r line; do
            raw=$(echo "$line" | sed -n 's/.*[Dd]uty[^0-9]*\([0-9][0-9]*\).*/\1/p')
            if [ -n "$raw" ] && [ "$raw" -ge 0 ] 2>/dev/null && [ "$raw" -le 65535 ] 2>/dev/null; then
                pct=$(awk "BEGIN { printf \"%.1f\", $raw * 100 / 65535 }")
                echo "  PWM 占空比: ${pct}% (raw $raw)"
            else
                echo "$line" | sed 's/^/  /'
            fi
        done <<< "$out"
        return 0
    }
    out=$(sudo "$ECTOOL" pwmgetduty 0 2>&1) && {
        raw=$(echo "$out" | sed -n 's/.*[Dd]uty[^0-9]*\([0-9][0-9]*\).*/\1/p')
        if [ -n "$raw" ] && [ "$raw" -ge 0 ] 2>/dev/null && [ "$raw" -le 65535 ] 2>/dev/null; then
            pct=$(awk "BEGIN { printf \"%.1f\", $raw * 100 / 65535 }")
            echo "  PWM 占空比: ${pct}% (raw $raw)"
        else
            echo "$out" | sed 's/^/  /'
        fi
        return 0
    }
    echo "  (ectool 无 pwmgetfanduty/pwmgetduty 命令)"
}

while true; do
    echo "===== $(date '+%F %T') ====="

    echo "温度（ratio = 当前温度在 fan_off~fan_max 间的线性比例，仅供参考；实际 PWM 由 EC 曲线/滞后决定，可与 ratio 不一致）："
    sudo "$ECTOOL" temps all 2>/dev/null || echo "  ectool temps 失败"

    echo
    echo "PWM 占空比（当前风扇 duty）："
    get_fan_duty
    echo
    echo "风扇转速："
    sudo "$ECTOOL" pwmgetfanrpm all 2>/dev/null || echo "  ectool pwmgetfanrpm 失败"
    sudo "$ECTOOL" pwmgetnumfans 2>/dev/null || true

    echo
    echo "CPU 频率："
    get_cpu_freq

    echo
    echo "CPU 负载："
    get_cpu_load

    echo
    sleep "$INTERVAL"
done