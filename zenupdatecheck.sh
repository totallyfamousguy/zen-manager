#!/usr/bin/env bash

set -euo pipefail

PKGNAME="zen-browser"
MAIN_SCRIPT="/path/to/main/script.sh"  # set this to your real script path

installed_version() {
  if dpkg -s "$PKGNAME" >/dev/null 2>&1; then
    dpkg-query -W -f='${Version}' "$PKGNAME" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

get_latest_version() {
  curl -sS "https://api.github.com/repos/zen-browser/desktop/releases/latest" \
    | grep -m1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true
}

INST_VER="$(installed_version)"
LATEST_TAG="$(get_latest_version || true)"

[ -z "$LATEST_TAG" ] && exit 0
[ "$INST_VER" = "$LATEST_TAG" ] && exit 0
[ -z "$MAIN_SCRIPT" ] && exit 0

CMD="sudo $MAIN_SCRIPT"

if command -v zenity >/dev/null 2>&1; then
  zenity --question \
    --title="Zen Browser Update Available" \
    --width=500 \
    --ok-label="Copy" \
    --cancel-label="OK" \
    --text="<b>A new version of Zen Browser ($LATEST_TAG) is available.</b>

Paste the following command in your terminal to update:

<tt>$CMD</tt>"

  RESPONSE=$?
  if [ "$RESPONSE" -eq 0 ]; then
    if command -v xclip >/dev/null 2>&1; then
      printf "%s" "$CMD" | xclip -selection clipboard
    elif command -v wl-copy >/dev/null 2>&1; then
      printf "%s" "$CMD" | wl-copy
    else
      zenity --info \
        --title="Couldn't Copy" \
        --width=500 \
        --text="❌ Couldn't copy to clipboard.

Please manually copy the command below:

<tt>$CMD</tt>"
    fi
  fi
fi

exit 0

