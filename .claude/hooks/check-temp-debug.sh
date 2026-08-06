#!/bin/bash
# PreToolUse hook: git commit実行前に、ステージ済み差分にTEMP DEBUGが
# 含まれていればコミットをブロックする。
#
# 背景: 検証用に仕込んだ "// TEMP DEBUG" コードの削除忘れが、過去2回
# 「アプリが壊れている」という実害のあるユーザー報告を招いた。Claudeの
# 自己判断(grepし忘れる可能性がある)ではなく、機械的に防ぐためのHook。

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("tool_input", {}).get("command", ""))
except Exception:
    print("")
')

# git commit を含まないコマンドは対象外、そのまま許可する
case "$COMMAND" in
  *git\ commit*) ;;
  *) exit 0 ;;
esac

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || true

if git diff --cached -- '*.swift' | grep -q "TEMP DEBUG"; then
  echo "ステージ済みの差分に \"TEMP DEBUG\" が含まれています。検証用の一時コードが残ったままコミットしようとしています。削除してから再度コミットしてください（grep -rn \"TEMP DEBUG\" --include=\"*.swift\" . で確認できます）。" >&2
  exit 2
fi

exit 0
