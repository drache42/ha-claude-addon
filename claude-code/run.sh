#!/usr/bin/env bash
# Entrypoint for the Claude Code add-on.
#
#   1. Prepare HOME on the persistent /data volume.
#   2. Wire MCP servers (ha-mcp discovered at runtime, node-red) into
#      ~/.claude.json and pre-trust the working directory.
#   3. Start the ingress web terminal (ttyd behind nginx) for login / re-login.
#   4. Supervise `claude remote-control` in a detached tmux session, restart it
#      when it dies, and report state to Zabbix and to HA (persistent
#      notification).
#
# No secret is ever stored by this add-on: the ha-mcp secret path is read from
# the Supervisor at every start, and the Claude login lives in /data/home.
set -u

export HOME=/data/home
export LANG=C.UTF-8 LC_ALL=C.UTF-8 TERM=xterm-256color
WORKDIR=/homeassistant_config
OPTIONS=/data/options.json
LOG=/data/remote-control.log
SUP=http://supervisor
SESSION=remote-control
LOG_MAX_BYTES=5242880
LOOP_SECONDS=30
REPORT_SECONDS=300
NOTIFY_AFTER_SECONDS=600
BACKOFF_STEP_SECONDS=60
BACKOFF_MAX_SECONDS=600
# The hassio network gateway is the HAOS host; ha-mcp and Node-RED publish
# their MCP ports on it.
HOST_IP=172.30.32.1

