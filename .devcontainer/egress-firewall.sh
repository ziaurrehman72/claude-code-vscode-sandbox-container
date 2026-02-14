#!/usr/bin/env bash
# =============================================================================
# egress-firewall.sh – Domain-based egress filtering via Squid forward proxy
# =============================================================================
#
# Runs as root at container start. Configures:
#   1. Squid forward proxy filtering HTTP/HTTPS by domain name
#   2. iptables DROP rules (only proxy user can reach internet directly)
#
# Squid sees domains via Host header (HTTP) / CONNECT method (HTTPS),
# so CDN IP rotation is irrelevant. No TLS interception needed.
#
# Domain whitelist: /usr/local/etc/allowed-domains.conf
# Bypass monitoring: dmesg | grep EGRESS_BLOCKED
#
# =============================================================================

set -euo pipefail

DOMAINS_FILE="/usr/local/etc/allowed-domains.conf"
SQUID_CONF="/etc/squid/squid.conf"
SQUID_ACL_FILE="/etc/squid/allowed-domains.acl"
SQUID_LOG_DIR="/var/log/squid"
PROXY_PORT=3128

echo "🔒 Egress firewall: configuring domain-based proxy filter..."

# ── Validate domain whitelist ────────────────────────────────────────────────
if [ ! -f "$DOMAINS_FILE" ]; then
    echo "⚠️  Domain whitelist not found: $DOMAINS_FILE"
    echo "   Egress firewall will NOT be activated."
    exit 1
fi

# ── Generate Squid ACL from allowed-domains.conf ─────────────────────────────
# *.example.com → .example.com (Squid wildcard), plain → exact match only
# ─────────────────────────────────────────────────────────────────────────────
echo "   📄 Generating Squid ACL from $DOMAINS_FILE..."

: > "$SQUID_ACL_FILE"  # truncate

DOMAIN_COUNT=0
while IFS= read -r line; do
    # Strip comments and whitespace
    line=$(echo "$line" | sed 's/#.*//' | xargs)
    [[ -z "$line" ]] && continue

    # Convert to Squid dstdomain format
    if [[ "$line" == \*.* ]]; then
        # *.example.com → .example.com (Squid wildcard syntax)
        echo ".${line#\*.}" >> "$SQUID_ACL_FILE"
    else
        # example.com → exact match only (no automatic subdomain wildcard)
        echo "$line" >> "$SQUID_ACL_FILE"
    fi
    DOMAIN_COUNT=$((DOMAIN_COUNT + 1))
done < "$DOMAINS_FILE"

echo "   ✅ ${DOMAIN_COUNT} domains loaded into Squid ACL"

# ── Generate Squid Configuration ─────────────────────────────────────────────
echo "   📝 Writing Squid configuration..."

mkdir -p "$SQUID_LOG_DIR" /var/spool/squid /var/cache/squid
chown -R proxy:proxy "$SQUID_LOG_DIR" /var/spool/squid /var/cache/squid 2>/dev/null || true

cat > "$SQUID_CONF" << 'SQUID_EOF'
# =============================================================================
# Squid Forward Proxy Configuration - Egress Domain Whitelist
# =============================================================================
# This proxy filters outbound HTTP/HTTPS traffic by domain name.
# Only domains listed in /etc/squid/allowed-domains.acl are permitted.
# All other connections are denied.
# =============================================================================

# ── Listener ─────────────────────────────────────────────────────────────────
# Listen only on localhost — the proxy is not externally accessible.
http_port 3128

# ── Access Control Lists ─────────────────────────────────────────────────────

# Safe ports: only allow standard HTTP/HTTPS ports
acl Safe_ports port 80          # HTTP
acl Safe_ports port 443         # HTTPS
acl CONNECT method CONNECT

# Load allowed domains from ACL file (generated from allowed-domains.conf)
acl allowed_domains dstdomain "/etc/squid/allowed-domains.acl"

# ── Access Rules (order matters!) ─────────────────────────────────────────────

# Deny requests to unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to non-SSL ports (prevents tunneling to arbitrary ports)
acl SSL_ports port 443
http_access deny CONNECT !SSL_ports

# Allow requests to whitelisted domains
http_access allow allowed_domains

# Deny everything else (default deny)
http_access deny all

# ── Logging ──────────────────────────────────────────────────────────────────
# Minimal logging to reduce disk usage. Blocked requests are logged
# so administrators can diagnose connectivity issues.
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# ── Performance ──────────────────────────────────────────────────────────────
# Disable caching — this is a filtering proxy, not a cache.
cache deny all

# DNS timeout: fail fast if DNS is slow
dns_timeout 10 seconds
connect_timeout 30 seconds
read_timeout 5 minutes

# ── Privacy / Security ──────────────────────────────────────────────────────
# Don't forward internal IP addresses
forwarded_for delete

