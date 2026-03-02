---
name: review-branch
description: 現在のブランチにおける開発内容を分岐元ブランチからの差分をもとにコードレビューする
---

## コンテキスト

現在のブランチ:
!`git rev-parse --abbrev-ref HEAD`

分岐元ブランチの自動検出結果:
!`bash .claude/skills/review-branch/scripts/detect-base-branch.sh`

作業ツリーの変更状況（未コミット・未追跡を含む）:
!`git status --short`

## 手順

### ステップ0: ベースブランチの確認

レビューを開始する前に、差分の起点となるブランチをユーザーに確認する。

コンテキストの「分岐元ブランチの自動検出結果」に表示されたブランチ名を提示し、ユーザーに確認する。
AskUserQuestion ツールを使い、検出されたブランチを第一選択肢として提示すること。

確認が取れたら、そのブランチ名を `<base-branch>` としてステップ1で使用する。

### ステップ1: reviewer エージェントによるレビュー実施

Agent ツールで `reviewer` エージェントを起動し、コードレビューを実行させる。

**起動パラメータ:**
- `subagent_type`: `reviewer`
- `prompt`: 「現在のブランチをベースブランチ `<base-branch>` からの差分でコードレビューしてください。」

reviewer エージェントがレビュー全工程（差分取得・規約読込・レビュー・構造化出力）を自己完結で実行する。
結果が返却されるまで待機する。

### ステップ2: ユーザーへの確認

レビュー結果を提示したあと、以下を確認する:

- CRITICAL または WARNING の修正を実施するか
- 修正依頼があれば、以下の手順に準じて対応する:
  1. 対象ファイルを編集して修正を実施する
  2. 修正内容を英語・Conventional Commits形式でコミットする:
     ```bash
     git add <変更ファイル>
     git commit -m "$(cat <<'EOF'
     fix: address review issues

     - <対応内容1の英語要約>
     - <対応内容2の英語要約>

     Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
     EOF
     )"
     ```
  3. 修正内容と対応した指摘の一覧を日本語で報告する
