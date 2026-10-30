# Sandboxed Dev Container for AI-Assisted Development

> A hardened, isolated development environment for VS Code with **GitHub Copilot**, **Claude Code**, or both.
> Restricts network egress, blocks privilege escalation, limits credential exposure, and prevents arbitrary binary execution, reducing the attack surface of AI agents like Copilot Agent Mode and Claude Code.

---

# What Is This?

This repository is a **template**. It contains a fully configured `.devcontainer/` folder that you copy into your own project. This gives you a sandboxed development environment that looks and feels like working locally - but runs inside an isolated container.

```
┌─────────────────────────────────────────────────────┐
│  Your Machine (Host)                                │
│                                                     │
│  ┌──────────────┐    ┌────────────────────────────┐ │
│  │  VS Code UI  │◄──►│  Container Runtime (VM)    │ │
│  │  (runs on    │    │  ┌──────────────────────┐  │ │
│  │   your       │    │  │  Container           │  │ │
│  │   machine)   │    │  │  • Python 3.12       │  │ │
│  │              │    │  │  • Node.js (nvm)     │  │ │
│  │              │    │  │  • Copilot / Claude  │  │ │
│  │              │    │  │  • Egress Firewall   │  │ │
│  │              │    │  │  • your project code │  │ │
│  └──────────────┘    │  └──────────────────────┘  │ │
│                      └────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

## Pre-Installed Tools

| Category         | Tools                                                          |
| ---------------- | -------------------------------------------------------------- |
| **Languages**    | Python 3.12, Node.js 20 (via nvm - switchable)                 |
| **Python**       | pip, pipx; poetry, black, ruff, ipython (read-only, see [below](#python-tools-and-the-home-directory)) |
| **Node.js**      | npm, nvm (install any version with `nvm install <version>`)    |
| **Git & GitHub** | Git                                                            |
| **AI Assistant** | GitHub Copilot + Chat and/or Claude Code (CLI + extension)     |
| **Editor**       | Python/Pylance, ESLint, Prettier                               |
| **Shell**        | zsh with Oh My Zsh                                             |

## Choosing Your Assistant

The template ships three variants that share one Dockerfile, firewall and set of security settings:

| Variant                           | Folder                     | Installs                        | Extra egress allowed                 |
| --------------------------------- | -------------------------- | ------------------------------- | ------------------------------------ |
| **Sandbox – GitHub Copilot**      | `.devcontainer/copilot/`   | Copilot + Copilot Chat          | `domains/copilot.conf`               |
| **Sandbox – Claude Code**         | `.devcontainer/claude/`    | Claude Code CLI + VS Code ext.  | `domains/claude.conf`                |
| **Sandbox – Copilot + Claude Code** | `.devcontainer/both/`    | Both                            | Both files                           |

When you run **"Dev Containers: Reopen in Container"**, VS Code asks which variant to use. Each variant only opens the network to the assistant it installs.

**To switch variants:** run **"Dev Containers: Reopen Folder Locally"**, then **"Dev Containers: Reopen in Container"** again and pick another variant. ("Rebuild Container" rebuilds the variant you are currently in; it does not show the picker.) Each variant is its own container, so switching back later is fast once both images are built.

## Security Features

This dev container is hardened and specifically addresses risks introduced by AI agents (Copilot Agent Mode, Claude Code, MCP tools, etc.):

| Measure                      | Details                                                                                                 |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- |
| **Rootless Container**       | Runs without host root privileges                                                                       |
| **Capability Drop**          | All capabilities dropped; only `DAC_OVERRIDE`, `NET_ADMIN`, `SETUID`, `SETGID`, `CHOWN` re-added; SUID bits stripped |
| **No New Privileges**        | Processes cannot gain additional privileges                                                             |
| **Egress Firewall**          | Outbound network traffic restricted to a domain whitelist (Squid proxy + iptables DEFAULT-DROP)         |
| **SSH Agent Blocked**        | Host SSH keys are not available inside the container                                                    |
| **Git Credential Isolation** | Credential helper limited to a short-lived cache (60 sec)                                               |
| **Resource Limits**          | Memory (8 GB), CPUs (4), PIDs (512) - prevents DoS of the host                                          |
| **Sudoers Removed**          | No `sudo` available inside the container                                                                |
| **`.copilotignore`**         | Sensitive files are excluded from Copilot context                                                       |
| **Claude Managed Settings**  | Read access to secret files (`.env`, keys, credentials) denied via read-only `/etc/claude-code/managed-settings.json` |
| **Port Isolation**           | Only explicitly defined ports are forwarded                                                             |
| **Read-Only Filesystem**     | Container root filesystem is read-only; only tmpfs and /workspaces writable                             |
| **Ephemeral Home**           | `/home/vscode` is an in-memory tmpfs, reset to clean dotfiles on every start                            |
| **Tamper-Proof Dev Tools**   | Preinstalled Python tools live on the read-only filesystem (`/opt/pipx`), so agents cannot modify them  |

## File Structure

```
.devcontainer/
├── copilot/devcontainer.json        # Variant: GitHub Copilot
├── claude/devcontainer.json         # Variant: Claude Code
├── both/devcontainer.json           # Variant: Copilot + Claude Code
└── shared/
    ├── Dockerfile                   # Image definition (Ubuntu 24.04 + tools)
    ├── entrypoint.sh                # Container entrypoint (runs firewall as root)
    ├── egress-firewall.sh           # Squid proxy + iptables enforcement
    ├── post-create.sh               # One-time setup after container creation
    ├── claude-managed-settings.json # Claude Code deny rules (secret files)
    └── domains/
        ├── common.conf              # Allowed egress domains for every variant
        ├── copilot.conf             # + GitHub Copilot domains
        └── claude.conf              # + Claude Code domains

