---
name: fix-pr
description: PRのレビューコメントを確認し、対応プランを構築・実装・返信・コミット・resolveする
argument-hint: [pr-number]
---

## コンテキスト

PR概要:
!`gh pr view ${ARGUMENTS:-} --json number,title,url,headRefName,baseRefName,state 2>/dev/null || gh pr view --json number,title,url,headRefName,baseRefName,state`

インラインレビューコメント:
!`PR_NUM=$(gh pr view ${ARGUMENTS:-} --json number --jq '.number' 2>/dev/null || gh pr view --json number --jq '.number'); REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner'); gh api repos/$REPO/pulls/$PR_NUM/comments`

一般コメント:
!`PR_NUM=$(gh pr view ${ARGUMENTS:-} --json number --jq '.number' 2>/dev/null || gh pr view --json number --jq '.number'); REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner'); gh api repos/$REPO/issues/$PR_NUM/comments`

レビューサマリー:
!`gh pr view ${ARGUMENTS:-} --json reviews 2>/dev/null || gh pr view --json reviews`

未resolvedスレッド一覧 (threadId含む):
!`PR_NUM=$(gh pr view ${ARGUMENTS:-} --json number --jq '.number' 2>/dev/null || gh pr view --json number --jq '.number'); REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner'); OWNER=${REPO%%/*}; REPONAME=${REPO##*/}; gh api graphql -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:50){nodes{id,isResolved,comments(first:1){nodes{body,author{login},path,line}}}}}}}' -F owner="$OWNER" -F repo="$REPONAME" -F pr=$PR_NUM`

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
PR_NUM=$(gh pr view ${ARGUMENTS:-} --json number --jq '.number' 2>/dev/null || gh pr view --json number --jq '.number')
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
gh api repos/$REPO/pulls/$PR_NUM/comments/<comment_id>/replies \
  -X POST \
  -f body="<返信内容（日本語）>"
```

**一般コメントへの返信:**
```bash
PR_NUM=$(gh pr view ${ARGUMENTS:-} --json number --jq '.number' 2>/dev/null || gh pr view --json number --jq '.number')
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
gh api repos/$REPO/issues/$PR_NUM/comments \
  -X POST \
  -f body="<返信内容（日本語）>"
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
gh api graphql -f query='mutation($threadId:ID!){resolveReviewThread(input:{threadId:$threadId}){thread{id,isResolved}}}' \
  -F threadId="<PRRT_...>"
```

対応不要と判断したスレッドも理由を返信したうえでresolveする。

### 完了報告

すべてのステップが完了したら、以下を日本語でまとめて報告する:

- 対応したレビューコメントの一覧と対応内容
- コミットハッシュ
- resolveしたスレッド数
- 対応しなかったコメントがある場合はその理由
