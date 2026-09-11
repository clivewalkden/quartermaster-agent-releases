# quartermaster-agent-releases

Signed, notarized release artifacts for [quartermaster-agent](https://github.com/clivewalkden/quartermaster-agent)
(private — this repo carries no source code, only compiled binaries/installers and a
`latest.json` manifest for the upgrade script).

## Installing

**macOS:**

```sh
curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/install-mac.sh | bash
```

**Linux** (Fedora/RHEL/CentOS/Rocky/AlmaLinux via `.rpm`, Debian/Ubuntu via `.deb` — detected
automatically):

```sh
curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/install-linux.sh | bash
```

Both ask for your API key and location interactively, then install, configure, and trigger a
first run. See `INSTALLATION.md` in the source repo for the full walkthrough, non-interactive/
scripted variants, and troubleshooting.

**Windows**: not yet ready for self-install — see the source repo's `TODO.md`.

## Uninstalling

```sh
curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/uninstall-mac.sh | bash     # macOS
curl -fsSL https://raw.githubusercontent.com/clivewalkden/quartermaster-agent-releases/main/uninstall-linux.sh | bash   # Linux
```

## Assets

- **macOS**: `quartermaster-agent.pkg` — signed with SOZO Design's Developer ID, notarized, stapled.
- **Windows**: `quartermaster-agent-setup.exe`
- **Linux**: `quartermaster-agent_amd64.deb` / `_arm64.deb` (Debian/Ubuntu), `_amd64.rpm` / `_arm64.rpm` (Fedora/RHEL family)

All available at [Releases](../../releases) or via the stable
`releases/latest/download/<filename>` URLs listed in [`latest.json`](latest.json).

See `RELEASING.md` in the source repo for how this gets published.
