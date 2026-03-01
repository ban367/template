#!/bin/bash
set -euo pipefail

BASE_BRANCH="${1:-main}"

# ブランチ名のバリデーション（コマンドインジェクション対策）
if [[ ! "$BASE_BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
  echo "エラー: 無効なブランチ名です: $BASE_BRANCH" >&2
  exit 1
fi

# コミット済み差分ファイル数
COMMITTED_COUNT=$(git diff "$BASE_BRANCH" --name-only 2>/dev/null | wc -l | tr -d ' ')

# 未追跡ファイル数（新規作成ファイル）
UNTRACKED_COUNT=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

# 未コミット変更ファイル数（staged + unstaged）
MODIFIED_COUNT=$(git diff --name-only 2>/dev/null | wc -l | tr -d ' ')
STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

FILE_COUNT=$((COMMITTED_COUNT + UNTRACKED_COUNT + MODIFIED_COUNT + STAGED_COUNT))

# 行数サマリー（コミット済み差分が主体）
STAT=$(git diff "$BASE_BRANCH" --shortstat 2>/dev/null || echo "")
if [ -n "$STAT" ]; then
  ADDED=$(echo "$STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
  DELETED=$(echo "$STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
else
  ADDED="0"
  DELETED="0"
fi

echo "変更ファイル数: ${FILE_COUNT}"
echo "  コミット済み差分: ${COMMITTED_COUNT}"
echo "  未コミット変更: $((MODIFIED_COUNT + STAGED_COUNT))"
echo "  未追跡ファイル: ${UNTRACKED_COUNT}"
echo "追加行数: +${ADDED}"
echo "削除行数: -${DELETED}"

if [ "$FILE_COUNT" -le 20 ]; then
  echo "レビューモード: 通常モード（全差分を一括取得）"
else
  echo "レビューモード: ファイル別モード（ファイルごとに逐次取得）"
fi
