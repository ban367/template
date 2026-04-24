#!/bin/bash
set -euo pipefail
# PR対応に必要なコンテキストを1クエリで取得する
# - PR概要（number, title, url, head/baseRefName, state）
# - reviews（state, author, body）直近50件
# - 未resolvedのreviewThreads（threadId + 全コメントのid/body/author/path/line）
# - general issueComments（databaseId, author, body）直近50件
#
# 使い方:
#   bash get-pr-context.sh           # 現在のブランチのPR
#   bash get-pr-context.sh <PR番号>  # 明示指定

PR_ARG="${1:-}"
set +e
if [ -n "$PR_ARG" ]; then
  PR_NUM=$(gh pr view "$PR_ARG" --json number --jq '.number' 2>/dev/null)
else
  PR_NUM=$(gh pr view --json number --jq '.number' 2>/dev/null)
fi
set -e
if [ -z "$PR_NUM" ]; then
  echo "エラー: プルリクエストを解決できませんでした。" >&2
  exit 1
fi
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
OWNER="${REPO%%/*}"
REPONAME="${REPO##*/}"

QUERY='query($owner:String!,$repo:String!,$pr:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$pr){number,title,url,state,headRefName,baseRefName,reviews(last:50){nodes{state,author{login},body,submittedAt}},comments(last:50){nodes{databaseId,author{login},body,createdAt}},reviewThreads(first:100,after:$after){pageInfo{hasNextPage,endCursor}nodes{id,isResolved,isOutdated,path,line,comments(first:50){nodes{databaseId,body,author{login},path,line,createdAt}}}}}}}'

AFTER="null"
HAS_NEXT="true"
THREADS='[]'
META='null'
REVIEWS='[]'
GENERAL='[]'

while [ "$HAS_NEXT" = "true" ]; do
  RESPONSE=$(gh api graphql \
    -f query="$QUERY" \
    -F owner="$OWNER" -F repo="$REPONAME" -F pr="$PR_NUM" \
    -F after="$AFTER")
  if [ "$META" = "null" ]; then
    META=$(printf '%s\n' "$RESPONSE" | jq '.data.repository.pullRequest | {number,title,url,state,headRefName,baseRefName}')
    REVIEWS=$(printf '%s\n' "$RESPONSE" | jq '.data.repository.pullRequest.reviews.nodes')
    GENERAL=$(printf '%s\n' "$RESPONSE" | jq '.data.repository.pullRequest.comments.nodes')
  fi
  PAGE=$(printf '%s\n' "$RESPONSE" | jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]')
  THREADS=$(jq -s '.[0] + .[1]' <(printf '%s\n' "$THREADS") <(printf '%s\n' "$PAGE"))
  HAS_NEXT=$(printf '%s\n' "$RESPONSE" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  AFTER=$(printf '%s\n' "$RESPONSE" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
done

jq -n \
  --argjson meta "$META" \
  --argjson reviews "$REVIEWS" \
  --argjson general "$GENERAL" \
  --argjson threads "$THREADS" \
  '{pr: $meta, reviews: $reviews, generalComments: $general, unresolvedThreads: $threads}'
