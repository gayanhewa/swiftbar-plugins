#!/bin/bash
#
# <xbar.title>GitHub PR Reviews</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Gayan Hewa</xbar.author>
# <xbar.desc>Lists open PRs where your review is requested, plus your own open PRs.</xbar.desc>
# <xbar.dependencies>gh,jq</xbar.dependencies>
#
# swiftbar.hideAbout=true
# swiftbar.hideRunInTerminal=true

export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/homebrew/bin:$PATH"

# ---------------------------------------------------------------------------
# Config — read from .gh-reviews.config next to this script (see that file).
# An exported GH_PR_REPOS / GH_PR_OWNERS still wins over the config file.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/.gh-reviews.config"

ENV_REPOS="${GH_PR_REPOS:-}"
ENV_OWNERS="${GH_PR_OWNERS:-}"

# shellcheck source=/dev/null
[ -f "$CONFIG" ] && . "$CONFIG"

REPOS="${ENV_REPOS:-${REPOS:-}}"
OWNERS="${ENV_OWNERS:-${OWNERS:-}}"

GH=$(command -v gh)
JQ=$(command -v jq)

if [ -z "$GH" ] || [ -z "$JQ" ]; then
  echo "PR ⚠️"
  echo "---"
  echo "gh or jq not found in PATH | color=red"
  exit 0
fi

if ! "$GH" auth status >/dev/null 2>&1; then
  echo "PR 🔒"
  echo "---"
  echo "gh not authenticated | color=red"
  echo "Run: gh auth login | color=gray"
  exit 0
fi

SCOPE=()
for r in $REPOS; do SCOPE+=("--repo=$r"); done
for o in $OWNERS; do SCOPE+=("--owner=$o"); done

fetch() {
  "$GH" search prs --state=open --limit 30 \
    --json number,title,url,repository,updatedAt,isDraft \
    "${SCOPE[@]}" "$@" 2>/dev/null
}

REVIEWS=$(fetch --review-requested=@me)
MINE=$(fetch --author=@me)

[ -z "$REVIEWS" ] && REVIEWS="[]"
[ -z "$MINE" ] && MINE="[]"

# Badge counts only actionable (non-draft) review requests; drafts are listed
# but dimmed, since they are not yet asking for review.
REVIEW_COUNT=$(echo "$REVIEWS" | "$JQ" '[.[] | select(.isDraft == false)] | length')
REVIEW_TOTAL=$(echo "$REVIEWS" | "$JQ" 'length')
MINE_TOTAL=$(echo "$MINE" | "$JQ" 'length')

if [ "$REVIEW_COUNT" -gt 0 ]; then
  echo "👀 $REVIEW_COUNT"
else
  echo "👀"
fi

echo "---"

render() {
  echo "$1" | "$JQ" -r '
    sort_by(.isDraft, .updatedAt)
    | reverse | sort_by(.isDraft)
    | .[]
    | (if .isDraft then " 📝" else "" end) as $tag
    | (if .isDraft then " | color=gray" else "" end) as $dim
    | "\(.repository.nameWithOwner)#\(.number)\($tag) — \(.title | if length > 60 then .[0:60] + "…" else . end) | href=\(.url) | length=100\($dim)\n--\(.repository.nameWithOwner) · updated \(.updatedAt) | color=gray"
  '
}

DRAFTS=$((REVIEW_TOTAL - REVIEW_COUNT))
if [ "$DRAFTS" -gt 0 ]; then
  echo "Awaiting my review ($REVIEW_COUNT + $DRAFTS draft) | color=#8888ff"
else
  echo "Awaiting my review ($REVIEW_COUNT) | color=#8888ff"
fi
if [ "$REVIEW_TOTAL" -eq 0 ]; then
  echo "Nothing to review 🎉 | color=gray"
else
  render "$REVIEWS"
fi

echo "---"
echo "My open PRs ($MINE_TOTAL) | color=#8888ff"
if [ "$MINE_TOTAL" -eq 0 ]; then
  echo "None | color=gray"
else
  render "$MINE"
fi

echo "---"
echo "Refresh | refresh=true"