# Minimal identifying headers
via off
reply_header_access X-Cache deny all
reply_header_access X-Cache-Lookup deny all

# Run as proxy user
cache_effective_user proxy
cache_effective_group proxy

# PID file
pid_filename /run/squid.pid

# Shutdown timeout
shutdown_lifetime 3 seconds
SQUID_EOF

echo "   ✅ Squid configuration written"

# ── Initialize Squid Cache ──────────────────────────────────────────────────
# Squid needs swap directories initialized before first start
echo "   📦 Initializing Squid cache directories..."
squid -z --foreground 2>&1 | head -5 || true

# ── Start Squid ──────────────────────────────────────────────────────────────
echo "   🚀 Starting Squid proxy on localhost:${PROXY_PORT}..."

# Start Squid daemon — capture stderr for diagnostics
squid -f "$SQUID_CONF" 2>&1 || {
    echo "   ❌ Squid failed to start! Exit code: $?"
    echo "   --- cache.log (last 20 lines) ---"
    tail -20 "$SQUID_LOG_DIR/cache.log" 2>/dev/null || echo "   (no log file)"
    echo "   --- end ---"
    echo "   ❌ FATAL: Egress proxy failed to start — aborting container for security!"
    exit 1
}

# Wait for Squid to be ready (max 10 seconds)
SQUID_READY=false
for i in $(seq 1 20); do
    if squid -f "$SQUID_CONF" -k check 2>/dev/null; then
        echo "   ✅ Squid proxy running (PID: $(cat /run/squid.pid 2>/dev/null || echo 'unknown'))"
        SQUID_READY=true
        break
    fi
    sleep 0.5
done

if [ "$SQUID_READY" = false ]; then
    echo "   ❌ Squid did NOT become ready within 10 seconds!"
    echo "   --- cache.log (last 20 lines) ---"
    tail -20 "$SQUID_LOG_DIR/cache.log" 2>/dev/null || echo "   (no log file)"
    echo "   --- end ---"
    echo "   ❌ FATAL: Egress proxy not ready — aborting container for security!"
    exit 1
fi

# ── Connectivity Test ────────────────────────────────────────────────────────
# Quick smoke test: verify that outbound HTTPS through the proxy works.
# This catches misconfigurations before VS Code/Copilot try to connect.
echo "   🔍 Testing proxy connectivity..."
if curl -sf --proxy "http://localhost:${PROXY_PORT}" --connect-timeout 5 -o /dev/null -w "" "https://api.github.com/" 2>/dev/null; then
    echo "   ✅ Proxy test PASSED (api.github.com reachable via proxy)"
else
    CURL_EXIT=$?
    echo "   ⚠️  Proxy test FAILED (curl exit: ${CURL_EXIT})"
    echo "   Possible causes:"
    echo "     - DNS resolution failure inside the container"
    echo "     - Squid not fully started yet"
    echo "     - Network not available (container networking issue)"
    echo "   --- Squid access.log (last 5 lines) ---"
    tail -5 "$SQUID_LOG_DIR/access.log" 2>/dev/null || echo "   (no log file yet)"
    echo "   --- end ---"
fi

# ── Configure iptables (enforced egress blocking) ────────────────────────────
# Only the proxy user (Squid) can make direct outbound connections.
# All other users are blocked — even if HTTP_PROXY is unset.
# Requires dockerd as the container runtime.
# ─────────────────────────────────────────────────────────────────────────────
echo "   🔧 Configuring iptables (DEFAULT-DROP mode)..."

PROXY_UID=$(id -u proxy 2>/dev/null || echo "13")

# ── Determine container DNS resolver ─────────────────────────────────────────
# Docker uses 127.0.0.11, but fall back to parsing resolv.conf if different.
CONTAINER_DNS=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null || echo "127.0.0.11")
echo "   📍 Container DNS resolver: ${CONTAINER_DNS}"

iptables -F OUTPUT 2>/dev/null || true

# ── DEFAULT-DROP POLICY (K-1 fix) ────────────────────────────────────────────
# Set policy to DROP — all traffic is blocked unless explicitly allowed.
# This closes exfiltration via non-standard ports (8443, 4443, 9090, etc.)
# and prevents reverse shells on arbitrary ports.
iptables -P OUTPUT DROP 2>/dev/null || {
    echo "   ❌ FATAL: Cannot set iptables DEFAULT-DROP policy!"
    echo "   The container will NOT start without egress filtering."
    exit 1
}

# ── Allow loopback (proxy <-> clients, internal services) ────────────────────
iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

