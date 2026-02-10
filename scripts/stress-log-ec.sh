#!/usr/bin/env bash
# 简单压测 + 记录温度/风扇转速到日志

# Chrome EC ectool 路径（与 monitor-ec.sh 保持一致）
ECTOOL="$HOME/bin/ectool-cec"

# 日志文件
LOG_DIR="$HOME/ectool-logs"
LOG_FILE="$LOG_DIR/$(date '+%Y%m%d-%H%M%S')-ec-stress.log"

# 采样间隔（秒）
INTERVAL=5

mkdir -p "$LOG_DIR"

# 检查 ectool 是否可执行
if [ ! -x "$ECTOOL" ]; then
    echo "找不到 Chrome EC ectool: $ECTOOL"
    echo "请确认已下载并 chmod +x（参考 docs/linux-ectool-fan.md 第 1 节）"
    exit 1
fi

echo "日志文件: $LOG_FILE"
echo "按 Ctrl+C 结束压测与记录。"
echo

# 可选：启动一个简单 CPU 压测（例如 stress-ng，没装就注释掉）
if command -v stress-ng >/dev/null 2>&1; then
    echo "启动 stress-ng 压测（8 线程）..."
    stress-ng --cpu 8 --timeout 0 &   # 不设 timeout，靠 Ctrl+C 结束
    STRESS_PID=$!
    echo "stress-ng PID: $STRESS_PID"
else
    echo "未找到 stress-ng，只记录温度/转速，不做额外压测。"
fi

# 头部
{
    echo "===== EC 温度 / 风扇监控日志 ====="
    echo "时间: $(date '+%F %T')"
    echo "ectool: $ECTOOL"
    echo "间隔: ${INTERVAL}s"
    echo
} >> "$LOG_FILE"

trap 'echo; echo "停止记录。"; [ -n "$STRESS_PID" ] && kill "$STRESS_PID" 2>/dev/null; exit 0' INT

while true; do
    TS="$(date '+%F %T')"

    TEMP_OUT="$(sudo "$ECTOOL" temps all 2>&1)"
    FAN_OUT="$(sudo "$ECTOOL" pwmgetfanrpm all 2>&1)"
    NUM_OUT="$(sudo "$ECTOOL" pwmgetnumfans 2>&1)"

    # 终端简要输出
    echo "[$TS]"
    echo "$TEMP_OUT"
    echo "$FAN_OUT"
    echo "$NUM_OUT"
    echo

    # 写入日志（带时间戳）
    {
        echo "===== $TS ====="
        echo "[temps all]"
        echo "$TEMP_OUT"
        echo
        echo "[pwmgetfanrpm all]"
        echo "$FAN_OUT"
        echo
        echo "[pwmgetnumfans]"
        echo "$NUM_OUT"
        echo
    } >> "$LOG_FILE"

    sleep "$INTERVAL"
done