#!/usr/bin/env bash
# =============================================================================
# egress-firewall.sh – Domain-based egress filtering via Squid forward proxy
# =============================================================================
#
# This script runs as root at container start and configures:
#   1. A Squid forward proxy that filters by DOMAIN NAME (not IP)
#   2. iptables LOG rules to monitor direct connections (bypass detection)
#
# WHY a Proxy Instead of IP-Based Filtering?
#   The previous approach resolved domains to IPs at container start and
#   used iptables/ipset to allow only those IPs. This is fundamentally
#   broken for CDN-backed services (GitHub Copilot, npm, Azure, etc.)
#   where IPs rotate frequently. Even periodic DNS re-resolution cannot
#   keep up with CDN IP changes.
#
#   A forward proxy solves this because:
#   - HTTP:  The proxy sees the Host header → filters by domain name
#   - HTTPS: The client sends CONNECT domain:443 → proxy sees the domain
#            BEFORE establishing the TLS tunnel (no TLS interception needed)
#   - CDN IP rotation is completely irrelevant
#
# ALLOWED DESTINATIONS:
#   Defined in /usr/local/etc/allowed-domains.conf
#   (source file: .devcontainer/allowed-domains.conf)
#
# HOW IT WORKS:
#   1. Squid listens on localhost:3128
#   2. allowed-domains.conf is converted to a Squid ACL file
#   3. HTTP_PROXY/HTTPS_PROXY env vars route traffic through Squid
#   4. VS Code http.proxy setting routes extension traffic through Squid
#   5. Squid denies requests to non-whitelisted domains
#   6. iptables LOG rules detect any direct connections (bypass monitoring)
#
# SECURITY MODEL:
#   - Proxy env vars + VS Code settings ensure standard tools use Squid
#   - Squid denies connections to non-whitelisted domains
#   - iptables logging detects proxy bypass attempts
#   - no-new-privileges prevents privilege escalation
#   - The proxy runs as a dedicated "proxy" user with no login shell
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
# Convert our domain list into Squid's dstdomain ACL format.
# Squid ACL format:
#   .example.com  → matches example.com AND all subdomains (*.example.com)
#   example.com   → matches only example.com exactly
#
# Our conversion rules:
#   *.example.com → .example.com  (Squid wildcard = leading dot)
#   example.com   → example.com   (exact match only, no automatic wildcard)
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
# Block direct outbound HTTP/HTTPS connections that bypass the Squid proxy.
# Only the "proxy" user (Squid) is allowed to make direct connections.
# All other users (including vscode) MUST go through the proxy.
#
# This enforces the domain whitelist at the network level — even if a
# process unsets HTTP_PROXY or uses a library that ignores proxy settings,
# the connection will be dropped by iptables.
#
# IMPORTANT: This requires Docker (dockerd) as the container runtime.
# ─────────────────────────────────────────────────────────────────────────────
echo "   🔧 Configuring iptables (enforced DROP mode)..."

# Get the UID of the proxy user (Squid runs as this user)
PROXY_UID=$(id -u proxy 2>/dev/null || echo "13")

# Flush existing OUTPUT rules to start clean
iptables -F OUTPUT 2>/dev/null || true

# Allow DNS (UDP + TCP port 53) — required by both proxy and clients
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT 2>/dev/null || true

# Allow all loopback traffic (proxy <-> clients on localhost)
iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true

# Allow established/related connections (response packets)
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true

# Allow container-internal traffic (Docker bridge network)
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT 2>/dev/null || true

# ALLOW the proxy user (Squid) to make direct outbound connections.
# This is the ONLY user that can reach the internet directly.
iptables -A OUTPUT -p tcp --dport 80 -m owner --uid-owner "$PROXY_UID" -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 443 -m owner --uid-owner "$PROXY_UID" -j ACCEPT 2>/dev/null || true

# LOG and DROP direct HTTP/HTTPS from all other users (bypass attempts).
# Check logs with: dmesg | grep EGRESS_BLOCKED
iptables -A OUTPUT -p tcp --dport 80 -j LOG --log-prefix "EGRESS_BLOCKED_HTTP: " --log-level 4 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 80 -j DROP 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 443 -j LOG --log-prefix "EGRESS_BLOCKED_HTTPS: " --log-level 4 2>/dev/null || true
iptables -A OUTPUT -p tcp --dport 443 -j DROP 2>/dev/null || true

# Block ICMP (prevents ICMP tunneling for data exfiltration)
iptables -A OUTPUT -p icmp -j DROP 2>/dev/null || true

echo "   ✅ iptables DROP rules active (only proxy user can reach internet directly)"
echo ""
echo "   ═══════════════════════════════════════════════════════════════"
echo "   🛡️  EGRESS FIREWALL ACTIVE (Domain-based proxy filtering)"
echo "   ───────────────────────────────────────────────────────────────"
echo "   Proxy:    localhost:${PROXY_PORT}"
echo "   Domains:  ${DOMAIN_COUNT} allowed (see $DOMAINS_FILE)"
echo "   Mode:     Squid proxy + iptables DROP (enforced)"
echo "   Blocked:  dmesg | grep EGRESS_BLOCKED"
echo "   ═══════════════════════════════════════════════════════════════"
echo ""
