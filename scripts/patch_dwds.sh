#!/bin/bash
# 修复 dwds 26.2.5 序列化 Bug
#
# 该补丁解决 Flutter 3.44.0 debug 模式下白屏崩溃问题：
#   Deserializing to 'unspecified' failed due to: TypeError: Instance of '_JsonMap'
#   is not a subtype of type 'String'
#
# 根因：dwds 的 main__closure5.call$2 中 A._asString(eventData) 强制要求字符串，
# 但 Chrome CDP 发送的 eventData 是 JSON 对象。JSON.stringify 可安全处理两种情况。
#
# 适用版本：dwds 26.2.5（Flutter 3.44.0 内置）

set -e

PATCH_DIRS=(
    "$HOME/.pub-cache/hosted/pub.dev/dwds-26.2.5/lib/src/injected"
    "$HOME/.pub-cache/hosted/pub.dev/dwds-26.2.3/lib/src/injected"
    "$HOME/.pub-cache/hosted/pub.dev/dwds-24.1.0/lib/src/injected"
    "$HOME/.pub-cache/hosted/pub.dev/dwds-24.0.0/lib/src/injected"
)

PATCHED=0
for dir in "${PATCH_DIRS[@]}"; do
    FILE="$dir/client.js"
    if [ ! -f "$FILE" ]; then
        continue
    fi
    if grep -q "JSON.stringify(eventData)" "$FILE"; then
        echo "✅ 已打补丁: $FILE"
        continue
    fi
    if ! grep -q "main__closure5.prototype" "$FILE"; then
        echo "⏭️  跳过（版本不同）: $FILE"
        continue
    fi
    sed -i 's/A._asString(eventData);/if (typeof eventData !== "string") eventData = JSON.stringify(eventData);\n      A._asString(eventData);/' "$FILE"
    echo "🔧 已修复: $FILE"
    PATCHED=$((PATCHED + 1))
done

if [ "$PATCHED" -eq 0 ]; then
    echo "没有需要修复的 dwds 版本，或者所有版本已打补丁。"
else
    echo "成功修复 $PATCHED 个 dwds 版本。"
fi