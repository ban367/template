#!/bin/bash
set -euo pipefail
# インラインレビューコメント取得
PR_ARG="${1:-}"
set +e
if [ -n "$PR_ARG" ]; then
  PR_NUM=$(gh pr view "$PR_ARG" --json number --jq '.number' 2>/dev/null)
else
  PR_NUM=$(gh pr view --json number --jq '.number' 2>/dev/null)
fi
set -e
if [ -z "$PR_NUM" ]; then
  if [ -n "$PR_ARG" ]; then
    echo "Error: failed to resolve pull request from argument '${PR_ARG}'." >&2
  else
    echo "Error: failed to resolve current pull request. Are you on a pull request branch?" >&2
  fi
  exit 1
fi
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
gh api --paginate "repos/$REPO/pulls/$PR_NUM/comments"
