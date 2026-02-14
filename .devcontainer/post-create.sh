#!/usr/bin/env bash
# post-create.sh – One-time setup after container creation
# Runs ONCE after creation, NOT on every restart.
#
# 1. Git credential hardening
# 2. Python dependencies (if requirements.txt exists)
# 3. Node dependencies (if package.json exists)
# 4. Git defaults

# Bash strict mode
set -euo pipefail

echo "🔧 Post-create setup starting..."
echo ""


# =============================================================================
# 0. SECURITY: Git Credential Isolation
# =============================================================================
# Override VS Code's default credential forwarding with a short-lived
# in-memory cache (60 sec). Credentials are NOT forwarded from the host.
# The short timeout minimizes the window in which an AI agent could reuse
# cached credentials for unauthorized operations (e.g., git push, API calls).
# =============================================================================
echo "🔒 Git Credential Hardening..."

git config --global credential.helper 'cache --timeout=60'
git config --global push.default simple
git config --global remote.pushDefault origin

echo "✅ Git credential helper set to 'cache' (60s timeout)"
echo ""


# =============================================================================
# 1. PYTHON DEPENDENCIES
# =============================================================================
if [ -f "requirements.txt" ]; then
    echo "📦 requirements.txt found — creating venv and installing..."
    python3 -m venv .venv
    # shellcheck disable=SC1091
    source .venv/bin/activate
    pip install --no-cache-dir -r requirements.txt
    echo "✅ Python dependencies installed in .venv/"
    echo ""
fi


# =============================================================================
# 2. NODE.JS DEPENDENCIES
# =============================================================================
if [ -f "package.json" ]; then
    echo "📦 package.json found — installing Node dependencies..."
    npm install
    echo "✅ Node dependencies installed in node_modules/"
    echo ""
fi


# =============================================================================
# 3. GIT DEFAULTS
# =============================================================================
git config --global init.defaultBranch main
git config --global pull.rebase true


# =============================================================================
# 4. SUMMARY
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Dev Container is ready!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   Python:  $(python3 --version)"
echo "   Node:    $(node --version)"
echo "   npm:     $(npm --version)"
echo ""