log() { echo "[$(date -Is)] $*"; }
opt() { jq -r --arg k "$1" '.[$k] // empty' "$OPTIONS" 2>/dev/null; }
sup() { curl -fsS -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" "$@"; }

mkdir -p "$HOME/.claude"

# ---------------------------------------------------------------- MCP wiring

# Prints the full ha-mcp URL (including its secret path) or returns 1. The
# value is never logged.
discover_ha_mcp_url() {
    local slug path
    slug=$(sup "$SUP/addons" 2>/dev/null \
        | jq -r '.data.addons[] | select(.slug | endswith("_ha_mcp")) | .slug' | head -n1)
    [ -n "$slug" ] || return 1
    path=$(sup "$SUP/addons/$slug/info" 2>/dev/null | jq -r '.data.options.secret_path // empty')
    if [ -z "$path" ]; then
        # No explicit secret_path option: ha-mcp generates one and prints it.
        path=$(sup "$SUP/addons/$slug/logs" 2>/dev/null \
            | grep -o '/private_[A-Za-z0-9_-]*' | tail -n1)
    fi
    [ -n "$path" ] || return 1
    case "$path" in /*) ;; *) path="/$path" ;; esac
    echo "http://${HOST_IP}:9583${path}"
}

configure_mcp() {
    local cfg="$HOME/.claude.json" url mcp tmp nodered
    [ -s "$cfg" ] || echo '{}' > "$cfg"
    mcp='{}'
    # Optional: only wired when the user supplies a Node-RED MCP endpoint.
    nodered=$(opt node_red_mcp_url)
    if [ -n "$nodered" ]; then
        mcp=$(jq -n --arg u "$nodered" '{"node-red":{"type":"http","url":$u}}')
    fi
    if url=$(discover_ha_mcp_url); then
        mcp=$(jq -n --argjson m "$mcp" --arg u "$url" '$m + {"ha-mcp":{"type":"http","url":$u}}')
        log "ha-mcp endpoint discovered"
    else
        log "WARNING: could not discover the ha-mcp endpoint; ha-mcp left as previously configured"
    fi
    tmp=$(mktemp)
    if jq --argjson mcp "$mcp" --arg dir "$WORKDIR" '
            .hasCompletedOnboarding = true
            | .mcpServers = ((.mcpServers // {}) + $mcp)
            | .projects[$dir].hasTrustDialogAccepted = true' "$cfg" > "$tmp"; then
        mv "$tmp" "$cfg"
        chmod 600 "$cfg"
    else
        rm -f "$tmp"
        log "WARNING: failed to update $cfg"
    fi
}

write_briefing() {
    cat > "$HOME/.claude/ha-addon-environment.md" <<'EOF'
# Home Assistant add-on environment

You are running inside the "Claude Code" Home Assistant add-on on Home Assistant OS.

- Working directory: /homeassistant_config is the LIVE Home Assistant config
  (the same files as /config on the host). Edits take effect on the running
  system; there is no staging copy.
- Also writable: /ssl, /share, /media, /backup, /local_apps, /all_app_configs.
- Admin access, two ways:
  - MCP servers `ha-mcp` and `node-red` (preferred for HA-aware operations).
  - Direct REST as admin: `ha-api METHOD PATH [JSON]` (Core API) and
    `ha-supervisor METHOD PATH [JSON]` (Supervisor API: add-ons, backups,
    host, OS, network). Both use the add-on token in $SUPERVISOR_TOKEN.
    Never print or log that token.
- Before risky changes, take a backup:
  `ha-supervisor POST /backups/new/partial '{"name":"before-change","homeassistant":true}'`.
- Validate before reloading or restarting:
  `ha-api POST /config/core/check_config`.
- This container is Debian with node, git, jq, curl, ripgrep and tmux. It has no
  `ha` CLI; use the helpers above.
- /data is the add-on's persistent volume (HOME is /data/home). HA backups
  include it, except the OAuth credentials file.
EOF
    # Only seed CLAUDE.md once so user edits to it are never overwritten.
    if [ ! -f "$HOME/.claude/CLAUDE.md" ]; then
        printf '@ha-addon-environment.md\n' > "$HOME/.claude/CLAUDE.md"
    fi
}

# ------------------------------------------------------------------- helpers

zbx_send() {
    local server host
    server=$(opt zabbix_server)
    host=$(opt zabbix_host)
    [ -n "$server" ] && [ -n "$host" ] || return 0
    python3 - "$server" 10051 "$host" remotecontrol.watchdog_failure "$1" <<'PY' 2>>"$LOG"
import socket, struct, sys, json
server, port, host, key, val = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
payload = json.dumps({"request": "sender data",
                      "data": [{"host": host, "key": key, "value": val}]}).encode()
pkt = b"ZBXD\x01" + struct.pack("<q", len(payload)) + payload
try:
    s = socket.create_connection((server, port), timeout=5)
    s.sendall(pkt); s.recv(1024); s.close()
except Exception as e:
    sys.stderr.write("zbx_send failed (%s): %s\n" % (key, e))
PY
}

ha_service() { # domain service json
    curl -fsS -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" -d "$3" \
        "$SUP/core/api/services/$1/$2" > /dev/null 2>&1
}

notify_down() {
    ha_service persistent_notification create "$(jq -n --arg m "$1" \
        '{notification_id:"claude_code_addon",title:"Claude Code add-on is down",message:$m}')"
}
notify_clear() {
    ha_service persistent_notification dismiss '{"notification_id":"claude_code_addon"}'
}

logged_in() {
    claude auth status 2>/dev/null | jq -e '.loggedIn == true' > /dev/null 2>&1
}

rc_alive() { tmux has-session -t "$SESSION" 2>/dev/null; }

start_rc() {
    local mode
    mode=$(opt permission_mode)
    [ -n "$mode" ] || mode=default
    tmux new-session -d -s "$SESSION" -c "$WORKDIR" \
        "claude remote-control --name 'Home Assistant' --permission-mode '$mode' >> '$LOG' 2>&1"
}

rotate_log() {
    local size
    size=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
    if [ "$size" -gt "$LOG_MAX_BYTES" ]; then
        tail -c 1048576 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
}

start_ui() {
    pgrep -x nginx > /dev/null || { nginx -c /etc/nginx/claude-ingress.conf & }
    pgrep -x ttyd > /dev/null || {
        ttyd -i 127.0.0.1 -p 7681 -W -t fontSize=15 -t disableLeaveAlert=true \
            tmux new-session -A -s shell -c "$WORKDIR" &
    }
}

# ---------------------------------------------------------------------- main

log "starting Claude Code add-on"
configure_mcp
write_briefing
touch "$LOG"

state=""            # up | down
down_since=0
notified=0
fail_count=0
next_start_allowed=0
last_report=0

while true; do
    now=$(date +%s)
    start_ui
    rotate_log
    reason=""

    if ! logged_in; then
        reason="Not signed in. Open the Claude Code panel in the HA sidebar and run: claude auth login"
    elif rc_alive; then
        fail_count=0
    elif [ "$now" -lt "$next_start_allowed" ]; then
        reason="Remote Control session is down (restart backoff active). See /data/remote-control.log"
    else
        log "starting remote-control session"
        if start_rc; then
            sleep 20
        fi
        if rc_alive; then
            fail_count=0
        else
            fail_count=$((fail_count + 1))
            backoff=$((fail_count * BACKOFF_STEP_SECONDS))
            [ "$backoff" -gt "$BACKOFF_MAX_SECONDS" ] && backoff=$BACKOFF_MAX_SECONDS
            next_start_allowed=$(( $(date +%s) + backoff ))
            reason="Remote Control session exited right after start. See /data/remote-control.log"
            log "WARNING: $reason (retry in ${backoff}s)"
        fi
    fi

    if [ -z "$reason" ]; then
        new_state=up
    else
        new_state=down
    fi

    if [ "$new_state" != "$state" ]; then
        log "state: ${state:-init} -> $new_state${reason:+ ($reason)}"
        if [ "$new_state" = down ]; then
            down_since=$now
        else
            down_since=0
            if [ "$notified" -eq 1 ]; then
                notify_clear
                notified=0
            fi
        fi
        state=$new_state
        last_report=0
    fi

    if [ "$state" = down ] && [ "$notified" -eq 0 ] \
            && [ $((now - down_since)) -ge "$NOTIFY_AFTER_SECONDS" ]; then
        notify_down "$reason"
        notified=1
    fi

    if [ $((now - last_report)) -ge "$REPORT_SECONDS" ]; then
        if [ "$state" = up ]; then zbx_send 0; else zbx_send 1; fi
        last_report=$now
    fi

    sleep "$LOOP_SECONDS"
done
