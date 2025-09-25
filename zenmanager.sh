#!/usr/bin/env bash
# ==========================================================
# Zen Manager
# Made by totallyfamousguy
# GitHub: https://github.com/totallyfamousguy/zen-manager
# ==========================================================

set -euo pipefail

SCRIPT_VERSION="2.0.1"
PKGNAME="zen-browser"
CUSTOM_TAG=""

check_script_update() {
  local latest_script
  latest_script=$(curl -sS "https://api.github.com/repos/totallyfamousguy/zen-manager/releases/latest" \
    | grep -m1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || true)

  local latest_clean="${latest_script#v}"
  local current_clean="${SCRIPT_VERSION#v}"

  if [ -n "$latest_clean" ] && [ "$latest_clean" != "$current_clean" ]; then
    echo "⬆️  A new version of Zen Manager is available: v$latest_clean (current: v$current_clean)"
    echo "👉 Download it here: https://github.com/totallyfamousguy/zen-manager/releases/latest"
    read -p "Do you want to continue with this old version now? (y/n) " ans
    if [ "${ans,,}" = "n" ]; then
      echo "ℹ️  Exiting the script, you can download and run the new version."
      exit 0
    else
      echo -e "\e[31m⚠️  You are running an outdated version of Zen Manager which may have bugs.\e[0m"
      read -p "Are you sure you want to continue with this old version? (y/n) " confirm
      if [ "${confirm,,}" != "y" ]; then
        echo "ℹ️  Exiting. Please download the latest version."
        exit 0
      fi
    fi
  fi
}
check_script_update

AUTO_YES=0
KEEP_FILES=0
DEBUG_MODE=0

for arg in "$@"; do
  case "$arg" in
    --help)
      echo "Zen Manager $SCRIPT_VERSION
Usage: sudo $0 [options]

Options:
  --help          Show this help and exit
  --yes           Automatically answer yes to all prompts
  --keep          Keep .deb and tarball after run
  --debug         Show dpkg-deb build output
  --version       Show script version
  --version-tag X Install a specific Zen Browser version"
      exit 0 ;;
    --yes) AUTO_YES=1 ;;
    --keep) KEEP_FILES=1 ;;
    --debug) DEBUG_MODE=1 ;;
    --version) echo "Zen Manager script version $SCRIPT_VERSION"; exit 0 ;;
    --version-tag)
      shift
      CUSTOM_TAG="$1"
      ;;
  esac
done

REQUIRED_CMDS=(curl tar dpkg-deb apt grep sed)
MISSING=()
for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING+=("$cmd")
  fi
done
if [ ${#MISSING[@]} -ne 0 ]; then
  echo "❌ Missing dependencies: ${MISSING[*]}"
  if [ $AUTO_YES -eq 1 ]; then
    echo "ℹ️  Installing missing dependencies..."
    apt update && apt install -y "${MISSING[@]}"
  else
    read -p "⚠️  Install missing dependencies now? (y/n) " resp
    if [ "${resp,,}" = "y" ]; then
      apt update && apt install -y "${MISSING[@]}"
    else
      echo "❌ Cannot continue without dependencies."; exit 1
    fi
  fi
fi

if [ "$EUID" -ne 0 ]; then
  echo "❌ This script must be run as root. Re-run with: sudo $0" >&2
  exit 1
fi

detect_archs() {
  case "$(uname -m)" in
    x86_64) TAR_ARCH="x86_64"; DEB_ARCH="amd64" ;;
    aarch64|arm64) TAR_ARCH="aarch64"; DEB_ARCH="arm64" ;;
    *) echo "❌ Unsupported CPU architecture: $(uname -m)" >&2; exit 1 ;;
  esac
}
detect_archs