.copilotignore               # Files excluded from Copilot analysis
.gitignore                   # Files excluded from version control
.gitattributes               # Enforces LF line endings (critical for Windows)
```

---

# Quick Start

## Prerequisites

1. **VS Code** with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension (`ms-vscode-remote.remote-containers`)
2. **Container Runtime** - one of the following:
   - [Rancher Desktop](https://rancherdesktop.io/) with dockerd backend - **recommended** (free, no license costs)
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/) (license required for organizations >250 employees)
   - [OrbStack](https://orbstack.dev/) (macOS only; license required for commercial use)
3. **Windows only:** [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) is **required**.

   ```powershell
   # Install WSL2 (PowerShell as Administrator)
   wsl --install
   ```

   The container uses Linux features (iptables, Squid, Linux capabilities) that only work with the WSL2 backend.
   Both Rancher Desktop and Docker Desktop must be configured to use it (this is the default for new installations).

## Setup in 3 Steps

### 1. Copy `.devcontainer/` into your project

**macOS / Linux:**

```bash
# Clone this repository (one-time)
git clone https://github.com/MSWagner/github-copilot-vscode-sandbox-container.git

# Copy the .devcontainer folder into your project
cp -r github-copilot-vscode-sandbox-container/.devcontainer/ /path/to/your/project/

# Optional: copy security files as well
cp github-copilot-vscode-sandbox-container/.copilotignore /path/to/your/project/
cp github-copilot-vscode-sandbox-container/.gitignore /path/to/your/project/
cp github-copilot-vscode-sandbox-container/.gitattributes /path/to/your/project/
```

**Windows (PowerShell):**

```powershell
# Clone this repository (one-time)
git clone https://github.com/MSWagner/github-copilot-vscode-sandbox-container.git

# Copy the .devcontainer folder into your project
Copy-Item -Recurse github-copilot-vscode-sandbox-container\.devcontainer\ \path\to\your\project\

# Optional: copy security files as well
Copy-Item github-copilot-vscode-sandbox-container\.copilotignore \path\to\your\project\
Copy-Item github-copilot-vscode-sandbox-container\.gitignore \path\to\your\project\
Copy-Item github-copilot-vscode-sandbox-container\.gitattributes \path\to\your\project\
```

> **Tip:** If your project already has a `.gitignore` or `.gitattributes`, merge the entries from the provided files instead of overwriting them.

### 2. Configure allowed domains

The egress firewall blocks all outbound traffic except to explicitly whitelisted domains. By default, **only domains required for VS Code, GitHub, the chosen AI assistant, and package managers (npm, PyPI, apt) are enabled**.

If your project uses additional services (Azure, Azure DevOps, Figma, Miro, Notion, etc.), you need to **uncomment the corresponding domains** in `.devcontainer/shared/domains/common.conf`:

```conf
# Example: Enable Azure DevOps for the ADO MCP server
*.dev.azure.com          # ← remove the leading "#" to enable

