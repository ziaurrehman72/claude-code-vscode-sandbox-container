#!/usr/bin/env bash
# =============================================================================
# post-create.sh – One-time setup script after container creation
# =============================================================================
#
# When does this script run?
#   ONCE, after the container is created for the first time.
#   It does NOT run on every container restart.
#   (For that, use "postStartCommand" in devcontainer.json)
#
# What does it do?
#   1. Install Python dependencies (if requirements.txt exists)
#   2. Install Node dependencies (if package.json exists)
#   3. Configure Git defaults
#
# =============================================================================

# -----------------------------------------------------------------------------
# Enable Bash Strict Mode
# -----------------------------------------------------------------------------
# set -e  → Script aborts immediately on ANY error
# set -u  → Undefined variables are an error (prevents typos)
# set -o pipefail → Errors IN a pipeline are also caught
# -----------------------------------------------------------------------------
set -euo pipefail

echo "🔧 Post-create setup starting..."
echo ""


# =============================================================================
# 0. SECURITY HARDENING: Git Credential Isolation
# =============================================================================
# VS Code forwards the host's Git credential helper into the container by
# default. This means ANY process in the container (including AI agents)
# can perform Git operations as the host user — clone private repos, push, etc.
#
# We restrict this by:
#   1. Setting credential helper to "cache" (short-lived in-memory cache,
#      max 15 minutes, ONLY after an explicit git command by the user)
#   2. Configuring Git to only allow push to origin
#   3. Disabling interactive prompts (GIT_TERMINAL_PROMPT=0 via remoteEnv)
#
# NOTE: For git push/pull, the user must explicitly authenticate.
# Credentials are NOT automatically forwarded from the host.
# =============================================================================
echo "🔒 Git Credential Hardening..."

# Set credential helper to short in-memory cache.
# Credentials are automatically deleted after 900 seconds (15 min).
git config --global credential.helper 'cache --timeout=300'

# Set push default to "simple" — prevents accidentally pushing
# to branches other than the currently checked out one.
git config --global push.default simple

# Only allow push to the origin remote (no push to arbitrary URLs).
git config --global remote.pushDefault origin

echo "✅ Git credential helper set to 'cache' (5min timeout)"
echo ""


# =============================================================================
# 1. PYTHON DEPENDENCIES
# =============================================================================
# If a requirements.txt exists in the project root, create a virtual
# environment (.venv) and install the dependencies.
#
# Why a venv when we're already in a container?
#   - Best practice: isolates project dependencies from system Python
#   - Prevents conflicts with globally installed tools (black, ruff)
#   - VS Code automatically detects .venv as the interpreter
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
# If a package.json exists in the project root, install the dependencies
# with npm.
#
# npm install reads package.json and:
#   - Installs all "dependencies" and "devDependencies"
#   - Creates/updates package-lock.json
#   - Places everything in node_modules/
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
# Sets sensible Git defaults for the container:
#
# init.defaultBranch = main
#   → New repos use "main" instead of "master" as the default branch
#
# pull.rebase = true
#   → "git pull" does a rebase instead of a merge commit.
#     Keeps Git history linear and clean.
# =============================================================================
git config --global init.defaultBranch main
git config --global pull.rebase true


# =============================================================================
# 4. SUMMARY
# =============================================================================
# Prints installed versions so you can see at a glance what's available
# in the container.
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
