# quartermaster-agent-releases

Signed, notarized release artifacts for [quartermaster-agent](https://github.com/clivewalkden/quartermaster-agent)
(private — this repo carries no source code, only compiled binaries/installers and a
`latest.json` manifest for the upgrade script).

- **macOS**: `quartermaster-agent.pkg` — signed with SOZO Design's Developer ID, notarized, stapled.
- **Windows**: `quartermaster-agent-setup.exe`
- **Linux**: `quartermaster-agent_amd64.deb` / `quartermaster-agent_arm64.deb`

All available at [Releases](../../releases) or via the stable
`releases/latest/download/<filename>` URLs listed in [`latest.json`](latest.json).

See `RELEASING.md` in the source repo for how this gets published.
