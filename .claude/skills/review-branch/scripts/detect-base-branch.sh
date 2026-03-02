#!/bin/bash
set -euo pipefail

# 現在のブランチを取得
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [ "$CURRENT_BRANCH" = "HEAD" ]; then
  echo "検出失敗: detached HEAD 状態です"
  echo "推定ベースブランチ: main"
  exit 0
fi

# main / master のどちらが存在するかを確認
DEFAULT_BRANCH=""
if git rev-parse --verify main >/dev/null 2>&1; then
  DEFAULT_BRANCH="main"
elif git rev-parse --verify master >/dev/null 2>&1; then
  DEFAULT_BRANCH="master"
fi

# 現在のブランチがデフォルトブランチ自体の場合
if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "検出失敗: 現在デフォルトブランチ ($DEFAULT_BRANCH) 上にいます"
  echo "推定ベースブランチ: $DEFAULT_BRANCH"
  exit 0
fi

# ローカルブランチの中から、現在のブランチとの merge-base が最も近いものを探す
BEST_BRANCH=""
BEST_DISTANCE=999999

for BRANCH in $(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null); do
  # 自分自身はスキップ
  [ "$BRANCH" = "$CURRENT_BRANCH" ] && continue

  MERGE_BASE=$(git merge-base "$CURRENT_BRANCH" "$BRANCH" 2>/dev/null || echo "")
  [ -z "$MERGE_BASE" ] && continue

  # merge-base から現在のブランチの HEAD までのコミット数（少ないほど分岐が近い）
  DISTANCE=$(git rev-list --count "$MERGE_BASE".."$CURRENT_BRANCH" 2>/dev/null || echo "999999")

  # 同距離ならデフォルトブランチを優先
  if [ "$DISTANCE" -lt "$BEST_DISTANCE" ] || { [ "$DISTANCE" -eq "$BEST_DISTANCE" ] && [ "$BRANCH" = "$DEFAULT_BRANCH" ]; }; then
    BEST_DISTANCE="$DISTANCE"
    BEST_BRANCH="$BRANCH"
  fi
done

# 結果出力
if [ -n "$BEST_BRANCH" ]; then
  echo "推定ベースブランチ: $BEST_BRANCH"
else
  # フォールバック: デフォルトブランチがあればそれを使う
  if [ -n "$DEFAULT_BRANCH" ]; then
    echo "推定ベースブランチ: $DEFAULT_BRANCH"
  else
    echo "検出失敗: ベースブランチを特定できませんでした"
    echo "推定ベースブランチ: main"
  fi
fi
