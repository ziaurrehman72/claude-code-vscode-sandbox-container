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
#   1. Install GitHub Copilot CLI extension (if gh is authenticated)
#   2. Install Python dependencies (if requirements.txt exists)
#   3. Install Node dependencies (if package.json exists)
#   4. Configure Git defaults
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
# NOTE: For git push/pull, the user must explicitly authenticate
# (e.g., via gh auth login). Credentials are NOT automatically
# forwarded from the host.
# =============================================================================
echo "🔒 Git Credential Hardening..."

# Set credential helper to short in-memory cache.
# Credentials are automatically deleted after 900 seconds (15 min).
git config --global credential.helper 'cache --timeout=900'

# Set push default to "simple" — prevents accidentally pushing
# to branches other than the currently checked out one.
git config --global push.default simple

# Only allow push to the origin remote (no push to arbitrary URLs).
git config --global remote.pushDefault origin

echo "✅ Git credential helper set to 'cache' (15min timeout)"
echo ""


# =============================================================================
# 1. GITHUB COPILOT CLI
# =============================================================================
# The Copilot CLI is an extension of the GitHub CLI (gh).
# It enables:
#   gh copilot suggest "..."  → Get shell command suggestions
#   gh copilot explain "..."  → Get shell command explanations
#
# PREREQUISITE: gh must be authenticated (gh auth login).
# Since authentication requires a browser flow, it cannot happen
# automatically in the Dockerfile — the user must do it manually
# after the container starts.
# =============================================================================
if gh auth status &>/dev/null; then
    # gh is already authenticated (e.g., via stored credentials)
    echo "✅ GitHub CLI is authenticated"
    echo "📦 Installing GitHub Copilot CLI extension..."

    # "2>/dev/null" suppresses error messages if already installed.
    # "|| gh extension upgrade" → If install fails (because it's already there),
    #   try an upgrade instead.
    gh extension install github/gh-copilot 2>/dev/null || gh extension upgrade gh-copilot

    echo "✅ Copilot CLI ready!"
    echo ""
else
    # gh is NOT authenticated → print instructions
    echo "⚠️  GitHub CLI is not yet authenticated."
    echo ""
    echo "   Please run the following in the terminal after the container starts:"
    echo ""
    echo "   1. gh auth login          ← Follow the browser flow"
    echo "   2. gh extension install github/gh-copilot"
    echo ""
    echo "   Then you can use Copilot CLI:"
    echo "   gh copilot suggest 'find all python files modified today'"
    echo "   gh copilot explain 'tar -xzf archive.tar.gz -C /opt'"
    echo ""
fi


# =============================================================================
# 2. PYTHON DEPENDENCIES
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
# 3. NODE.JS DEPENDENCIES
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
# 4. GIT DEFAULTS
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
# 5. SUMMARY
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
echo "   gh:      $(gh --version | head -1)"
echo ""
echo "   Next step (if not done yet):"
echo "   → gh auth login"
echo "   → gh extension install github/gh-copilot"
echo ""