# Example: Enable Figma API
*.figma.com              # ← remove the leading "#" to enable
```

After editing, rebuild the container (`Cmd+Shift+P` / `Ctrl+Shift+P` → **"Dev Containers: Rebuild Container"**). The domain files are baked into the image, so a plain restart doesn't pick up changes.

> **⚠️ Security:** Wildcard domains (`*.example.com`) grant access to **all** subdomains, including potentially attacker-controlled ones. For example, `*.blob.core.windows.net` allows any Azure Storage account. Where possible, narrow wildcards to your specific instances (e.g., `myaccount.blob.core.windows.net`). See [Known Limitations → Wildcard Domains](#3-wildcard-domains) for details.

### 3. Start the container

1. Open your project in VS Code
2. `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Linux/Windows)
3. Select **"Dev Containers: Reopen in Container"**
4. Pick a variant: **Sandbox – GitHub Copilot**, **Sandbox – Claude Code**, or **Sandbox – Copilot + Claude Code**
5. The first time, the image will be built (~3–5 minutes)

**How do you know you're inside the container?**

- The status bar (bottom left) shows the variant name, e.g. `Dev Container: Sandbox – Claude Code`
- The terminal shows a zsh shell with Oh My Zsh

---

# Using Claude Code

Available in the **Claude Code** and **Copilot + Claude Code** variants.

