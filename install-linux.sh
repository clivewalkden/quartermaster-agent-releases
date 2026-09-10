#!/usr/bin/env bash
# Quartermaster Agent installer for Linux (systemd).
#
# Usage (published to the public releases repo — see release.yml, same pattern as
# install-mac.sh):
#   curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/install-linux.sh | bash
#
# Non-interactive (e.g. scripted/config-management push): pass --yes to skip both prompts and
# use API_KEY / LOCATION from the environment instead.
#   curl -fsSL .../install-linux.sh | API_KEY=xxx LOCATION="London Office" bash -s -- --yes
#
# Detects Fedora/RHEL/CentOS/Rocky/AlmaLinux/openSUSE (rpm, via `rpm -Uvh`) vs
# Debian/Ubuntu/everything else (deb, via `dpkg -i`) from /etc/os-release — same detection
# `quartermaster-agent --self-update` uses internally, see agent.go's linuxPackageFamily.
#
# Downloads the latest package, verifies its checksum, installs it (this also scaffolds the
# systemd unit/timer and env file automatically — see .goreleaser.yml's nfpms contents/scripts),
# prompts for your API key and location, and triggers a first run to confirm it worked. See
# INSTALLATION.md in the quartermaster-agent source repo for the manual step-by-step equivalent
# and troubleshooting.
set -euo pipefail

REPO="clivewalkden/quartermaster-agent-releases"
BASE="https://github.com/${REPO}/releases/latest/download"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Quartermaster Agent installer"
echo "=============================="
echo

if [ "$(uname -s)" != "Linux" ]; then
  echo "This installer is for Linux only. See INSTALLATION.md in the quartermaster-agent repo for macOS/Windows." >&2
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) PKG_ARCH=amd64 ;;
  aarch64|arm64) PKG_ARCH=arm64 ;;
  *)
    echo "Unsupported architecture: $ARCH (only amd64/arm64 are published)." >&2
    exit 1
    ;;
esac

FAMILY=deb
if [ -r /etc/os-release ]; then
  OS_RELEASE_LC="$(tr '[:upper:]' '[:lower:]' < /etc/os-release)"
  case "$OS_RELEASE_LC" in
    *fedora*|*rhel*|*centos*|*rocky*|*almalinux*|*suse*) FAMILY=rpm ;;
  esac
fi
echo "Detected package family: $FAMILY (arch: $PKG_ARCH)"

SKIP_PROMPTS=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) SKIP_PROMPTS=true ;;
  esac
done

if [ "$SKIP_PROMPTS" = "true" ]; then
  API_KEY="${API_KEY:-}"
  LOCATION="${LOCATION:-}"
  if [ -z "$API_KEY" ]; then
    echo "--yes was passed but API_KEY isn't set in the environment — aborting." >&2
    exit 1
  fi
else
  # -e /dev/tty only checks the device node exists, not that this process actually has a
  # controlling terminal to open it against (a fully non-interactive context still passes -e but
  # fails at the actual read below) — `( : < /dev/tty ) 2>/dev/null` genuinely attempts the open,
  # and cleanly suppresses the shell's own redirection-failure diagnostic too.
  if ! ( : < /dev/tty ) 2>/dev/null; then
    echo "No terminal available to prompt for input, and --yes wasn't passed. Re-run with --yes and API_KEY/LOCATION set in the environment for a non-interactive install." >&2
    exit 1
  fi
  # Read from /dev/tty explicitly — this script is normally run via `curl | bash`, which makes
  # stdin the piped script itself, not the terminal.
  echo "Get your API key from LastPass first (the \"Quartermaster API Key\" secure note) — ask Clive if you don't have access."
  read -r -s -p "Enter your API key: " API_KEY < /dev/tty
  echo
  if [ -z "$API_KEY" ]; then
    echo "No API key entered — aborting. Re-run this script when you have it." >&2
    exit 1
  fi
  read -r -p "Enter your location (e.g. \"London Office - Floor 3\", or leave blank for \"Unknown\"): " LOCATION < /dev/tty
fi

echo
echo "Downloading the latest Quartermaster Agent ($FAMILY, $PKG_ARCH)..."
PKG_FILE="quartermaster-agent_${PKG_ARCH}.${FAMILY}"
curl -fsSL -o "$WORKDIR/$PKG_FILE" "$BASE/$PKG_FILE"

echo "Verifying checksum..."
curl -fsSL -o "$WORKDIR/checksums.txt" "$BASE/checksums.txt"
EXPECTED="$(grep " ${PKG_FILE}\$" "$WORKDIR/checksums.txt" | awk '{print $1}')"
ACTUAL="$(sha256sum "$WORKDIR/$PKG_FILE" | awk '{print $1}')"
if [ -z "$EXPECTED" ] || [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "Checksum verification failed — refusing to install an unverified package." >&2
  echo "expected: ${EXPECTED:-<not found in checksums.txt>}" >&2
  echo "actual:   $ACTUAL" >&2
  exit 1
fi
echo "Checksum OK."

echo "Installing (you'll be asked for your sudo password)..."
if [ "$FAMILY" = "rpm" ]; then
  sudo rpm -Uvh "$WORKDIR/$PKG_FILE"
else
  sudo dpkg -i "$WORKDIR/$PKG_FILE"
fi

echo "Setting your API key..."
sudo quartermaster-agent --set-api-key "$API_KEY"

if [ -n "$LOCATION" ]; then
  echo "Setting your location..."
  sudo quartermaster-agent --set-location "$LOCATION"
fi

echo "Triggering a first run to confirm everything's working..."
sudo quartermaster-agent-run-now

echo
echo "Result of the first run:"
cat /var/lib/quartermaster-agent/last_run_status.json 2>/dev/null \
  || echo "(status file not found yet — give it a few seconds, then check /var/lib/quartermaster-agent/last_run_status.json)"
echo
echo "Done. If the result above shows \"success\": false, see the Troubleshooting section of INSTALLATION.md in the quartermaster-agent repo."
