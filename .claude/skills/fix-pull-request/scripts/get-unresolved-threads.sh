#!/bin/bash
# 未resolvedスレッド取得（GraphQL）
PR_ARG="${1:-}"
if [ -n "$PR_ARG" ]; then
  PR_NUM=$(gh pr view "$PR_ARG" --json number --jq '.number' 2>/dev/null)
else
  PR_NUM=$(gh pr view --json number --jq '.number')
fi
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER="${REPO%%/*}"
REPONAME="${REPO##*/}"
gh api graphql \
  -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:50){nodes{id,isResolved,comments(first:1){nodes{body,author{login},path,line}}}}}}}' \
  -F owner="$OWNER" -F repo="$REPONAME" -F pr="$PR_NUM"
