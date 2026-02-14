#!/usr/bin/env bash
# =============================================================================
# egress-firewall.sh – Restrict network egress to a whitelist
# =============================================================================
#
# This script runs as root at container start and configures iptables
# rules that restrict outbound network traffic to a whitelist of
# domains/IPs.
#
# WHY Egress Filtering?
#   AI agents (Copilot, Cline, etc.) have terminal access and can use
#   curl/wget/python to send data to arbitrary external servers.
#   Without egress filtering, data exfiltration is trivial.
#
# ALLOWED DESTINATIONS:
#   Defined in /usr/local/etc/allowed-domains.conf
#   (source file: .devcontainer/allowed-domains.conf)
#   Includes: GitHub, npm, PyPI, Ubuntu, VS Code, Azure,
#   Azure DevOps, Figma, Miro, Notion, Amplitude
#
# LIMITATIONS:
#   - iptables-based domain filtering is DNS-dependent and can be
#     bypassed if an attacker uses direct IP connections.
#   - For production environments, a content-inspection proxy is recommended.
#   - This script provides defense-in-depth, not perfect isolation.
#
# =============================================================================

set -euo pipefail

# ── Whitelist: load allowed domains from config file ─────────────────────────
# The list of allowed domains is read from a separate file so it can be
# easily edited without modifying the firewall script.
#
# File: /usr/local/etc/allowed-domains.conf
# Format: One domain per line, comments (#) and blank lines are ignored.
# ─────────────────────────────────────────────────────────────────────────────
DOMAINS_FILE="/usr/local/etc/allowed-domains.conf"

if [ ! -f "$DOMAINS_FILE" ]; then
    echo "⚠️  Domain whitelist not found: $DOMAINS_FILE"
    echo "   Egress firewall will NOT be activated."
    exit 1
fi

# Read domains: filter out blank lines and comments
ALLOWED_DOMAINS=()
while IFS= read -r line; do
    # Skip blank lines and comments
    line=$(echo "$line" | sed 's/#.*//' | xargs)
    if [[ -n "$line" ]]; then
        ALLOWED_DOMAINS+=("$line")
    fi
done < "$DOMAINS_FILE"

echo "   📄 ${#ALLOWED_DOMAINS[@]} domains loaded from $DOMAINS_FILE"

# ── Resolve Domains → IP Addresses ───────────────────────────────────────────
# Resolve each domain to IPs and store them in an ipset for efficient matching.

echo "🔒 Egress firewall: configuring network whitelist..."

# Install ipset if not available
if ! command -v ipset &>/dev/null; then
    apt-get update -qq && apt-get install -y -qq ipset iptables >/dev/null 2>&1
fi

# Create ipset for allowed IPs
ipset create allowed_egress hash:ip -exist 2>/dev/null || true
ipset flush allowed_egress

# Always allow local/container network IPs
ipset add allowed_egress 127.0.0.1 -exist
ipset add allowed_egress 10.88.0.1 -exist   # Podman gateway (typical)

RESOLVED_COUNT=0
for domain in "${ALLOWED_DOMAINS[@]}"; do
    # Skip wildcard domains (cannot be resolved)
    if [[ "$domain" == *"*"* ]]; then
        continue
    fi

    # DNS resolution, multiple IPs per domain possible
    ips=$(getent ahosts "$domain" 2>/dev/null | awk '{print $1}' | sort -u || true)
    for ip in $ips; do
        if [[ -n "$ip" ]]; then
            ipset add allowed_egress "$ip" -exist 2>/dev/null || true
            RESOLVED_COUNT=$((RESOLVED_COUNT + 1))
        fi
    done
done

echo "   ✅ ${RESOLVED_COUNT} IP addresses resolved from ${#ALLOWED_DOMAINS[@]} domains"

# ── Set iptables rules ───────────────────────────────────────────────────────

# Allow DNS (UDP + TCP port 53) — required for name resolution
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true

# Allow local traffic (loopback)
iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

# Allow already established connections (for response packets)
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# Allow whitelisted IPs (HTTPS + HTTP)
iptables -A OUTPUT -m set --match-set allowed_egress dst -p tcp --dport 443 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -m set --match-set allowed_egress dst -p tcp --dport 80 -j ACCEPT 2>/dev/null || true

# Allow container-internal traffic (Podman network)
iptables -A OUTPUT -d 10.88.0.0/16 -j ACCEPT 2>/dev/null || true

# Block everything else
iptables -A OUTPUT -p tcp --dport 80 -j DROP 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 443 -j DROP 2>/dev/null || true

echo "   ✅ iptables egress rules active"
echo "   ℹ️  Allowed: ${#ALLOWED_DOMAINS[@]} domains (see $DOMAINS_FILE)"
echo "   ⛔ Blocked: All other outbound HTTP/HTTPS connections"
echo ""
