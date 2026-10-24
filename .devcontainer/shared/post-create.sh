#!/usr/bin/env bash
# post-create.sh – One-time setup after container creation
# Runs ONCE after creation, NOT on every restart.
#
# 1. Git credential hardening

# Bash strict mode
set -euo pipefail

echo "🔧 Post-create setup starting..."
echo ""


# =============================================================================
# SECURITY: Git Credential Isolation
# =============================================================================
# Override VS Code's default credential forwarding with a short-lived
# in-memory cache (60 sec). Credentials are NOT forwarded from the host.
# The short timeout minimizes the window in which an AI agent could reuse
# cached credentials for unauthorized operations (e.g., git push, API calls).
# =============================================================================
echo "🔒 Git Credential Hardening..."

git config --global credential.helper 'cache --timeout=60'

echo "✅ Git credential helper set to 'cache' (60s timeout)"
