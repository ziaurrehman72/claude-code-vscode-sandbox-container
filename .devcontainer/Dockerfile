# Dockerfile – Sandboxed Dev Container (Ubuntu 24.04 + Python + Node.js)

# --- Base Image (Ubuntu 24.04 LTS, non-root "vscode" user) ---
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04


# --- Build Arguments ---
ARG PYTHON_VERSION=3.12
ARG NODE_VERSION=20


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


# --- Node.js (via NodeSource) ---
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*


# --- pipx (PEP 668 compliant tool installer, tools installed in user step) ---
RUN apt-get update \
    && apt-get install -y --no-install-recommends pipx \
    && rm -rf /var/lib/apt/lists/*


# --- Node.js Dev Tools (global) ---
RUN npm install -g \
    typescript \
    ts-node \
    eslint \
    prettier


# --- SECURITY: Squid proxy + iptables for domain-based egress filtering ---
RUN apt-get update \
    && apt-get install -y --no-install-recommends squid iptables \
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


# --- SECURITY: Egress firewall script (runs at container start via entrypoint) ---
COPY allowed-domains.conf /usr/local/etc/allowed-domains.conf
COPY egress-firewall.sh /usr/local/bin/egress-firewall.sh
RUN chmod +x /usr/local/bin/egress-firewall.sh

# --- SECURITY: Entrypoint + /etc/environment for --read-only mode ---
# Pre-populate /etc/environment (VS Code can't patch it on read-only fs).
# Entrypoint creates marker files so VS Code skips patching.
RUN echo 'PATH="/home/vscode/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' > /etc/environment \
    && echo 'SHELL="/usr/bin/zsh"' >> /etc/environment

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh


# --- Switch to non-root user ---
USER vscode
WORKDIR /home/vscode


# --- Python Dev Tools via pipx (poetry, black, ruff, ipython) ---
RUN pipx install poetry \
    && pipx install black \
    && pipx install ruff \
    && pipx install ipython \
    && pipx ensurepath


# Oh My Zsh: pre-installed in base image, no action needed.


# --- Default Shell & PATH ---
ENV SHELL=/usr/bin/zsh
ENV PATH="/home/vscode/.local/bin:${PATH}"


# --- Entrypoint (runs as root → starts Squid + iptables → hands off to CMD) ---
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
