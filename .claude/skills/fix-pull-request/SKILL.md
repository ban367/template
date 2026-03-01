---
name: fix-pr
description: PRのレビューコメントを確認し、対応プランを構築・実装・返信・コミット・resolveする
---

## コンテキスト

PR概要:
!`gh pr view --json number,title,url,headRefName,baseRefName,state`

インラインレビューコメント:
!`bash .claude/skills/fix-pull-request/scripts/get-inline-comments.sh`

一般コメント:
!`bash .claude/skills/fix-pull-request/scripts/get-general-comments.sh`

レビューサマリー:
!`gh pr view --json reviews`

未resolvedスレッド一覧 (threadId含む):
!`bash .claude/skills/fix-pull-request/scripts/get-unresolved-threads.sh`

## 手順

### ステップ1: レビュー分析

上記コンテキストを読み込み、以下を整理する:

- 未resolved（`isResolved: false`）のスレッドを全件リストアップ
- インラインコメント（ファイル・行情報付き）と一般コメントを区別する
- 各コメントに含まれる指摘内容・要望・質問を把握する
- 必要であれば `gh pr diff` でdiffを取得して変更箇所を確認する

### ステップ2: 対応プランの構築

コメントごとに対応方針を明示する:

- コード修正が必要なもの → 修正内容を具体的に示す
- 質問・確認事項 → 返答内容を草案する
- 対応不要・意図的なもの → その理由を説明する

**重要**: 対応方針に不明点や判断が難しい点がある場合は、実装前にユーザーに確認する。

### ステップ3: コード修正

AGENTS.mdおよび `.github/instructions/general.instructions.md` の規約に従い実装する:

- 最小限の変更にとどめる（レビューコメントへの対応のみ）
- 1関数1機能・スコープを狭く保つ
- セキュリティ・エラーハンドリングの規約を遵守する

### ステップ4: コメント返信

各コメントに日本語で返信する。

**インラインコメントへの返信:**
```bash
REPLY_FILE=$(mktemp)
cat > "$REPLY_FILE" << 'JSONEOF'
{"body": "<返信内容（日本語）>"}
JSONEOF
PR_NUM=$(gh pr view --json number --jq '.number')
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
gh api repos/$REPO/pulls/$PR_NUM/comments/<comment_id>/replies \
  -X POST --input "$REPLY_FILE"
rm -f "$REPLY_FILE"
```

**一般コメントへの返信:**
```bash
REPLY_FILE=$(mktemp)
cat > "$REPLY_FILE" << 'JSONEOF'
{"body": "<返信内容（日本語）>"}
JSONEOF
PR_NUM=$(gh pr view --json number --jq '.number')
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
gh api repos/$REPO/issues/$PR_NUM/comments \
  -X POST --input "$REPLY_FILE"
rm -f "$REPLY_FILE"
```

返信内容の例:
- 修正対応: 「ご指摘のとおり修正しました。`<修正内容の概要>` に変更しています。」
- 質問への回答: 「`<質問内容>` についてですが、`<回答>` のため現状の実装としています。」
- 意図的な実装: 「`<理由>` のため意図的にこの実装としています。問題があればご指摘ください。」

### ステップ5: コミット

英語・Conventional Commits形式でコミットする（AGENTS.mdの規約に従う）:

```bash
git add <変更ファイル>
git commit -m "$(cat <<'EOF'
fix: address review comments

- <対応内容1の英語要約>
- <対応内容2の英語要約>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

使用するプレフィックス例:
- `fix:` バグ修正・レビュー指摘への修正
- `refactor:` リファクタリング
- `docs:` ドキュメント修正
- `style:` コードスタイル修正
- `test:` テスト追加・修正

### ステップ6: スレッドresolve

対応済みスレッドを `resolveReviewThread` GraphQL mutationでresolveする。

threadIdはコンテキストで取得済みの `id`（`PRRT_...` 形式）を使用する:

```bash
JFILE=$(mktemp)
cat > "$JFILE" << 'ENDJSON'
{"query": "mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId}){thread{id,isResolved}}}"}
ENDJSON
jq --arg tid "<PRRT_...>" '. + {variables: {threadId: $tid}}' "$JFILE" | gh api graphql --input -
rm -f "$JFILE"
```

対応不要と判断したスレッドも理由を返信したうえでresolveする。

### 完了報告

すべてのステップが完了したら、以下を日本語でまとめて報告する:

- 対応したレビューコメントの一覧と対応内容
- コミットハッシュ
- resolveしたスレッド数
- 対応しなかったコメントがある場合はその理由