- **Log in once:** click **Login** in the Claude Code panel, or run `claude` in the terminal and use `/login`. Complete the sign-in in your host browser (for the terminal, paste the code back). A Claude subscription and an Anthropic Console account both work. The panel and the CLI share the login; if you log in from the terminal while the panel is open, run **"Developer: Reload Window"** so the panel picks it up.
- **Login persists** in a per-container Docker volume (`claude-config-<id>`) mounted at `~/.claude`. Everything else in `/home/vscode` is a tmpfs and is wiped on restart. To log out completely, delete the volume: `docker volume ls | grep claude-config` → `docker volume rm <name>`.
- **Permissions:** Claude Code asks before running commands or editing files, as usual. Reading secret files (`.env`, `*.pem`, `*.key`, credentials, `.npmrc`, …) is **denied** by `/etc/claude-code/managed-settings.json`. That file is baked into the read-only image, so neither you nor the agent can override it from inside the container. Edit `.devcontainer/shared/claude-managed-settings.json` and rebuild to change it.
- **Skipping prompts** (`claude --dangerously-skip-permissions`) is possible, because the sandbox is the safety boundary. But the agent can then freely use every whitelisted domain, for example to push to GitHub or publish to npm. Use it deliberately.
- **Updates:** auto-update is disabled (the root filesystem is read-only). Rebuild the container to get the latest Claude Code.
- **Network:** nonessential traffic (telemetry, error reporting) is disabled, so only the domains in `domains/claude.conf` are needed. If Claude reports connection errors, see [Claude Code Can't Connect or Log In](#claude-code-cant-connect-or-log-in).

---

# Rancher Desktop Setup (Recommended)

[Rancher Desktop](https://rancherdesktop.io/) provides a full Docker-compatible runtime without Docker Desktop license costs. It uses the open-source dockerd (moby) engine.

## Install Rancher Desktop

```bash
# macOS
brew install --cask rancher

# Linux - see https://docs.rancherdesktop.io/getting-started/installation/#linux
```

```powershell
# Windows (winget)
winget install suse.RancherDesktop

# Alternative: download the installer from https://rancherdesktop.io/
```

## Configure Rancher Desktop

1. Open Rancher Desktop
2. Go to **Preferences → Container Engine → dockerd (moby)**
3. Verify it works:

```bash
docker info
```

## Configure VS Code

Add this setting to your VS Code User Settings (JSON) via `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Windows/Linux) → "Preferences: Open User Settings (JSON)":

```json
{
  "dev.containers.dockerPath": "docker"
}
```

---

# Customization

## Egress Firewall: Allowing Domains

The files in `.devcontainer/shared/domains/` define which external domains the container can reach. `common.conf` is always loaded. Each variant adds its assistant's file (`copilot.conf`, `claude.conf`, or both), selected by the `AI_PROFILE` value in the variant's `containerEnv`. The following are **enabled by default** (minimum required):

- **GitHub** - Git, API (all variants); Copilot (copilot/both)
- **Anthropic** - Claude API and login (claude/both)
- **npm**, **Node.js** and **PyPI** - package installation
- **Ubuntu Repos** - apt
- **VS Code / Microsoft** - extensions, updates

The following are **disabled by default** (commented out) and can be enabled as needed:

- **Azure** - Portal, APIs, DevOps, Storage, Key Vault
- **Figma, Miro, Notion, Amplitude** - MCP servers

To enable additional domains, uncomment them in `domains/common.conf` and rebuild the container. See [Quick Start Step 2](#2-configure-allowed-domains) for details and [Known Limitations → Wildcard Domains](#3-wildcard-domains) for security implications.

## Adjusting Resource Limits

In each variant's `devcontainer.json` under `runArgs`. The three variants intentionally duplicate their security and resource settings, because `devcontainer.json` has no include mechanism. **Keep them in sync.**

```jsonc
"--memory=8g",      // RAM limit (adjust for your machine)
"--cpus=4",          // CPU cores (adjust for your machine)
"--pids-limit=512"   // Max processes
```

## Python Tools and the Home Directory

The home directory `/home/vscode` is an in-memory tmpfs: it starts empty on every container start, and anything written to it is gone after a restart. On start, `entrypoint.sh` fills it with the base image's dotfiles (`.zshrc`, Oh My Zsh, `.bashrc`, …) from `/opt/home-skel`.

The preinstalled tools (poetry, black, ruff, ipython) are installed system-wide in `/opt/pipx`, with commands in `/usr/local/bin`. They are on the read-only filesystem, so an agent can't modify them. The data they write at runtime is still writable:

| Data                                         | Location                          | Survives restart? |
| -------------------------------------------- | --------------------------------- | ----------------- |
| Preinstalled tools                           | `/opt/pipx`, `/usr/local/bin`     | ✅ (read-only)    |
| Your project, incl. `.venv` / tool caches    | `/workspaces/<project>`           | ✅                |
| Claude Code login/config                     | `~/.claude` (Docker volume)       | ✅                |
| pip/poetry caches, shell history, `~/.config` | `/home/vscode/...`                | ❌ wiped          |
| `pip install --user`, `pipx install <tool>`  | `~/.local`                        | ❌ wiped          |

- **Keep environments in the project.** Poetry is preconfigured with `POETRY_VIRTUALENVS_IN_PROJECT=true`, so `poetry install` creates `<project>/.venv`, which persists. Do the same for plain venvs: `python -m venv .venv` inside the project.
- **Extra tools for a session:** `pipx install <tool>` works and installs into `~/.local` until the next restart.
- **Permanent extra tools, or a different version:** add a `pipx install <tool>` line to the system-wide pipx step in `.devcontainer/shared/Dockerfile` and rebuild. `pipx upgrade` and `poetry self add` don't work on the read-only preinstalled tools.

## Port Forwarding

Ports `3000`, `5000`, `8000`, `8080` are forwarded by default. Adjust in each variant's `devcontainer.json` under `forwardPorts`. Additional ports can be forwarded manually in VS Code (`Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Windows/Linux) → "Forward a Port").

## Disabling Network Access (Offline Mode)

Add this to `runArgs` in your variant's `devcontainer.json`:

```json
"--network=none"
```

> ⚠️ **Warning:** Copilot, Claude Code, pip, and npm require internet access. Only use this if all dependencies are pre-installed.

---

# How Security Works in Detail

## Container Startup Flow

```
1. Container starts as root (containerUser: root), with AI_PROFILE set by the variant
2. entrypoint.sh is executed:
   ├── Empty tmpfs home ← dotfiles from /opt/home-skel (owner vscode, mode 750)
   └── egress-firewall.sh configures Squid proxy
       ├── domains/common.conf + domains/<AI_PROFILE>.conf → Squid ACL
       │   (unknown profile or missing file → startup ABORTS)
       ├── Squid proxy starts on localhost:3128
       ├── iptables DROP rules (only proxy user can reach internet)
       └── If Squid fails → container startup ABORTS (fail-closed)
3. VS Code connects as user "vscode" (remoteUser)
4. post-create.sh runs once, from the project folder (postCreateCommand):
   └── Git credential hardening (cache instead of host forwarding)
```

