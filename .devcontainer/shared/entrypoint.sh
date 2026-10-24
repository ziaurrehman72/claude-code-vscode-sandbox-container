#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh – Container entrypoint with security initialization
# =============================================================================
# Runs as root before the actual container process starts.
# Activates the Squid-based egress firewall and then hands off to the
# normal process.
# =============================================================================

set -euo pipefail

# ── Fix tmpfs ownership ──────────────────────────────────────────────────────
# The --read-only flag with --tmpfs mounts creates tmpfs directories owned by
# root. The vscode user needs write access to their home directory for VS Code
# Server, shell config, pipx, etc.
chown vscode:vscode /home/vscode

# Claude Code config volume (claude/both variants) is created root-owned.
if [ -d /home/vscode/.claude ]; then
    chown vscode:vscode /home/vscode/.claude
fi

# ── Create TMPDIR for vscode user ────────────────────────────────────────────
# /tmp is mounted noexec to prevent AI agents from downloading and executing
# arbitrary binaries. Build tools (pip, node-gyp) that need exec use TMPDIR
# which points to /home/vscode/.tmp (on the /home/vscode tmpfs with exec).
mkdir -p /home/vscode/.tmp
chmod 1700 /home/vscode/.tmp
chown vscode:vscode /home/vscode/.tmp

# ── Create VS Code marker files ──────────────────────────────────────────────
# With --read-only, VS Code cannot patch /etc/environment or /etc/profile.
# These marker files tell VS Code the patching is already done (the correct
# content is pre-populated in the Dockerfile). Without these markers, VS Code
# tries to write to /etc/environment and fails on the read-only filesystem.
mkdir -p /var/devcontainer
touch /var/devcontainer/.patchEtcEnvironmentMarker
touch /var/devcontainer/.patchEtcProfileMarker

# Activate egress firewall (Squid proxy + iptables enforcement)
# SECURITY: Fail-closed — if the firewall cannot be activated, the container
# must NOT start. This prevents running without egress filtering.
/usr/local/bin/egress-firewall.sh || {
    echo "❌ FATAL: Egress firewall could not be activated!"
    echo "   The container will NOT start without egress filtering."
    echo "   Ensure NET_ADMIN capability is available and AI_PROFILE is valid."
    exit 1
}

# Hand off to the original command
exec "$@"
