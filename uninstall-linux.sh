#!/usr/bin/env bash
# Quartermaster Agent uninstaller for Linux (systemd).
#
# Usage (published to the public releases repo — see release.yml, same as install-linux.sh):
#   curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/uninstall-linux.sh | bash
#
# Non-interactive (e.g. scripted removal): pass --yes to skip the confirmation prompt.
#   curl -fsSL .../uninstall-linux.sh | bash -s -- --yes
#
# Removes the package via dpkg/rpm (whichever one it's actually installed under — this also
# stops and disables the systemd timer automatically via the package's preremove scriptlet, see
# .goreleaser.yml), then removes the env file (including your API key) and local state, which
# aren't package-owned files. Does NOT delete the device record from the backend — this only
# removes the local agent; the machine will just stop reporting.
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
  echo "This uninstaller is for Linux only." >&2
  exit 1
fi

FAMILY=""
if command -v dpkg >/dev/null 2>&1 && dpkg -s quartermaster-agent >/dev/null 2>&1; then
  FAMILY=deb
elif command -v rpm >/dev/null 2>&1 && rpm -q quartermaster-agent >/dev/null 2>&1; then
  FAMILY=rpm
else
  echo "quartermaster-agent doesn't appear to be installed via dpkg or rpm on this machine — nothing to do." >&2
  exit 1
fi

SKIP_CONFIRM=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) SKIP_CONFIRM=true ;;
  esac
done

echo "Quartermaster Agent uninstaller"
echo "================================"
echo
echo "This will remove Quartermaster Agent from this machine (detected: $FAMILY package):"
echo "  - stop and disable the scheduled systemd timer"
echo "  - the quartermaster-agent package itself (binary, helper scripts, systemd units)"
echo "  - /etc/quartermaster-agent (the env file, including your API key)"
echo "  - /var/lib/quartermaster-agent (local state)"
echo
echo "The device record on the backend is NOT deleted by this — it just stops reporting."
echo

if [ "$SKIP_CONFIRM" != "true" ]; then
  # -e /dev/tty only checks the device node exists, not that this process actually has a
  # controlling terminal to open it against (see install-linux.sh's identical comment) —
  # `( : < /dev/tty ) 2>/dev/null` genuinely attempts the open.
  if ! ( : < /dev/tty ) 2>/dev/null; then
    echo "No terminal available to confirm, and --yes wasn't passed — refusing to guess. Re-run with --yes for a non-interactive removal." >&2
    exit 1
  fi
  read -r -p "Continue? [y/N] " CONFIRM < /dev/tty
  case "$CONFIRM" in
    y|Y|yes|YES) ;;
    *)
      echo "Aborted — nothing was removed."
      exit 0
      ;;
  esac
fi

echo
echo "Removing the package (you'll be asked for your sudo password)..."
if [ "$FAMILY" = "rpm" ]; then
  sudo rpm -e quartermaster-agent
else
  sudo dpkg -r quartermaster-agent
fi

echo "Removing env file and local state..."
sudo rm -rf /etc/quartermaster-agent
sudo rm -rf /var/lib/quartermaster-agent

echo
echo "Done. Quartermaster Agent has been removed from this machine."