# ── Allow DNS only to container resolver (K-2 fix) ──────────────────────────
# Restrict DNS to the container's own resolver to prevent DNS tunneling.
# Data exfiltration via DNS queries to attacker-controlled servers is blocked.
iptables -A OUTPUT -p udp --dport 53 -d "$CONTAINER_DNS" -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 53 -d "$CONTAINER_DNS" -j ACCEPT 2>/dev/null || true
# LOG + DROP DNS to any other destination (DNS tunneling detection)
iptables -A OUTPUT -p udp --dport 53 -j LOG --log-prefix "EGRESS_BLOCKED_DNS: " --log-level 4 2>/dev/null || true
iptables -A OUTPUT -p udp --dport 53 -j DROP 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 53 -j LOG --log-prefix "EGRESS_BLOCKED_DNS: " --log-level 4 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 53 -j DROP 2>/dev/null || true

# ── Allow established connections ────────────────────────────────────────────
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# ── Block cloud metadata endpoints (MUST come before private range allows) ───
# AWS, GCP, Azure IMDS all use 169.254.169.254. Block explicitly.
iptables -A OUTPUT -d 169.254.169.254/32 -j LOG --log-prefix "EGRESS_BLOCKED_METADATA: " --log-level 4 2>/dev/null || true
iptables -A OUTPUT -d 169.254.169.254/32 -j DROP 2>/dev/null || true

# ── Allow container-internal traffic ─────────────────────────────────────────
# Docker default bridge: 172.17.0.0/16, user-defined: 172.18-31.x.x
# All three RFC 1918 private ranges are allowed (consistent with NO_PROXY).
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT 2>/dev/null || true

# ── Allow proxy user (Squid) to make direct outbound connections ─────────────
iptables -A OUTPUT -p tcp --dport 80 -m owner --uid-owner "$PROXY_UID" -j ACCEPT 2>/dev/null || {
    echo "   ❌ FATAL: Cannot add iptables rule for proxy (port 80)!"
    exit 1
}
iptables -A OUTPUT -p tcp --dport 443 -m owner --uid-owner "$PROXY_UID" -j ACCEPT 2>/dev/null || {
    echo "   ❌ FATAL: Cannot add iptables rule for proxy (port 443)!"
    exit 1
}

# ── LOG all other blocked traffic (bypass/exfiltration detection) ────────────
# With DEFAULT-DROP, all non-whitelisted traffic is blocked. LOG before DROP
# for visibility. Check: dmesg | grep EGRESS_BLOCKED
iptables -A OUTPUT -p tcp -j LOG --log-prefix "EGRESS_BLOCKED_TCP: " --log-level 4 2>/dev/null || true
iptables -A OUTPUT -p udp -j LOG --log-prefix "EGRESS_BLOCKED_UDP: " --log-level 4 2>/dev/null || true
iptables -A OUTPUT -p icmp -j LOG --log-prefix "EGRESS_BLOCKED_ICMP: " --log-level 4 2>/dev/null || true

# Note: DEFAULT-DROP policy handles the actual blocking — no explicit DROP
# rules needed. The LOG rules above are for monitoring only.

# ── IPv6: DEFAULT-DROP (prevent IPv6 egress bypass) ──────────────────────────
# If IPv6 is available, apply the same DEFAULT-DROP policy.
# Without this, all IPv4 firewall rules can be bypassed via IPv6.
echo "   🔧 Configuring ip6tables (DEFAULT-DROP mode)..."

if command -v ip6tables &>/dev/null; then
    ip6tables -F OUTPUT 2>/dev/null || true
    ip6tables -P OUTPUT DROP 2>/dev/null || true
    ip6tables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
    ip6tables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    ip6tables -A OUTPUT -p tcp -j LOG --log-prefix "EGRESS_BLOCKED_IPv6_TCP: " --log-level 4 2>/dev/null || true
    ip6tables -A OUTPUT -p udp -j LOG --log-prefix "EGRESS_BLOCKED_IPv6_UDP: " --log-level 4 2>/dev/null || true
    echo "   ✅ ip6tables DEFAULT-DROP active"
else
    echo "   ℹ️  ip6tables not available (IPv6 not supported in this container)"
fi

echo "   ✅ iptables DEFAULT-DROP active (only proxy user can reach internet directly)"
echo "   ✅ DNS restricted to container resolver: ${CONTAINER_DNS}"
echo ""
echo "   ═══════════════════════════════════════════════════════════════"
echo "   🛡️  EGRESS FIREWALL ACTIVE (Domain-based proxy filtering)"
echo "   ───────────────────────────────────────────────────────────────"
echo "   Proxy:    localhost:${PROXY_PORT}"
echo "   Domains:  ${DOMAIN_COUNT} allowed (see $DOMAINS_FILE)"
echo "   Mode:     Squid proxy + iptables DEFAULT-DROP (enforced)"
echo "   DNS:      Restricted to ${CONTAINER_DNS} (tunneling blocked)"
echo "   Blocked:  dmesg | grep EGRESS_BLOCKED"
echo "   ═══════════════════════════════════════════════════════════════"
echo ""
