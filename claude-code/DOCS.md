# Claude Code

Runs the Claude Code CLI inside Home Assistant with full admin access, and keeps a
`claude remote-control` server alive so you can drive it from claude.ai/code or the
Claude mobile app.

## First-time setup

1. Install and start the add-on. It shows "Not signed in" in its log until you log in.
2. Open **Claude Code** in the sidebar (admin users only). This is a web terminal.
3. Run `claude auth login`, open the URL, sign in, and paste the code it gives you back
   into the terminal (Ctrl+Shift+V, or right-click > Paste; Shift+Insert also works).
   Remote Control needs a full-scope login. `claude setup-token`, API keys and
   `CLAUDE_CODE_OAUTH_TOKEN` do not work for it.
4. Within 30 seconds the add-on starts the Remote Control session by itself.
   If the one-time "Enable Remote Control? (y/n)" prompt is waiting, answer it with
   `tmux attach -t remote-control` in the terminal (detach with Ctrl-b d).
5. Open claude.ai/code or the Claude app and pick the "Home Assistant" session.

When the login expires, repeat steps 2 and 3. A persistent notification appears in
HA after the session has been down for 10 minutes.

## What Claude can reach

- `/homeassistant_config`: the live Home Assistant config (read-write). Claude
  starts here, so the config repo's `CLAUDE.md` and `.claude/` are picked up.
- `/ssl`, `/share`, `/media`, `/backup`, `/local_apps`, `/all_app_configs`: read-write.
- MCP server `ha-mcp`, wired at every start when the ha-mcp add-on
  (homeassistant-ai/ha-mcp) is installed. Its secret URL is read from the Supervisor
  at runtime and never stored by this add-on. `node-red` is wired when you set
  `node_red_mcp_url`.
- `ha-api METHOD PATH [JSON]` (Core API) and `ha-supervisor METHOD PATH [JSON]`
  (Supervisor API, admin role) using the add-on token.

The add-on does not use `full_access` or host networking. It cannot touch host
hardware or the host shell.

## Options

| Option | Default | Meaning |
|---|---|---|
| `permission_mode` | `default` | Starting permission mode for Remote Control sessions: `default`, `acceptEdits` or `plan`. |
| `node_red_mcp_url` | empty | Optional Node-RED MCP endpoint (for example `http://172.30.32.1:8001/mcp`). Empty skips it. |
| `zabbix_server` | empty | Optional Zabbix server (port 10051) for the health item. Empty disables it. |
| `zabbix_host` | empty | Zabbix host owning the trapper item `remotecontrol.watchdog_failure` (1 = down, 0 = up). |

## Security notes

- The sidebar panel is a root shell with an admin Supervisor token. It is limited to HA
  admin users, and nginx only accepts connections from the Supervisor ingress proxy.
- Anyone signed in to your claude.ai account can reach this server through Remote
  Control, from anywhere. That access is as powerful as the admin token above.
- Your Claude login lives in `/data/home/.claude`. HA backups exclude
  `.credentials.json`.