## What Is Isolated?

| Area                 | Status | Explanation                                    |
| -------------------- | ------ | ---------------------------------------------- |
| **Host Filesystem**  | ✅     | Only your project folder is visible            |
| **SSH Keys**         | ✅     | SSH agent forwarding disabled                  |
| **Git Credentials**  | ✅     | Short-lived cache (60 sec), no host forwarding |
| **Network (Egress)** | ✅     | Only whitelisted domains reachable             |
| **Root Privileges**  | ✅     | sudo removed, no-new-privileges active         |
| **Home Directory**   | ✅     | In-memory tmpfs, reset on every start          |
| **Resources**        | ✅     | Memory, CPU, PID limits enforced               |
| **Ports**            | ✅     | Only explicitly defined ports forwarded        |

## Known Limitations

This sandbox significantly reduces the attack surface for AI agents, but **no sandbox is 100% secure**. Security is always a cost/benefit trade-off. The following limitations are known, accepted risks that are **not yet mitigated**:

### 1. Data Exfiltration via Whitelisted Domains

Even with perfect egress filtering, whitelisted domains can be used as exfiltration channels:

| Channel            | Domain                    | Method                              |
| ------------------ | ------------------------- | ----------------------------------- |
| GitHub Gist/API    | `github.com`              | `POST https://api.github.com/gists` |
| Anthropic API      | `api.anthropic.com`       | Requests with another account's API key |
| Azure Blob Storage | `*.blob.core.windows.net` | Upload to any storage account       |
| Notion API         | `api.notion.com`          | Create pages with data              |
| npm Publish        | `registry.npmjs.org`      | Publish package with data           |

This is an inherent trade-off: blocking these domains would break core functionality (Git, package installation, MCP servers). For environments handling highly sensitive data, consider a content-inspection proxy (e.g., mitmproxy) for deep packet inspection.

**Mitigation:** Review and narrow the domain whitelist in `domains/*.conf` for your use case. Remove domains for services you don't use (Figma, Miro, Notion, Amplitude). Replace broad Azure wildcards (`*.blob.core.windows.net`) with your specific account URLs where possible.

### 2. DNS Tunneling

Direct DNS queries to external DNS servers are **blocked and logged** - only the container's internal resolver (auto-detected from `/etc/resolv.conf`, typically `127.0.0.11`) is allowed. However, DNS tunneling through the container resolver is still possible: an agent can encode data in query names (e.g., `secret-data.attacker.com`), which the container resolver forwards through Docker's DNS to upstream resolvers and ultimately to the attacker's authoritative DNS server.

**Mitigation:** Deploy a DNS-layer filtering solution (e.g., Pi-hole, CoreDNS with response policy zones) or monitor DNS query logs for high-entropy domain names.

> **Monitoring tip:** Check for blocked direct DNS attempts with `dmesg | grep EGRESS_BLOCKED_DNS`.

### 3. Wildcard Domains

Some entries in `domains/*.conf` use wildcards (e.g., `*.blob.core.windows.net`, `*.visualstudio.com`). These grant access to **all** subdomains, including potentially attacker-controlled ones.

**Important:** Domains without a `*` prefix match **only the exact domain** - subdomains are not automatically included. If you need subdomains, use the explicit `*.example.com` syntax. Review the domain list and narrow wildcards to specific instances where possible.

### 4. No MCP Server Restrictions

The dev container does not restrict which [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) servers can be used by Copilot Agent Mode or Claude Code. Any MCP server that connects to a whitelisted domain will work. Organizations should define MCP server policies via GitHub Enterprise Copilot settings, VS Code organizational policies, or Claude Code managed settings (`claude-managed-settings.json`).

### 5. Git Credentials

Git credentials are cached for 60 seconds after explicit authentication by the user. During this window, any process (including AI agents) can perform Git operations. The host's credential helper is **not** forwarded - only the short-lived in-memory cache is available.

**Hardening options:**

