#!/bin/bash
#
# <xbar.title>Claude Usage</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Gayan Hewa</xbar.author>
# <xbar.desc>Shows Claude quota windows (session, week, model) from quota-axi.</xbar.desc>
# <xbar.dependencies>quota-axi,jq</xbar.dependencies>
#
# swiftbar.hideAbout=true
# swiftbar.hideRunInTerminal=true

export PATH="/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

QUOTA=$(command -v quota-axi)
JQ=$(command -v jq)

if [ -z "$QUOTA" ] || [ -z "$JQ" ]; then
  echo "✳️ ⚠️"
  echo "---"
  echo "quota-axi or jq not found in PATH | color=red"
  exit 0
fi

JSON=$("$QUOTA" --provider claude --json 2>/dev/null)
STATE=$(echo "$JSON" | "$JQ" -r '.providers[0].state.status // "error"')

if [ "$STATE" != "fresh" ] && [ "$STATE" != "stale" ]; then
  echo "✳️ 🔒"
  echo "---"
  echo "claude quota unavailable ($STATE) | color=red"
  echo "Run: quota-axi --allow-keychain-prompt | color=gray"
  exit 0
fi

PLAN=$(echo "$JSON" | "$JQ" -r '.providers[0].plan // "unknown"')

# Badge: the session (five_hour) window, the one that bites first.
SESSION=$(echo "$JSON" | "$JQ" -r '[.providers[0].windows[] | select(.id == "five_hour") | .percentRemaining] | first // "?"')

badge_color=""
if [ "$SESSION" != "?" ]; then
  [ "$SESSION" -le 25 ] && badge_color=" | color=orange"
  [ "$SESSION" -le 10 ] && badge_color=" | color=red"
fi
echo "✳️ ${SESSION}%$badge_color"

echo "---"
echo "Claude quota ($PLAN plan) | color=#8888ff"

echo "$JSON" | "$JQ" -r '
  .providers[0].windows[]
  | select(.percentRemaining != null)
  | [.label, .percentRemaining, (.resetsAt // "" | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch 0), (.pace.status // "-"), (.pace.burnMultiple // 0)]
  | @tsv' |
while IFS=$'\t' read -r label pct reset pace burn; do
  color=""
  [ "$pct" -le 25 ] && color=" | color=orange"
  [ "$pct" -le 10 ] && color=" | color=red"
  echo "$label — ${pct}% left$color"
  if [ "$reset" != "0" ]; then
    echo "--resets $(date -r "$reset" +"%a %-d %b %H:%M") | color=gray"
  fi
  if [ "$pace" != "-" ]; then
    echo "--pace: $pace (burning ${burn}x) | color=gray"
  fi
done

# ---------------------------------------------------------------------------
# Usage by session: sum output tokens per transcript for messages inside the
# current five_hour window. Transcripts live in ~/.claude/projects/.
# ---------------------------------------------------------------------------
RESET_EPOCH=$(echo "$JSON" | "$JQ" -r '
  [.providers[0].windows[] | select(.id == "five_hour") | .resetsAt] | first // ""
  | sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | try fromdateiso8601 catch 0')
if [ "$RESET_EPOCH" -gt 0 ]; then
  START_EPOCH=$((RESET_EPOCH - 18000))
else
  START_EPOCH=$(($(date +%s) - 18000))
fi
START_ISO=$(date -u -r "$START_EPOCH" +"%Y-%m-%dT%H:%M:%SZ")
START_LOCAL=$(date -r "$START_EPOCH" +"%H:%M")
AGE_MIN=$((($(date +%s) - START_EPOCH) / 60 + 1))

echo "---"
echo "By session since $START_LOCAL | color=#8888ff"

find "$HOME/.claude/projects" -name '*.jsonl' -mmin "-$AGE_MIN" 2>/dev/null |
while read -r f; do
  "$JQ" -r --arg start "$START_ISO" --arg file "$f" '
    [inputs? | select(.type? == "assistant" and .timestamp >= $start)
     | .message.usage.output_tokens // 0] as $outs
    | if ($outs | length) > 0 then
        [($outs | add), $file] | @tsv
      else empty end
  ' -n "$f" 2>/dev/null
done | sort -rn | head -8 |
while IFS=$'\t' read -r tokens f; do
  proj=$(basename "$(dirname "$f")" | sed "s|^-Users-$USER-||; s|^Workspace-||")
  prompt=$("$JQ" -r '[inputs? | select(.type? == "user" and (.message.content | type == "string"))
    | .message.content] | first // "" | gsub("\\s+"; " ") | .[0:40] | gsub("\\|"; "/")' -n "$f" 2>/dev/null)
  if [ "$tokens" -ge 1000 ]; then
    disp="$((tokens / 1000))k"
  else
    disp="$tokens"
  fi
  echo "$proj — $disp out | length=60"
  [ -n "$prompt" ] && echo "--\"$prompt\" | color=gray"
done

echo "---"
echo "Refresh | refresh=true"
