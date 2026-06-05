#!/bin/bash
# 开发模式启动 Flutter Web（绕过 dwds 序列化 bug）
#
# Flutter 3.44.0 的 dwds 调试服务器存在一个序列化 bug：
#   Deserializing to 'unspecified' failed due to: TypeError: Instance of '_JsonMap'
#   is not a subtype of type 'String'
#
# 禁用 DDS (Dart Developer Service) 可绕过此 bug，hot reload 仍然可用。
# 如需断点调试，使用 release 模式：flutter run -d chrome --release
#
# 使用方式：
#   scripts/dev_web.sh            # 启动 Chrome（需要图形界面）
#   scripts/dev_web.sh --server   # 启动 web-server（无图形界面时使用）

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Auto-detect X11 display for GUI
export DISPLAY=${DISPLAY:-:0}
if [ -z "$XAUTHORITY" ]; then
    for f in /run/user/$(id -u)/.mutter-Xwaylandauth.*; do
        if [ -f "$f" ]; then
            export XAUTHORITY="$f"
            break
        fi
    done
fi

if [ "$1" = "--server" ]; then
    echo "启动 web-server 模式 (http://localhost:8090)"
    flutter run -d web-server --no-dds --web-port 8090
else
    echo "启动 Chrome 模式"
    flutter run -d chrome --no-dds
fi