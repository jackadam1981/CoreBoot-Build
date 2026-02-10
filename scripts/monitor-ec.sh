#!/usr/bin/env bash
# 定期打印温度 & 风扇转速

INTERVAL=5   # 每隔多少秒刷新一次

# 指定 Chrome EC ectool 的绝对路径
ECTOOL="$HOME/bin/ectool-cec"

if [ ! -x "$ECTOOL" ]; then
    echo "找不到 Chrome EC ectool: $ECTOOL"
    echo "请先下载并 chmod +x（参考 docs/linux-ectool-fan.md 第 1 节）"
    exit 1
fi

while true; do
    echo "===== $(date '+%F %T') ====="
    echo "温度："
    sudo "$ECTOOL" temps all || echo "ectool temps all 失败"

    echo
    echo "风扇转速："
    sudo "$ECTOOL" pwmgetfanrpm all || echo "ectool pwmgetfanrpm 失败"

    echo
    echo "风扇数量："
    sudo "$ECTOOL" pwmgetnumfans || echo "ectool pwmgetnumfans 失败"

    echo
    sleep "$INTERVAL"
done