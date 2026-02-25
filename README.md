# Sandboxed Dev Container for AI-Assisted Development

> A hardened, isolated development environment for VS Code with GitHub Copilot.
> Restricts network egress, blocks privilege escalation, limits credential exposure, and prevents arbitrary binary execution and reducing the attack surface of AI agents like Copilot Agent Mode.

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
│  │              │    │  │  • GitHub Copilot    │  │ │
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
| **Python**       | pip, poetry, black, ruff, ipython (via pipx)                   |
| **Node.js**      | npm, nvm (install any version with `nvm install <version>`)    |
| **Git & GitHub** | Git                                                            |
| **Editor**       | GitHub Copilot, Copilot Chat, Python/Pylance, ESLint, Prettier |
| **Shell**        | zsh with Oh My Zsh                                             |

## Security Features

This dev container is hardened and specifically addresses risks introduced by AI agents (Copilot Agent Mode, MCP tools, etc.):

| Measure                      | Details                                                                                                 |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- |
| **Rootless Container**       | Runs without host root privileges                                                                       |
| **Capability Drop**          | All Linux capabilities removed, only `DAC_OVERRIDE`, `NET_ADMIN` allowed; SUID bits stripped            |
| **No New Privileges**        | Processes cannot gain additional privileges                                                             |
| **Egress Firewall**          | Outbound network traffic restricted to a domain whitelist (Squid proxy + iptables DEFAULT-DROP)         |
| **SSH Agent Blocked**        | Host SSH keys are not available inside the container                                                    |
| **Git Credential Isolation** | Credential helper limited to a short-lived cache (60 sec)                                               |
| **Resource Limits**          | Memory (8 GB), CPUs (4), PIDs (512) - prevents DoS of the host                                          |
| **Sudoers Removed**          | No `sudo` available inside the container                                                                |
| **`.copilotignore`**         | Sensitive files are excluded from Copilot context                                                       |
| **Port Isolation**           | Only explicitly defined ports are forwarded                                                             |
| **Read-Only Filesystem**     | Container root filesystem is read-only; only tmpfs and /workspaces writable                             |

## File Structure

```
.devcontainer/
├── devcontainer.json        # Main configuration for VS Code
├── Dockerfile               # Image definition (Ubuntu 24.04 + tools)
├── post-create.sh           # One-time setup after container creation
├── entrypoint.sh            # Container entrypoint (runs firewall as root)
├── egress-firewall.sh       # Squid proxy + iptables enforcement
└── allowed-domains.conf     # List of allowed egress domains

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

The egress firewall blocks all outbound traffic except to explicitly whitelisted domains. By default, **only domains required for VS Code, GitHub Copilot, and package managers (npm, PyPI, apt) are enabled**.

If your project uses additional services (Azure, Azure DevOps, Figma, Miro, Notion, etc.), you need to **uncomment the corresponding domains** in `.devcontainer/allowed-domains.conf`:

```conf
# Example: Enable Azure DevOps for the ADO MCP server
*.dev.azure.com          # ← remove the leading "#" to enable

# Example: Enable Figma API
*.figma.com              # ← remove the leading "#" to enable
```

After editing, restart the container (`Cmd+Shift+P` / `Ctrl+Shift+P` → **"Dev Containers: Rebuild Container"**).

> **⚠️ Security:** Wildcard domains (`*.example.com`) grant access to **all** subdomains, including potentially attacker-controlled ones. For example, `*.blob.core.windows.net` allows any Azure Storage account. Where possible, narrow wildcards to your specific instances (e.g., `myaccount.blob.core.windows.net`). See [Known Limitations → Wildcard Domains](#4-wildcard-domains-in-allowed-domainsconf) for details.

### 3. Start the container

1. Open your project in VS Code
2. `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Linux/Windows)
3. Select **"Dev Containers: Reopen in Container"**
4. The first time, the image will be built (~3–5 minutes)

**How do you know you're inside the container?**

- The status bar (bottom left) shows: `Dev Container: Sandboxed Dev Environment`
- The terminal shows a zsh shell with Oh My Zsh

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

The file `.devcontainer/allowed-domains.conf` defines which external domains the container can reach. The following are **enabled by default** (minimum required):

- **GitHub** - Copilot, Git, API
- **npm**, **Node.js** and **PyPI** - package installation
- **Ubuntu Repos** - apt
- **VS Code / Microsoft** - extensions, updates

