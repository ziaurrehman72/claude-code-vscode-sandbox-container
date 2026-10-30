# Dockerfile – Sandboxed Dev Container (Ubuntu 24.04 + Python)
# Node.js is installed via Dev Container Feature (see devcontainer.json).

# --- Base Image (Ubuntu 24.04 LTS, non-root "vscode" user) ---
# NOTE: Digest should be updated regularly (e.g. monthly) to pick up security patches.
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04@sha256:d94c97dd9cacf183d0a6fd12a8e87b526e9e928307674ae9c94139139c0c6eae


# --- Build Arguments ---
ARG PYTHON_VERSION=3.12


# --- System Packages ---
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


# --- Python (from Ubuntu repos, symlinked to /usr/bin/python) ---
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        python${PYTHON_VERSION} \
        python${PYTHON_VERSION}-venv \
        python3-pip \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*


# --- pipx (PEP 668 compliant tool installer, tools installed in user step) ---
RUN apt-get update \
    && apt-get install -y --no-install-recommends pipx \
    && rm -rf /var/lib/apt/lists/*


# --- SECURITY: Squid proxy + iptables for domain-based egress filtering ---
# squid-openssl (not the GnuTLS "squid" build): some clients send full-URL
# HTTPS requests instead of CONNECT tunnels, e.g. the Claude Code VS Code
# extension's login token exchange. Only the OpenSSL build can forward those,
# and it verifies server certificates against the system CA store.
RUN apt-get update \
    && apt-get install -y --no-install-recommends squid-openssl iptables \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /var/log/squid /var/spool/squid /var/cache/squid \
    && chown -R proxy:proxy /var/log/squid /var/spool/squid /var/cache/squid


# --- SECURITY: Remove sudoers (defense-in-depth, use `docker exec -u root` if needed) ---
RUN rm -f /etc/sudoers.d/vscode

# --- SECURITY: Strip SUID/SGID bits from binaries (defense-in-depth) ---
# --no-new-privileges already neutralizes SUID, but stripping bits removes
# the attack surface entirely. Only keep mount/umount (needed by some tools).
RUN find / -path /proc -prune -o -path /sys -prune -o -type f -perm /6000 -print 2>/dev/null \
    | grep -v -E '/(mount|umount)$' \
    | xargs -r chmod u-s,g-s 2>/dev/null || true


# --- Python Dev Tools via pipx (poetry, black, ruff, ipython), installed system-wide ---
# /home/vscode is an empty tmpfs at runtime, so anything installed into it here
# would be hidden. Installing into /opt + /usr/local/bin keeps the tools visible
# and, on the read-only root fs, tamper-proof. The PIPX_* vars apply to this step
# only: at runtime `pipx install <tool>` still works and goes to ~/.local
# (writable, but wiped on restart).
RUN export PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin \
        PIPX_MAN_DIR=/usr/local/share/man PIP_NO_CACHE_DIR=1 \
    && pipx install poetry \
    && pipx install black \
    && pipx install ruff \
    && pipx install ipython \
    && rm -rf /root/.cache

# --- Home skeleton: base image dotfiles (.zshrc, Oh My Zsh, .bashrc, ...) ---
# Copied into the empty tmpfs home by entrypoint.sh on every start.
RUN cp -a /home/vscode /opt/home-skel


# --- SECURITY: Egress firewall script (runs at container start via entrypoint) ---
# Domain files: common.conf + per-assistant files, selected at runtime by AI_PROFILE.
COPY domains/ /usr/local/etc/allowed-domains.d/
COPY egress-firewall.sh /usr/local/bin/egress-firewall.sh
RUN chmod +x /usr/local/bin/egress-firewall.sh

# --- SECURITY: Claude Code managed settings (deny reads of secret files) ---
# Lives on the read-only root fs, so the agent cannot edit it. Managed settings
# take precedence over user/project settings. Harmless when Claude isn't installed.
COPY claude-managed-settings.json /etc/claude-code/managed-settings.json

# --- SECURITY: Entrypoint + /etc/environment for --read-only mode ---
# Pre-populate /etc/environment (VS Code can't patch it on read-only fs).
# Entrypoint creates marker files so VS Code skips patching.
RUN echo 'PATH="/home/vscode/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/environment \
    && echo 'SHELL="/usr/bin/zsh"' >> /etc/environment

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- SECURITY: Healthcheck — detect Squid proxy crashes ---
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD squid -f /etc/squid/squid.conf -k check 2>/dev/null || exit 1

# --- Switch to non-root user ---
USER vscode
WORKDIR /home/vscode


# --- Default Shell & PATH ---
# ~/.local/bin holds tools a user installs at runtime (session-only).
ENV SHELL=/usr/bin/zsh
ENV PATH="/home/vscode/.local/bin:${PATH}"

# Keep Poetry virtualenvs in the project (<project>/.venv), which persists.
# The default (~/.cache/pypoetry/virtualenvs) is on the tmpfs and wiped on restart.
ENV POETRY_VIRTUALENVS_IN_PROJECT=true


# --- Entrypoint (runs as root → starts Squid + iptables → hands off to CMD) ---
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
