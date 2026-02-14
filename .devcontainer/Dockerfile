# =============================================================================
# Dockerfile – Builds the container image for the development environment
# =============================================================================
#
# Structure:
#   1. Base image (Ubuntu with dev tools from Microsoft)
#   2. System packages (build-essential, curl, git, etc.)
#   3. Python 3.12
#   4. Node.js 20
#   5. Python dev tools (black, ruff, poetry, etc.)
#   6. Node.js dev tools (typescript, eslint, prettier)
#   7. Security hardening (egress firewall, sudoers removal)
#   8. Shell setup (Oh My Zsh)
#
# =============================================================================


# -----------------------------------------------------------------------------
# STEP 1: Base Image
# -----------------------------------------------------------------------------
# Official Microsoft Dev Container base image. It includes:
#   - Ubuntu 24.04 (LTS)
#   - A non-root user named "vscode" (uid 1000)
#   - sudo privileges for the vscode user
#   - Basic locale configuration (UTF-8)
#   - Python 3.12 available natively (no PPA needed)
# -----------------------------------------------------------------------------
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04


# -----------------------------------------------------------------------------
# STEP 2: Build Arguments (can be overridden at build time)
# -----------------------------------------------------------------------------
# ARG defines variables available ONLY during the build.
# Override at build time, e.g.: docker build --build-arg PYTHON_VERSION=3.11 .
# -----------------------------------------------------------------------------
ARG PYTHON_VERSION=3.12
ARG NODE_VERSION=20


# -----------------------------------------------------------------------------
# STEP 3: Install System Packages
# -----------------------------------------------------------------------------
# Installed packages and their purpose:
#   build-essential → gcc, g++, make – needed for compiling native
#                     Python/Node modules (e.g., numpy, bcrypt)
#   curl            → HTTP client – used for downloading install scripts
#   git             → Version control – VS Code requires git in the container
#   zsh             → Z Shell – more comfortable shell than bash
#   jq              → CLI JSON parser – useful for API responses
#   unzip           → Needed by some installers
#   ca-certificates → SSL/TLS certificates – required for HTTPS connections
# -----------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        zsh \
        jq \
        unzip \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*


# -----------------------------------------------------------------------------
# STEP 4: Install Python
# -----------------------------------------------------------------------------
# Ubuntu 24.04 includes Python 3.12 natively in the standard repositories.
#
# Installed packages:
#   python3.12      → The Python interpreter itself
#   python3.12-venv → Enables virtual environments (python -m venv)
#   python3-pip     → The Python package manager
#
# The ln commands create convenience shortcuts:
#   /usr/bin/python3 → points to python3.12
#   /usr/bin/python  → points to python3
# -----------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-venv \
        python3-pip \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*


# -----------------------------------------------------------------------------
# STEP 5: Install Node.js
# -----------------------------------------------------------------------------
# Uses the official NodeSource setup script which:
#   1. Adds the NodeSource repository to apt
#   2. Imports the GPG key (package authenticity)
#   3. Then Node.js can be installed normally via apt
#
# npm is automatically installed alongside Node.js.
# -----------------------------------------------------------------------------
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*


