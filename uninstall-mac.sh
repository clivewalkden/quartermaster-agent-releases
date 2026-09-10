#!/usr/bin/env bash
# Quartermaster Agent uninstaller for macOS.
#
# Usage (published to the public releases repo — see release.yml, same as install-mac.sh):
#   curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/uninstall-mac.sh | bash
#
# Non-interactive (e.g. MDM-pushed removal): pass --yes to skip the confirmation prompt.
#   curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/uninstall-mac.sh | bash -s -- --yes
#
# Stops and removes everything install-mac.sh / the .pkg's postinstall set up: the scheduled
# job, the binary and helper scripts, the env file (including your API key), and local state.
# Does NOT delete the device record from the backend — this only removes the local agent; the
# machine will just stop reporting and eventually show as stale in quartermaster-android.
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This uninstaller is for macOS only." >&2
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
echo "This will remove Quartermaster Agent from this machine:"
echo "  - stop and unload the scheduled background job"
echo "  - /usr/local/bin/quartermaster-agent and its helper scripts"
echo "  - /Library/LaunchDaemons/com.sozodesign.quartermaster-agent.plist"
echo "  - /etc/quartermaster-agent (the env file, including your API key)"
echo "  - /var/db/quartermaster-agent (local state)"
echo "  - /var/log/quartermaster-agent.{out,err}"
echo
echo "The device record on the backend is NOT deleted by this — it just stops reporting."
echo

if [ "$SKIP_CONFIRM" != "true" ]; then
  # -e /dev/tty only checks the device node exists, not that this process actually has a
  # controlling terminal to open it against (see install-mac.sh's identical comment) —
  # `: < /dev/tty` genuinely attempts the open, so it catches a fully non-interactive context too.
  if ! ( : < /dev/tty ) 2>/dev/null; then
    echo "No terminal available to confirm, and --yes wasn't passed — refusing to guess. Re-run with --yes for a non-interactive removal." >&2
    exit 1
  fi
  # Read from /dev/tty explicitly — see install-mac.sh's identical comment: this script is
  # normally run via `curl | bash`, which makes stdin the piped script itself, not the terminal.
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
echo "Stopping and unloading the scheduled job (you'll be asked for your Mac login password)..."
sudo launchctl bootout system/com.sozodesign.quartermaster-agent 2>/dev/null || true

echo "Removing files..."
sudo rm -f /Library/LaunchDaemons/com.sozodesign.quartermaster-agent.plist
sudo rm -f /usr/local/bin/quartermaster-agent
sudo rm -f /usr/local/bin/quartermaster-agent-run.sh
sudo rm -f /usr/local/bin/quartermaster-agent-run-now
sudo rm -rf /etc/quartermaster-agent
sudo rm -rf /var/db/quartermaster-agent
sudo rm -f /var/log/quartermaster-agent.out /var/log/quartermaster-agent.err

echo
echo "Done. Quartermaster Agent has been removed from this machine."