The following are **disabled by default** (commented out) and can be enabled as needed:

- **Azure** - Portal, APIs, DevOps, Storage, Key Vault
- **Figma, Miro, Notion, Amplitude** - MCP servers

To enable additional domains, uncomment them in `allowed-domains.conf` and restart the container. See [Quick Start Step 3](#3-configure-allowed-domains) for details and [Known Limitations → Wildcard Domains](#4-wildcard-domains-in-allowed-domainsconf) for security implications.

## Adjusting Resource Limits

In `.devcontainer/devcontainer.json` under `runArgs`:

```jsonc
"--memory=8g",      // RAM limit (adjust for your machine)
"--cpus=4",          // CPU cores (adjust for your machine)
"--pids-limit=512"   // Max processes
```

## Port Forwarding

Ports `3000`, `5000`, `8000`, `8080` are forwarded by default. Adjust in `devcontainer.json` under `forwardPorts`. Additional ports can be forwarded manually in VS Code (`Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Windows/Linux) → "Forward a Port").

## Disabling Network Access (Offline Mode)

Add this to `runArgs` in `devcontainer.json`:

```json
"--network=none"
```

> ⚠️ **Warning:** Copilot, pip, and npm require internet access. Only use this if all dependencies are pre-installed.

---

# How Security Works in Detail

## Container Startup Flow

```
1. Container starts as root (containerUser: root)
2. entrypoint.sh is executed:
   └── egress-firewall.sh configures Squid proxy
       ├── Domains from allowed-domains.conf → Squid ACL
       ├── Squid proxy starts on localhost:3128
       ├── iptables DROP rules (only proxy user can reach internet)
       └── If Squid fails → container startup ABORTS (fail-closed)
3. VS Code connects as user "vscode" (remoteUser)
4. post-create.sh runs once:
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
| **Resources**        | ✅     | Memory, CPU, PID limits enforced               |
| **Ports**            | ✅     | Only explicitly defined ports forwarded        |

## Known Limitations

This sandbox significantly reduces the attack surface for AI agents, but **no sandbox is 100% secure**. Security is always a cost/benefit trade-off. The following limitations are known, accepted risks that are **not yet mitigated**:

### 1. Data Exfiltration via Whitelisted Domains

Even with perfect egress filtering, whitelisted domains can be used as exfiltration channels:

| Channel            | Domain                    | Method                              |
| ------------------ | ------------------------- | ----------------------------------- |
| GitHub Gist/API    | `github.com`              | `POST https://api.github.com/gists` |
| Azure Blob Storage | `*.blob.core.windows.net` | Upload to any storage account       |
| Notion API         | `api.notion.com`          | Create pages with data              |
| npm Publish        | `registry.npmjs.org`      | Publish package with data           |

This is an inherent trade-off: blocking these domains would break core functionality (Git, package installation, MCP servers). For environments handling highly sensitive data, consider a content-inspection proxy (e.g., mitmproxy) for deep packet inspection.

**Mitigation:** Review and narrow the domain whitelist in `allowed-domains.conf` for your use case. Remove domains for services you don't use (Figma, Miro, Notion, Amplitude). Replace broad Azure wildcards (`*.blob.core.windows.net`) with your specific account URLs where possible.

### 2. DNS Tunneling

Direct DNS queries to external DNS servers are **blocked and logged** - only the container's internal resolver (auto-detected from `/etc/resolv.conf`, typically `127.0.0.11`) is allowed. However, DNS tunneling through the container resolver is still possible: an agent can encode data in query names (e.g., `secret-data.attacker.com`), which the container resolver forwards through Docker's DNS to upstream resolvers and ultimately to the attacker's authoritative DNS server.

**Mitigation:** Deploy a DNS-layer filtering solution (e.g., Pi-hole, CoreDNS with response policy zones) or monitor DNS query logs for high-entropy domain names.

> **Monitoring tip:** Check for blocked direct DNS attempts with `dmesg | grep EGRESS_BLOCKED_DNS`.

#### 3. Wildcard Domains in allowed-domains.conf

Some entries in `allowed-domains.conf` use wildcards (e.g., `*.blob.core.windows.net`, `*.visualstudio.com`). These grant access to **all** subdomains, including potentially attacker-controlled ones.

**Important:** Domains in `allowed-domains.conf` without a `*` prefix match **only the exact domain** - subdomains are not automatically included. If you need subdomains, use the explicit `*.example.com` syntax. Review the domain list and narrow wildcards to specific instances where possible.

#### 4. No MCP Server Restrictions

The dev container does not restrict which [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) servers can be used by Copilot Agent Mode. Any MCP server that connects to a whitelisted domain will work. Organizations should define MCP server policies via GitHub Enterprise Copilot settings or VS Code organizational policies.

#### 5. Git Credentials

Git credentials are cached for 60 seconds after explicit authentication by the user. During this window, any process (including AI agents) can perform Git operations. The host's credential helper is **not** forwarded - only the short-lived in-memory cache is available.

**Hardening options:**

- Reduce timeout further: Change `--timeout=60` to a lower value in `post-create.sh`
- Disable entirely: Set `git config --global credential.helper ''` - but this means `git push` / `git pull` to private repos will not work at all (since `GIT_TERMINAL_PROMPT=0` prevents interactive prompts)

#### 6. Package Installation (Supply Chain)

PyPI and npm registries are whitelisted, allowing AI agents to install arbitrary packages. Malicious or typosquatted packages can execute arbitrary code via post-install scripts.

**Mitigation:** Use a private package registry with curation (e.g., Artifactory, Nexus), `pip install --require-hashes`, or restrict registry access to specific packages.

### 8. Writable Project Directory (`/workspaces`)

The `/workspaces` directory is writable by design - AI agents need to create and modify project files. However, this also allows:

- **Git hook manipulation:** An agent can create or modify `.git/hooks/pre-commit` (or other hooks) to execute arbitrary code on the next `git commit`.
- **Config file changes:** `.vscode/settings.json`, `.env` files, or CI/CD configs can be modified silently.

**Mitigation:** Use `core.hooksPath` pointing to a read-only directory for Git hooks. Always review AI-generated changes before committing - treat agent output like an untrusted pull request.

## Potential Improvements

These are not implemented but could further harden the container for high-security environments:

- **Automated Base Image Updates:** Configure [Dependabot](https://docs.github.com/en/code-security/dependabot) or [Renovate](https://github.com/renovatebot/renovate) to automatically update the pinned Docker image digest in the Dockerfile. Pair with a CI pipeline running image scanning (e.g., [Trivy](https://github.com/aquasecurity/trivy), [Grype](https://github.com/anchore/grype)) to detect known CVEs before deployment.
- **Audit Logging:** Install `auditd` or configure persistent shell history (`HISTFILE` + `PROMPT_COMMAND`) to enable forensic analysis of AI agent actions. Persist Squid `access.log` via a volume mount.
- **Custom Seccomp Profile:** Block unnecessary syscalls (`ptrace`, `mount`, `keyctl`) via `--security-opt seccomp=custom-profile.json`.
- **AppArmor / SELinux Profile:** Provide a custom AppArmor profile (Ubuntu hosts) or SELinux policy (RHEL/Fedora hosts) to restrict file access beyond what the read-only filesystem and capabilities already enforce.
- **Reduce Required Capabilities:** The `SETUID`, `SETGID`, and `CHOWN` capabilities are currently needed for Squid's privilege drop to the `proxy` user. Evaluating a lighter-weight forward proxy (e.g., tinyproxy) or running Squid directly as the `proxy` user could eliminate the need for these capabilities. Note: `no-new-privileges` and SUID-bit stripping already neutralize most of the risk.
- **Content-Inspection Proxy:** Deploy mitmproxy or a similar tool for deep packet inspection on whitelisted domains (detects data exfiltration in request bodies).

---

# Troubleshooting

## Container Build Fails

```bash
# Clear image cache and rebuild
docker system prune -a

# In VS Code: Cmd+Shift+P (macOS) / Ctrl+Shift+P (Windows/Linux)
# → "Dev Containers: Rebuild Container"
```

## Network Issues (Domain Blocked)

The egress firewall blocks non-whitelisted domains. Check `.devcontainer/allowed-domains.conf`, add the missing domains, and restart the container.

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
sed -i 's/\r$//' .devcontainer/*.sh
sed -i 's/\r$//' .devcontainer/allowed-domains.conf

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