# -----------------------------------------------------------------------------
# STEP 6: Install pipx (as system package)
# -----------------------------------------------------------------------------
# pipx is the recommended way to install Python CLI tools on Ubuntu 24.04
# (PEP 668). It creates an isolated virtual environment for each tool —
# no conflicts, no --break-system-packages needed.
#
# Installed via apt (system-wide). The actual tools are then installed
# as the vscode user via pipx (STEP 8b).
# -----------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends pipx \
    && rm -rf /var/lib/apt/lists/*


# -----------------------------------------------------------------------------
# STEP 7: Install Node.js Dev Tools
# -----------------------------------------------------------------------------
# Installed globally (-g) so they're available in every project:
#
#   typescript → The TypeScript compiler (tsc)
#   ts-node    → Runs TypeScript files directly without a compile step
#   eslint     → JavaScript/TypeScript linter
#   prettier   → Code formatter for JS/TS/JSON/CSS/HTML/Markdown
# -----------------------------------------------------------------------------
RUN npm install -g \
    typescript \
    ts-node \
    eslint \
    prettier


# -----------------------------------------------------------------------------
# STEP 7b: SECURITY – Install Egress Firewall Dependencies
# -----------------------------------------------------------------------------
# Installs Squid (forward proxy) and iptables for domain-based egress
# filtering. Squid filters by domain name (not IP), which is essential
# for CDN-backed services where IPs rotate frequently.
#
# iptables enforces that all HTTP/HTTPS traffic goes through Squid —
# direct outbound connections on ports 80/443 are blocked for all users
# except the proxy user.
#
# SECURITY: Without egress filtering, AI agents can exfiltrate arbitrary
# data via HTTP/HTTPS to external servers.
# -----------------------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends squid iptables \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/squid /var/spool/squid /var/cache/squid \
    && chown -R proxy:proxy /var/log/squid /var/spool/squid /var/cache/squid


# -----------------------------------------------------------------------------
# STEP 7c: SECURITY – Remove Sudoers Entry
# -----------------------------------------------------------------------------
# The Microsoft base image creates a sudoers entry granting the vscode
# user passwordless root access: vscode ALL=(root) NOPASSWD:ALL
#
# Although --security-opt=no-new-privileges blocks this, it's a latent
# risk: if no-new-privileges is removed (e.g., for debugging), the
# container immediately gets full root access.
#
# SECURITY: Defense-in-depth — explicitly remove unnecessary privileges.
# If root access is needed in an emergency: use docker exec -u root.
# -----------------------------------------------------------------------------
RUN rm -f /etc/sudoers.d/vscode


# -----------------------------------------------------------------------------
# STEP 7d: SECURITY – Install Egress Firewall Script
# -----------------------------------------------------------------------------
# Copies the firewall script into the image and makes it executable.
# It runs at container start via the entrypoint.
# -----------------------------------------------------------------------------
COPY allowed-domains.conf /usr/local/etc/allowed-domains.conf
COPY egress-firewall.sh /usr/local/bin/egress-firewall.sh
RUN chmod +x /usr/local/bin/egress-firewall.sh

# -----------------------------------------------------------------------------
# STEP 7e: SECURITY – Install Entrypoint
# -----------------------------------------------------------------------------
# The entrypoint starts the Squid proxy and egress firewall as root
# before the container process takes over as the vscode user.
# No DNS refresh daemon needed — Squid resolves domains on each request.
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# STEP 7f: SECURITY – Pre-populate /etc/environment for read-only mode
# -----------------------------------------------------------------------------
# VS Code Dev Containers normally patches /etc/environment at startup to
# set PATH and SHELL. With --read-only, /etc is not writable. We pre-
# populate the file during build so the container has the correct
# environment from the start. The entrypoint creates marker files so
# VS Code skips the patching step.
# -----------------------------------------------------------------------------
RUN echo 'PATH="/home/vscode/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/environment \
    && echo 'SHELL="/usr/bin/zsh"' >> /etc/environment

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh


# -----------------------------------------------------------------------------
# STEP 8: Switch to Non-Root User
# -----------------------------------------------------------------------------
# From here on, all commands run as the "vscode" user (not root).
# This is important for:
#   - Security: if a process is compromised, it has no root privileges
#   - Consistency: files created in the container belong to the vscode
#     user (no permission issues)
# -----------------------------------------------------------------------------
USER vscode
WORKDIR /home/vscode


# -----------------------------------------------------------------------------
# STEP 8b: Install Python Dev Tools via pipx
# -----------------------------------------------------------------------------
# Now running as the vscode user, we install tools with pipx.
# Each tool gets its own isolated virtual environment:
#
#   poetry  → Modern Python package manager (alternative to pip +
#             requirements.txt). Manages dependencies with lock files.
#   black   → Code formatter for Python. Automatically formats code
#             in a consistent style (PEP 8 compatible).
#   ruff    → Extremely fast Python linter (written in Rust).
#             Replaces flake8, isort, pycodestyle in one tool.
#   ipython → Interactive Python shell with syntax highlighting,
#             tab completion, and magic commands.
#
# pipx ensurepath → Adds ~/.local/bin to PATH so tools are available
#                   directly as commands.
# -----------------------------------------------------------------------------
RUN pipx install poetry \
    && pipx install black \
    && pipx install ruff \
    && pipx install ipython \
    && pipx ensurepath


# -----------------------------------------------------------------------------
# STEP 9: Oh My Zsh
# -----------------------------------------------------------------------------
# Oh My Zsh is already pre-installed in the base image
# (mcr.microsoft.com/devcontainers/base) — reinstalling would fail since
# /home/vscode/.oh-my-zsh already exists. Therefore we skip this step.
# -----------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# STEP 10: Set Default Shell
# -----------------------------------------------------------------------------
ENV SHELL=/usr/bin/zsh
ENV PATH="/home/vscode/.local/bin:${PATH}"


# -----------------------------------------------------------------------------
# STEP 11: SECURITY – Entrypoint & CMD
# -----------------------------------------------------------------------------
# The entrypoint starts as root (containerUser: root in devcontainer.json),
# starts the Squid proxy, configures iptables to enforce proxy usage,
# and then hands off to the normal container process.
# VS Code operates as remoteUser: vscode — separate from the container user.
# -----------------------------------------------------------------------------
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