- Reduce timeout further: Change `--timeout=60` to a lower value in `post-create.sh`
- Disable entirely: Set `git config --global credential.helper ''` - but this means `git push` / `git pull` to private repos will not work at all (since `GIT_TERMINAL_PROMPT=0` prevents interactive prompts)

### 6. Package Installation (Supply Chain)

PyPI and npm registries are whitelisted, allowing AI agents to install arbitrary packages. Malicious or typosquatted packages can execute arbitrary code via post-install scripts.

**Mitigation:** Use a private package registry with curation (e.g., Artifactory, Nexus), `pip install --require-hashes`, or restrict registry access to specific packages.

### 7. Writable Project Directory (`/workspaces`)

The `/workspaces` directory is writable by design - AI agents need to create and modify project files. However, this also allows:

- **Git hook manipulation:** An agent can create or modify `.git/hooks/pre-commit` (or other hooks) to execute arbitrary code on the next `git commit`.
- **Claude Code hooks/settings:** An agent can write `.claude/settings.json` in the project, adding hooks that run shell commands or `allow` rules that skip prompts. Managed deny rules still win, but hooks run with your user's rights.
- **Config file changes:** `.vscode/settings.json`, `.env` files, or CI/CD configs can be modified silently.

**Mitigation:** Use `core.hooksPath` pointing to a read-only directory for Git hooks. Review changes to `.claude/` like any other code. To forbid project hooks entirely, add `"allowManagedHooksOnly": true` to `claude-managed-settings.json`. Always review AI-generated changes before committing - treat agent output like an untrusted pull request.

### 8. Persisted Claude Credentials

The Claude Code login token lives in the `claude-config-<id>` Docker volume, so any process in the container can read it while the container runs. It also survives rebuilds. Delete the volume when you're done with a project, or log in with a scoped Console API key instead of a personal subscription.

## Potential Improvements

These are not implemented but could further harden the container for high-security environments:

