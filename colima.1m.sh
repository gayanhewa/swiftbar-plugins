#!/bin/bash
#
# <xbar.title>Colima</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Gayan Hewa</xbar.author>
# <xbar.desc>Shows Colima VM status per profile with start/stop/restart actions.</xbar.desc>
# <xbar.dependencies>colima,jq</xbar.dependencies>
#
# swiftbar.hideAbout=true
# swiftbar.hideRunInTerminal=true

export PATH="/opt/homebrew/bin:/usr/local/bin:/etc/profiles/per-user/$USER/bin:$HOME/homebrew/bin:$PATH"

COLIMA=$(command -v colima)
JQ=$(command -v jq)

# Action mode: the script re-invokes itself from menu items.
#   colima.1m.sh start|stop|restart <profile>
if [ -n "$1" ]; then
  case "$1" in
    start)   "$COLIMA" start   --profile "$2" ;;
    stop)    "$COLIMA" stop    --profile "$2" ;;
    restart) "$COLIMA" restart --profile "$2" ;;
  esac
  exit 0
fi

if [ -z "$COLIMA" ] || [ -z "$JQ" ]; then
  echo "🐳 ⚠️"
  echo "---"
  echo "colima or jq not found in PATH | color=red"
  exit 0
fi

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# One JSON object per line, one per instance. Empty when none exist.
LIST=$("$COLIMA" list -j 2>/dev/null)

if [ -z "$LIST" ]; then
  echo "🐳 –"
  echo "---"
  echo "No colima instances | color=gray"
  echo "Start default | bash=$SELF param1=start param2=default terminal=false refresh=true"
  echo "---"
  echo "Refresh | refresh=true"
  exit 0
fi

RUNNING=$(echo "$LIST" | "$JQ" -s '[.[] | select(.status == "Running")] | length')
TOTAL=$(echo "$LIST" | "$JQ" -s 'length')

if [ "$RUNNING" -gt 0 ]; then
  echo "🐳 $RUNNING"
else
  echo "🐳 ✕"
fi

echo "---"

echo "$LIST" | "$JQ" -c -s 'sort_by(.name) | .[]' | while read -r inst; do
  NAME=$(echo "$inst" | "$JQ" -r '.name')
  STATUS=$(echo "$inst" | "$JQ" -r '.status')
  INFO=$(echo "$inst" | "$JQ" -r '
    [ .runtime,
      .arch,
      (if .cpus then "\(.cpus)cpu" else null end),
      (if .memory then "\(.memory / 1073741824 | floor)G" else null end)
    ] | map(select(. != null)) | join(" · ")')

  if [ "$STATUS" = "Running" ]; then
    echo "🟢 $NAME — $INFO"
    echo "--Stop | bash=$SELF param1=stop param2=$NAME terminal=false refresh=true"
    echo "--Restart | bash=$SELF param1=restart param2=$NAME terminal=false refresh=true"
  else
    echo "🔴 $NAME — $STATUS | color=gray"
    echo "--Start | bash=$SELF param1=start param2=$NAME terminal=false refresh=true"
  fi
done

echo "---"
echo "Refresh | refresh=true"
