#!/usr/bin/env bash
#
# 本地使用 coreboot-sdk Docker 镜像编译固件
# 用法: ./build.sh [board_name] [--debug]
#   board_name: 目标板型号，默认 kaisa
#   --debug:    启用调试模式
#
# 示例:
#   ./build.sh              # 编译 kaisa (默认)
#   ./build.sh kaisa        # 同上
#   ./build.sh kaisa --debug
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BOARD_NAME="${BOARD_NAME:-kaisa}"
DEBUG_FLAG=""

for arg in "$@"; do
    if [ "$arg" = "--debug" ]; then
        DEBUG_FLAG="--debug"
    elif [ -n "$arg" ] && [ "$arg" != "--debug" ]; then
        BOARD_NAME="$arg"
    fi
done

# coreboot 可由容器内 git submodule update --init 自动拉取，无需事先存在
if ! docker image inspect coreboot/coreboot-sdk &>/dev/null; then
    echo "正在拉取 coreboot-sdk 镜像..."
    docker pull coreboot/coreboot-sdk
fi

echo "=========================================="
echo "Board: $BOARD_NAME ${DEBUG_FLAG:+($DEBUG_FLAG)}"
echo "镜像:  coreboot/coreboot-sdk"
echo "=========================================="

mkdir -p roms

# 临时日志文件，编译完成后移动到结果目录
BUILD_LOG="roms/.build.log"

# 使用 root 运行，否则挂载的 .git 目录无法被容器内用户写入（Permission denied）
docker run --rm --user root \
    -v "$SCRIPT_DIR:/workspace" \
    -w /workspace \
    coreboot/coreboot-sdk \
    bash -c "
        set -e
        git config --global --add safe.directory /workspace
        git config --global --add safe.directory /workspace/coreboot
        git config --global --add safe.directory /workspace/coreboot/payloads/external/iPXE/ipxe
        git config --global --add safe.directory '*'
        git config --global http.postBuffer 524288000
        git config --global http.lowSpeedLimit 0
        git config --global http.lowSpeedTime 999999
        echo '>>> 更新子模块...'
        if [ -f coreboot/build-uefi.sh ]; then
            echo 'coreboot 已就绪，仅更新子模块'
            (cd coreboot && git submodule update --init --recursive) 2>/dev/null || true
        elif [ -n \"\$(ls -A coreboot 2>/dev/null)\" ]; then
            echo 'coreboot 目录存在但缺少源码，备份 blobs 后重新 clone...'
            tar -cf /tmp/coreboot_blobs_backup.tar -C coreboot 3rdparty 2>/dev/null || true
            rm -rf coreboot
            git submodule update --init --checkout --recursive
            tar -xf /tmp/coreboot_blobs_backup.tar -C coreboot 2>/dev/null || true
            rm -f /tmp/coreboot_blobs_backup.tar
        else
            git submodule update --init --checkout --recursive
        fi
        echo '>>> 编译固件...'
        for attempt in 1 2 3; do
            [ \$attempt -gt 1 ] && echo \">>> 第 \$attempt 次重试（克隆 EDK2 时网络不稳可多试几次）...\" && sleep 30
            (cd coreboot && ./build-uefi.sh $BOARD_NAME $DEBUG_FLAG) && exit 0
        done
        exit 1
    " 2>&1 | tee "$BUILD_LOG"

# 检查 docker 退出状态（通过 PIPESTATUS）
DOCKER_EXIT=${PIPESTATUS[0]}

# build-uefi.sh 输出到 ../roms，再按时间戳归入 roms/YYYYMMDDHHMMSS/ 避免同一天多次编译覆盖
echo ""
if compgen -G "roms/*.rom" >/dev/null 2>&1; then
    BUILD_DIR="roms/$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BUILD_DIR"
    mv roms/*.rom roms/*.sha1 "$BUILD_DIR/" 2>/dev/null || true
    # 复制编译时实际使用的 .config（make olddefconfig 后的最终配置）
    [ -f coreboot/.config ] && cp coreboot/.config "$BUILD_DIR/.config"
    # 移动编译日志到结果目录
    [ -f "$BUILD_LOG" ] && mv "$BUILD_LOG" "$BUILD_DIR/build.log"
    echo ">>> 编译完成，固件位于: $SCRIPT_DIR/$BUILD_DIR/"
    ls -la "$BUILD_DIR"/*.rom "$BUILD_DIR"/*.sha1 2>/dev/null || true
    [ -f "$BUILD_DIR/.config" ] && echo "    .config (编译配置)"
    [ -f "$BUILD_DIR/build.log" ] && echo "    build.log (编译日志)"
    [ -f "$SOURCE_TAR" ] && echo "    source.tar.gz (本次编译所用源码)"
else
    echo ">>> 编译结束，未发现 roms/*.rom（请检查编译日志: $BUILD_LOG）"
    if grep -qE "RPC failed|early EOF|recv error|fetch-pack" "$BUILD_LOG" 2>/dev/null; then
        echo ">>> 日志中疑似网络/TLS 错误。可多试几次，或在宿主机预克隆 EDK2 后重编："
        echo "    mkdir -p coreboot/payloads/external/edk2/workspace"
        echo "    git clone --recurse-submodules https://github.com/jackadam1981/mrchromebox_edk2.git coreboot/payloads/external/edk2/workspace/jackadam1981"
        echo "    再运行: sudo ./docker-build.sh"
    fi
    [ $DOCKER_EXIT -ne 0 ] && exit $DOCKER_EXIT
fi
