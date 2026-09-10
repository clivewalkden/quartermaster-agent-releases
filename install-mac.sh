#!/usr/bin/env bash
# Quartermaster Agent installer for macOS.
#
# Usage (published to the public releases repo — see release.yml):
#   curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/install-mac.sh | bash
#
# Downloads the latest signed/notarized .pkg, verifies its checksum, installs it, and prompts
# for your API key and location so a single command does the whole setup. See INSTALLATION.md in
# the quartermaster-agent source repo for the manual step-by-step equivalent, Linux/Windows, and
# troubleshooting.
set -euo pipefail

REPO="clivewalkden/quartermaster-agent-releases"
BASE="https://github.com/${REPO}/releases/latest/download"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "Quartermaster Agent installer"
echo "=============================="
echo

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer is for macOS only. See INSTALLATION.md in the quartermaster-agent repo for Linux/Windows." >&2
  exit 1
fi

if [ ! -e /dev/tty ]; then
  echo "No terminal available to prompt for input — run this in an interactive Terminal session, not from a non-interactive script/CI." >&2
  exit 1
fi

# This script is normally run via `curl ... | bash`, which makes stdin the piped script itself,
# not the terminal — reading explicitly from /dev/tty is what makes these prompts actually work
# rather than silently reading nothing (or leftover script bytes).
echo "Get your API key from LastPass first (the \"Quartermaster API Key\" secure note) — ask Clive if you don't have access."
read -r -s -p "Enter your API key: " API_KEY < /dev/tty
echo
if [ -z "$API_KEY" ]; then
  echo "No API key entered — aborting. Re-run this script when you have it." >&2
  exit 1
fi

read -r -p "Enter your location (e.g. \"London Office - Floor 3\", or leave blank for \"Unknown\"): " LOCATION < /dev/tty

echo
echo "Downloading the latest Quartermaster Agent..."
curl -fsSL -o "$WORKDIR/quartermaster-agent.pkg" "$BASE/quartermaster-agent.pkg"

echo "Verifying checksum..."
curl -fsSL -o "$WORKDIR/checksums.txt" "$BASE/checksums.txt"
EXPECTED="$(grep ' quartermaster-agent\.pkg$' "$WORKDIR/checksums.txt" | awk '{print $1}')"
ACTUAL="$(shasum -a 256 "$WORKDIR/quartermaster-agent.pkg" | awk '{print $1}')"
if [ -z "$EXPECTED" ] || [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "Checksum verification failed — refusing to install an unverified package." >&2
  echo "expected: ${EXPECTED:-<not found in checksums.txt>}" >&2
  echo "actual:   $ACTUAL" >&2
  exit 1
fi
echo "Checksum OK."

echo "Installing (you'll be asked for your Mac login password — that's sudo, nothing to do with the API key)..."
sudo installer -pkg "$WORKDIR/quartermaster-agent.pkg" -target /

echo "Setting your API key..."
sudo quartermaster-agent --set-api-key "$API_KEY"

if [ -n "$LOCATION" ]; then
  echo "Setting your location..."
  sudo quartermaster-agent --set-location "$LOCATION"
fi

echo "Triggering a first run to confirm everything's working..."
sudo launchctl kickstart -k system/com.sozodesign.quartermaster-agent
sleep 3

echo
echo "Result of the first run:"
cat /var/db/quartermaster-agent/last_run_status.json 2>/dev/null \
  || echo "(status file not found yet — give it a few seconds, then check /var/db/quartermaster-agent/last_run_status.json)"
echo
echo "Done. If the result above shows \"success\": false, see the Troubleshooting section of INSTALLATION.md in the quartermaster-agent repo."