- **Automated Base Image Updates:** Configure [Dependabot](https://docs.github.com/en/code-security/dependabot) or [Renovate](https://github.com/renovatebot/renovate) to automatically update the pinned Docker image digest in the Dockerfile. Pair with a CI pipeline running image scanning (e.g., [Trivy](https://github.com/aquasecurity/trivy), [Grype](https://github.com/anchore/grype)) to detect known CVEs before deployment.
- **Audit Logging:** Install `auditd` or configure persistent shell history (`HISTFILE` + `PROMPT_COMMAND`) to enable forensic analysis of AI agent actions. Persist Squid `access.log` via a volume mount.
- **Custom Seccomp Profile:** Block unnecessary syscalls (`ptrace`, `mount`, `keyctl`) via `--security-opt seccomp=custom-profile.json`.
- **AppArmor / SELinux Profile:** Provide a custom AppArmor profile (Ubuntu hosts) or SELinux policy (RHEL/Fedora hosts) to restrict file access beyond what the read-only filesystem and capabilities already enforce.
- **Reduce Required Capabilities:** `SETUID` and `SETGID` are currently needed for Squid's privilege drop to the `proxy` user and for `entrypoint.sh` to populate the home directory as `vscode`. `CHOWN` is needed to hand the tmpfs home, the Squid log directory and the `~/.claude` volume to their users. A lighter-weight forward proxy (e.g., tinyproxy) or running Squid directly as the `proxy` user, plus mounting the home tmpfs with `uid`/`gid` options, could eliminate these capabilities. Note: `no-new-privileges` and SUID-bit stripping already neutralize most of the risk.
- **Content-Inspection Proxy:** Deploy mitmproxy or a similar tool for deep packet inspection on whitelisted domains (detects data exfiltration in request bodies).

---

# Troubleshooting

## Container Build Fails

First rebuild without Docker's build cache: `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Windows/Linux) → **"Dev Containers: Rebuild Without Cache and Reopen in Container"**.

If that doesn't help, read the build log in VS Code's Dev Containers output for the failing step. Only as a last resort, clear Docker's caches:

```bash
# ⚠️ Removes ALL unused images and build cache on this machine,
# including those of other projects (they will be rebuilt/re-downloaded).
docker system prune -a
```

## Build Fails with `ReadTimeoutError` from `files.pythonhosted.org`

```
pip._vendor.urllib3.exceptions.ReadTimeoutError: HTTPSConnectionPool(host='files.pythonhosted.org', port=443): Read timed out.
Error installing poetry.
```

This happens in the Dockerfile's pipx step and is **not** caused by the egress firewall: the firewall only starts when the container runs, so the build has normal internet access. Downloads from PyPI's CDN are stalling somewhere between your machine and PyPI, and pip gives up when a download stalls for more than 15 seconds.

- **Retry later.** CDN and routing problems often clear up within hours.
- **Compare IPv4 and IPv6 from your host:**
  ```bash
  U=https://files.pythonhosted.org/packages/source/r/ruff/ruff-0.6.9.tar.gz
  curl -4 -sLo /dev/null -w 'IPv4: %{time_total}s\n' --max-time 20 $U
  curl -6 -sLo /dev/null -w 'IPv6: %{time_total}s\n' --max-time 20 $U
  ```
  The file is 3 MB and should take well under a second. If one protocol is slow or times out, your network's route to the CDN is the problem. Builds usually use IPv4, even when your host browser uses IPv6 and seems fast.
- **Restart your container runtime**, and check host VPNs or network filters.

## Container Exits Right After Starting

Startup is **fail-closed**: if the egress firewall can't be set up, `entrypoint.sh` stops the container instead of running it unprotected. Read the container's log from your host:

```bash
docker ps -a                    # find the exited container
docker logs <container-id>      # look for lines starting with ❌
```

| Log message                                                | Cause and fix                                                                                                                         |
| ---------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `Invalid AI_PROFILE entry` or `Domain whitelist not found` | `AI_PROFILE` in the variant's `containerEnv` names a profile with no `domains/<name>.conf` file. Fix the value or add the file, then rebuild. |
| `Cannot set iptables DEFAULT-DROP policy`                  | The runtime didn't grant `NET_ADMIN` or doesn't support iptables. On Windows, use the WSL2 backend.                                   |
| `Squid failed to start` or `Squid did NOT become ready`    | Read the `cache.log` lines printed below the error. A malformed entry in a `domains/*.conf` file is a common cause.                   |

## `Dev container config (…/.devcontainer/devcontainer.json) not found`

```
No dev container config found. No repository connection string found.
...
Error: Dev container config (/path/to/project/.devcontainer/devcontainer.json) not found.
```

**Cause:** VS Code opened the container through a saved address that doesn't say which variant to use. With the variant layout there is no `.devcontainer/devcontainer.json`, only `copilot/`, `claude/` and `both/`. Without a variant, VS Code falls back to that missing default path. This typically happens after a project switched from the old single-config template to the variant layout, because VS Code still holds addresses from before:

- the window VS Code **restores on startup** (so restarting VS Code, **Reload Window** and **Retry** reopen the same broken address)
- older **File → Open Recent** entries for the project's dev container
- opening the container from the **Remote Explorer** container list

The project and the container are fine. The container still records the right variant; VS Code just isn't using it.

**Fix:**

1. In the failing window, run **"Dev Containers: Reopen Folder Locally"** (or **File → Open Folder…** and open the project normally). Don't click **Retry**.
2. In the local window, run **"Dev Containers: Reopen in Container"** and pick the variant. VS Code now saves an address that includes the variant, and restores that one from then on.
3. Remove the stale entries: `Ctrl+R` (Open Recent), hover over the project's "[Dev Container]" entries that don't open, and click **×**.

From then on, open the project with "Reopen in Container" or a working Open Recent entry. If it still fails, remove the project's container (`docker ps -a`, then `docker rm -f <container-id>`) and run "Reopen in Container" again.

## `postCreateCommand` Fails: `post-create.sh: No such file or directory`

```
Start: Run in container: /bin/sh -c bash .devcontainer/shared/post-create.sh
bash: .devcontainer/shared/post-create.sh: No such file or directory
postCreateCommand from devcontainer.json failed with exit code 127. Skipping any further user-provided commands.
```

(The "What's next: Try Docker Debug …" lines that may appear in the same output are a Docker CLI hint, not part of the error.)

**Cause:** the one-time setup command uses a path relative to the project folder. VS Code runs it from the project folder only when it creates the container itself through **"Reopen in Container"**. It fails when VS Code didn't create the container that way:

- you used **"Dev Containers: Attach to Running Container"**, or
- the container was started outside VS Code (for example with the `devcontainer` CLI and a custom `--id-label`), so VS Code doesn't recognize it as the project's container.

In those cases VS Code runs the command stored in the image from the user's home directory (`/home/vscode`), where the relative path doesn't exist.

**Impact:** the container works, but `post-create.sh` did not run, so the Git credential hardening (60-second credential cache) is **not** applied.

**Fix:**

- Open the project with **"Dev Containers: Reopen in Container"** and pick the variant, instead of attaching to an existing container. VS Code then creates its own container and runs the setup from the project folder.
- If you need to keep using the attached container, run the script once manually in its terminal:
  ```bash
  bash /workspaces/<your-project>/.devcontainer/shared/post-create.sh
  ```

## Network Issues (Domain Blocked)

The egress firewall blocks non-whitelisted domains. The proxy log is readable only by root, so check it **from your host**:

```bash
docker exec -u root <container-id> grep DENIED /var/log/squid/access.log
```

Add the missing domains to `.devcontainer/shared/domains/common.conf` (or the assistant-specific file), and rebuild the container.

## Claude Code Can't Connect or Log In

1. **Check the variant.** In the container's terminal, `echo $AI_PROFILE` must include `claude`. The **Sandbox – GitHub Copilot** variant blocks Anthropic's domains on purpose.
2. **Check for blocked domains** with the `docker exec … grep DENIED …` command from [Network Issues](#network-issues-domain-blocked). Add any domain Claude Code needs to `domains/claude.conf`, and rebuild.
3. **Logging in:** after `/login`, open the printed URL in the browser **on your host** and paste the code back into the terminal.
4. **`Token exchange failed` / `request failed with status code 403` (or 503) after signing in from the panel:** the extension sends its login token request as a full-URL HTTPS request instead of a `CONNECT` tunnel. Squid's GnuTLS build (`squid` package) can't forward those; this template installs the OpenSSL build (`squid-openssl`), which can. If you copied `.devcontainer/` before that change, replace `squid` with `squid-openssl` in the Dockerfile's Squid `apt-get install` line and rebuild. Quick workaround without rebuilding: log in with `claude` → `/login` in the terminal, then run **"Developer: Reload Window"**.
5. **Logged out after a rebuild?** The login lives in the `claude-config-<id>` volume. VS Code's container gets a new `<id>` if the project folder moves or the variant changes, so you need to log in once per variant and folder.

## "Permission denied" Inside the Container

Since `sudo` has been removed, root access is only possible from outside the container:

```bash
docker exec -u root <container-id> chown -R vscode:vscode /workspaces
```

## Copilot Extension Not Loading

```bash
# Check if extensions are installed:
code --list-extensions | grep copilot

# If not listed, rebuild the container:
# Cmd+Shift+P (macOS) / Ctrl+Shift+P (Windows/Linux)
# → "Dev Containers: Rebuild Container"
```

## Windows: `/bin/bash\r: No such file or directory`

This means shell scripts have Windows-style line endings (CRLF instead of LF). The `.gitattributes` file in this repository prevents this, but if you copied files manually:

```powershell
# Fix line endings in existing files (Git Bash or WSL)
sed -i 's/\r$//' .devcontainer/shared/*.sh
sed -i 's/\r$//' .devcontainer/shared/domains/*.conf

# Or re-clone with correct settings
git config --global core.autocrlf input
git clone https://github.com/MSWagner/github-copilot-vscode-sandbox-container.git
```

> **Root cause:** Git on Windows defaults to `core.autocrlf=true`, which converts LF → CRLF on checkout. The `.gitattributes` file overrides this for container-critical files.

## Windows: Slow File Access / Container Performance

If the container feels slow (especially `npm install`, `pip install`, or file-heavy operations):

- Move your project into the **WSL2 filesystem** (`\\wsl$\Ubuntu\home\...`) instead of keeping it on `C:\`
- Windows filesystem mounts (from `C:\`) into WSL2/Docker have significant I/O overhead
- In VS Code: `Ctrl+Shift+P` → "WSL: New Window" → open your project from within WSL

---

# License

[MIT](LICENSE)
