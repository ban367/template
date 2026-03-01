#!/bin/bash
# インラインレビューコメント取得
PR_ARG="${1:-}"
if [ -n "$PR_ARG" ]; then
  PR_NUM=$(gh pr view "$PR_ARG" --json number --jq '.number' 2>/dev/null)
else
  PR_NUM=$(gh pr view --json number --jq '.number')
fi
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
gh api "repos/$REPO/pulls/$PR_NUM/comments"
