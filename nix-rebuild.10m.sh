#!/bin/bash
#
# <xbar.title>Nix Rebuild</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>Gayan Hewa</xbar.author>
# <xbar.desc>Discovers darwin hosts in your flakes and rebuilds them from the menu bar.</xbar.desc>
# <xbar.dependencies>nix,jq</xbar.dependencies>
#
# swiftbar.hideAbout=true
# swiftbar.hideRunInTerminal=true

export PATH="/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/etc/profiles/per-user/$USER/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# ---------------------------------------------------------------------------
# Config — .nix-rebuild.config next to this script may set:
#   FLAKES="~/Workspace/mydots ~/Workspace/other-flake"
# Defaults to ~/Workspace/mydots.
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/.nix-rebuild.config"
# shellcheck source=/dev/null
[ -f "$CONFIG" ] && . "$CONFIG"
FLAKES="${FLAKES:-$HOME/Workspace/mydots}"

SELF="$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")"

# Action mode: menu items re-invoke this script in a terminal so sudo can
# prompt for a password.
#   nix-rebuild.10m.sh switch|build <flake-dir> <host>
if [ -n "$1" ]; then
  FLAKE="$2" HOST="$3"
  case "$1" in
    switch)
      echo ">>> sudo darwin-rebuild switch --flake $FLAKE#$HOST"
      sudo darwin-rebuild switch --flake "$FLAKE#$HOST"
      ;;
    build)
      echo ">>> darwin-rebuild build --flake $FLAKE#$HOST"
      cd "$(mktemp -d)" || exit 1   # keep the ./result symlink out of real dirs
      darwin-rebuild build --flake "$FLAKE#$HOST"
      ;;
  esac
  rc=$?
  echo
  [ $rc -eq 0 ] && echo "✓ done" || echo "✗ failed (exit $rc)"
  read -r -p "Press enter to close"
  exit 0
fi

NIX=$(command -v nix)
JQ=$(command -v jq)
if [ -z "$NIX" ] || [ -z "$JQ" ]; then
  echo "❄️ ⚠️"
  echo "---"
  echo "nix or jq not found in PATH | color=red"
  exit 0
fi

THIS_HOST=$(hostname -s)
GEN=$(readlink /nix/var/nix/profiles/system 2>/dev/null | sed -E 's/system-([0-9]+)-link/\1/')

# Dirty if any flake repo has uncommitted changes.
DIRTY=""
for f in $FLAKES; do
  eval f="$f"
  [ -n "$(git -C "$f" status --porcelain 2>/dev/null)" ] && DIRTY="*"
done

echo "❄️$DIRTY"
echo "---"
echo "System generation ${GEN:-?} on $THIS_HOST | color=gray"

for f in $FLAKES; do
  eval f="$f"
  echo "---"
  if [ ! -f "$f/flake.nix" ]; then
    echo "$f — no flake.nix | color=red"
    continue
  fi

  LABEL="${f/#$HOME/~}"
  if [ -n "$(git -C "$f" status --porcelain 2>/dev/null)" ]; then
    echo "$LABEL (dirty) | color=#cc8800"
  else
    echo "$LABEL | color=#8888ff"
  fi

  HOSTS=$("$NIX" eval "$f#darwinConfigurations" --apply builtins.attrNames --json 2>/dev/null | "$JQ" -r '.[]')
  if [ -z "$HOSTS" ]; then
    echo "no darwinConfigurations found | color=gray"
    continue
  fi

  for h in $HOSTS; do
    if [ "$h" = "$THIS_HOST" ]; then
      echo "$h (this machine)"
    else
      echo "$h | color=gray"
    fi
    echo "--Switch | bash=$SELF param1=switch param2=$f param3=$h terminal=true refresh=true"
    echo "--Build only | bash=$SELF param1=build param2=$f param3=$h terminal=true"
  done
done

echo "---"
echo "Refresh | refresh=true"
