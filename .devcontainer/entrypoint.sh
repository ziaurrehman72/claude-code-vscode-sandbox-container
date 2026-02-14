#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh – Container entrypoint with security initialization
# =============================================================================
# Runs as root before the actual container process starts.
# Activates the egress firewall and then hands off to the normal process.
# =============================================================================

set -euo pipefail

# Activate egress firewall (requires root + NET_ADMIN)
if [ -x /usr/local/bin/egress-firewall.sh ]; then
    /usr/local/bin/egress-firewall.sh || echo "⚠️  Egress firewall could not be activated (requires NET_ADMIN capability)"
fi

# Hand off to the original command
exec "$@"
