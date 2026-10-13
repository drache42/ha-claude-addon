# Changelog

## 0.2.4

- Show a friendly machine name in Remote Control instead of the container hostname
  (`<hash>-claude-code`). New optional `hostname` setting, default `home-assistant`.

## 0.2.3

- Fix Remote Control exiting immediately on first run: it needs a real terminal on
  stdout to ask its one-time confirmation and trust prompts, but output was redirected
  to a file. The session now runs on the tmux terminal and tmux copies the output to
  `/data/remote-control.log`.
- Report "waiting for a one-time confirmation" (with the `tmux attach` hint) instead
  of looking healthy while sitting at a prompt.
- Print the tail of the Remote Control log in the add-on log when the session fails.

## 0.2.2

- Turn tmux mouse capture off in the web terminal. It blocked right-click and paste,
  so the login code from `claude auth login` could not be pasted.

## 0.2.1

- Enable the sidebar panel automatically on first start (HA leaves "Show in sidebar"
  off by default, which hid the login terminal).

## 0.2.0

- Use prebuilt multi-arch images from ghcr.io/drache42/ha-claude-code instead of
  building on the Home Assistant host.
- Node-RED MCP, Zabbix server and Zabbix host are now optional settings with empty
  defaults.
- Add icon, logo, option translations, and CI (add-on linter, shellcheck, build).
- Drop config keys that only repeated defaults.

## 0.1.0

- Initial version: Claude Code with Remote Control, admin Supervisor and Core
  API access, ha-mcp MCP wiring, ingress web terminal for login.
