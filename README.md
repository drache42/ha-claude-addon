# Claude Code for Home Assistant

A Home Assistant add-on that runs the [Claude Code](https://code.claude.com) CLI inside
Home Assistant OS with admin access to Home Assistant, and keeps a
[Remote Control](https://code.claude.com/docs/en/remote-control) server running so you
can drive it from [claude.ai/code](https://claude.ai/code) or the Claude mobile app
without leaving a computer on.

[![Add repository to Home Assistant](https://my.home-assistant.io/badges/supervisor_add_addon_repository.svg)](https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fdrache42%2Fha-claude-addon)

## Read this first

This add-on hands an AI agent **admin control of your Home Assistant**.

- It runs with the Supervisor `admin` role and the Core API proxy. Claude can change
  automations, restart or reconfigure add-ons, take and restore backups, and edit your
  live config files (`/homeassistant_config` is mounted read-write).
- The sidebar panel is a root shell inside the add-on, limited to HA admin users.
- Anyone signed in to the claude.ai account you log in with can reach the Remote Control
  session from anywhere. Treat that account as having admin access to your house.
- It does **not** use `full_access` or host networking, so it cannot touch host hardware
  or the host shell.
- You need a Claude Pro, Max, Team or Enterprise subscription. API keys and
  `claude setup-token` tokens cannot start Remote Control; you sign in once with
  `claude auth login` from the add-on's web terminal. Nothing from this repository
  is signed in on your behalf.

Take a Home Assistant backup before first use, and keep Claude's permission mode on
`default` until you trust it.

## Requirements

- Home Assistant OS or Supervised (add-ons are not available on Container or Core).
- amd64 or aarch64.

## Install

1. Settings > Add-ons > Add-on Store > three-dot menu > Repositories.
2. Add `https://github.com/drache42/ha-claude-addon` (or use the button above).
3. Install **Claude Code**, start it, and follow its Documentation tab to sign in.

## What you get

- `claude remote-control` supervised in tmux: restarted if it dies, with restart backoff.
- MCP wiring for [ha-mcp](https://github.com/homeassistant-ai/ha-mcp) when that add-on is
  installed (its secret URL is read from the Supervisor at start, never stored), and
  optionally Node-RED.
- `ha-api` and `ha-supervisor` helpers for direct Core and Supervisor REST calls.
- A persistent notification in HA if Remote Control has been down for 10 minutes, and an
  optional Zabbix trapper item.
- Your login lives in `/data/home/.claude` and survives restarts and updates. HA backups
  exclude the credentials file.

## Updating

Pre-built multi-arch images are published to `ghcr.io/drache42/ha-claude-code`, tagged
with the add-on version. The Claude Code CLI also updates itself while running.

## Layout

```
repository.yaml
claude-code/
  config.yaml     add-on definition (permissions, mounts, ingress)
  Dockerfile      node + claude CLI + tmux + ttyd + nginx
  run.sh          entrypoint: MCP wiring, web terminal, Remote Control supervisor
  ha-api          Core API helper
  ha-supervisor   Supervisor API helper
  DOCS.md         shown on the add-on's Documentation tab
```

## Development

`docker build -t claude-code-addon-test claude-code` builds the image. Running it with a
fake `/data/options.json`, a temp `/homeassistant_config` and `SUPERVISOR_TOKEN=dummy`
exercises everything except the Supervisor calls; CI does exactly that. To ship a change,
bump `version` in `claude-code/config.yaml` and add a CHANGELOG entry; pushing to `main`
publishes the image.

## License

MIT. Not affiliated with or endorsed by Anthropic or Nabu Casa.