TMPDIR=""
cleanup() { [ -n "${TMPDIR:-}" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"; }
trap cleanup EXIT

get_latest_version() {
  local json
  json=$(curl -sS "https://api.github.com/repos/zen-browser/desktop/releases/latest" 2>/dev/null || true)
  printf '%s\n' "$json" | grep -m1 '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

download_tarball() {
  local version="$1"
  local filename="zen_${version}_${TAR_ARCH}.tar.xz"
  local url="https://github.com/zen-browser/desktop/releases/download/${version}/zen.linux-${TAR_ARCH}.tar.xz"
  local outpath="$(pwd)/$filename"
  echo "⬇️  Downloading Zen ${version} (${TAR_ARCH}) ..." >&2
  if ! curl -sS -L -f -o "$outpath" "$url"; then
    echo "❌ Failed to download: $url" >&2; return 1
  fi
  printf '%s\n' "$outpath"
}

build_deb() {
  local tarball="$1"
  TMPDIR="$(mktemp -d)"
  local workdir="$TMPDIR/zen-pkg"
  local installdir="$workdir/opt/zen"
  local debdir="$workdir/DEBIAN"
  mkdir -p "$installdir" "$debdir"

  echo "📥 Extracting $(basename "$tarball") ..." >&2
  tar -xJf "$tarball" -C "$workdir/opt/" || { echo "❌ tar extraction failed" >&2; return 1; }

  local detected_version=""
  if [ -f "$installdir/application.ini" ]; then
    detected_version="$(grep -m1 '^Version=' "$installdir/application.ini" | cut -d'=' -f2 || true)"
  fi
  [ -z "$detected_version" ] && detected_version="$LATEST_TAG"

  echo "📦 Building package ${PKGNAME} version ${detected_version} ..." >&2

  mkdir -p "$workdir/usr/bin"
  cat > "$workdir/usr/bin/zen" <<'EOF'
#!/bin/sh
exec /opt/zen/zen "$@"
EOF
  chmod +x "$workdir/usr/bin/zen"

  mkdir -p "$workdir/usr/share/applications"
  cat > "$workdir/usr/share/applications/zen.desktop" <<EOF
[Desktop Entry]
Name=Zen Browser
Comment=Zen Browser (Firefox-based browser)
Exec=zen %u
Icon=/opt/zen/browser/chrome/icons/default/default128.png
Type=Application
Categories=Network;WebBrowser;
StartupWMClass=zen
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

  cat > "$debdir/control" <<EOF
Package: $PKGNAME
Version: $detected_version
Section: web
Priority: optional
Architecture: $DEB_ARCH
Maintainer: Zen Browser Team <support@zen-browser.app>
Description: Zen Browser
 A Firefox-based browser (Zen).
EOF

    local debfile="${PKGNAME}_${detected_version}_${DEB_ARCH}.deb"

  if [ $DEBUG_MODE -eq 1 ]; then
    set -x
    dpkg-deb --build --root-owner-group --verbose "$workdir" "$debfile"
    set +x
  else
    dpkg-deb --build --root-owner-group "$workdir" "$debfile" >/dev/null 2>&1
  fi

  [ ! -f "$debfile" ] && { echo "❌ Failed to build $debfile" >&2; return 1; }

  echo "✅ Successfully built $debfile" >&2
  rm -rf "$workdir"
  printf '%s\n' "$debfile"
}

installed_version() {
  if dpkg -s "$PKGNAME" >/dev/null 2>&1; then
    dpkg-query -W -f='${Version}' "$PKGNAME" 2>/dev/null || echo ""
  else
    echo ""
  fi
}

INST_VER="$(installed_version)"
LATEST_TAG="$(get_latest_version || true)"

if [ -n "$CUSTOM_TAG" ]; then
  LATEST_TAG="$CUSTOM_TAG"
fi

if [ -n "$INST_VER" ] && [ -n "$LATEST_TAG" ] && [ "$INST_VER" = "$LATEST_TAG" ]; then
  echo "✅ Zen is up to date (installed: $INST_VER)"
elif [ -n "$INST_VER" ] && [ -n "$LATEST_TAG" ]; then
  if [ $AUTO_YES -eq 1 ]; then resp="y"; else read -p "⚡ Update available ($INST_VER → $LATEST_TAG). Update now? (y/n) " resp; fi
  if [ "${resp,,}" = "y" ]; then
    TARPATH="$(download_tarball "$LATEST_TAG")"
    DEBFILE="$(build_deb "$TARPATH")"
    if [ $AUTO_YES -eq 1 ]; then inst="y"; else read -p "🚀 Install Zen now? (y/n) " inst; fi
    if [ "${inst,,}" = "y" ]; then
      echo "ℹ️  Installing $DEBFILE ..." >&2
      dpkg -i "./$DEBFILE" && apt-get install -f -y
      echo "✅ Installed $DEBFILE"
    else
      echo "✅ Update package ready: $DEBFILE"
    fi
    if [ $KEEP_FILES -eq 0 ]; then
      read -p "🧹 Remove $(basename "$TARPATH") and $(basename "$DEBFILE")? (y/n) " clean
      [ "${clean,,}" = "y" ] && rm -f "$TARPATH" "$DEBFILE"
    fi
  else
    echo "❌ Update skipped."
  fi
elif [ -z "$INST_VER" ]; then
  if [ -n "$CUSTOM_TAG" ]; then
    TARPATH="$(download_tarball "$LATEST_TAG")"
    DEBFILE="$(build_deb "$TARPATH")"
    if [ $AUTO_YES -eq 1 ]; then inst="y"; else read -p "🚀 Install Zen now? (y/n) " inst; fi
    if [ "${inst,,}" = "y" ]; then
      echo "ℹ️  Installing $DEBFILE ..." >&2
      dpkg -i "./$DEBFILE" && apt-get install -f -y
      echo "✅ Installed $DEBFILE"
    else
      echo "✅ Package ready: $DEBFILE"
    fi
    if [ $KEEP_FILES -eq 0 ]; then
      read -p "🧹 Remove $(basename "$TARPATH") and $(basename "$DEBFILE")? (y/n) " clean
      [ "${clean,,}" = "y" ] && rm -f "$TARPATH" "$DEBFILE"
    fi
  else
    if [ $AUTO_YES -eq 1 ]; then doinstall="y"; else read -p "📦 Zen is not installed. Install it now? (y/n) " doinstall; fi
    if [ "${doinstall,,}" = "y" ]; then
      [ -z "$LATEST_TAG" ] && { echo "❌ Cannot detect latest tag; supply a version." >&2; exit 1; }
      TARPATH="$(download_tarball "$LATEST_TAG")"
      DEBFILE="$(build_deb "$TARPATH")"
      if [ $AUTO_YES -eq 1 ]; then inst="y"; else read -p "🚀 Install Zen now? (y/n) " inst; fi
      if [ "${inst,,}" = "y" ]; then
        echo "ℹ️  Installing $DEBFILE ..." >&2
        dpkg -i "./$DEBFILE" && apt-get install -f -y
        echo "✅ Installed $DEBFILE"
      else
        echo "✅ Package ready: $DEBFILE"
      fi
      if [ $KEEP_FILES -eq 0 ]; then
        read -p "🧹 Remove $(basename "$TARPATH") and $(basename "$DEBFILE")? (y/n) " clean
        [ "${clean,,}" = "y" ] && rm -f "$TARPATH" "$DEBFILE"
      fi
    else
      echo "❌ Installation cancelled."
    fi
  fi
else
  echo "⚠️  Could not determine state. Installed: $INST_VER, Latest: $LATEST_TAG"
fi

exit 0

