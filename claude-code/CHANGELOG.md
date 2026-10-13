# Changelog

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
