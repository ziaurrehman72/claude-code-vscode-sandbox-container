# Sandboxed Dev Container for AI-Assisted Development

> A hardened, isolated development environment for VS Code with GitHub Copilot.
> Protects the host and credentials from potentially risky AI agent actions.

---

## What Is This?

This repository is a **template**. It contains a fully configured `.devcontainer/` folder that you copy into your own project. This gives you a sandboxed development environment that looks and feels like working locally — but runs inside an isolated container.

```
┌─────────────────────────────────────────────────────┐
│  Your Machine (Host)                                │
│                                                     │
│  ┌──────────────┐    ┌────────────────────────────┐ │
│  │  VS Code UI  │◄──►│  Container Runtime (VM)    │ │
│  │  (runs on    │    │  ┌──────────────────────┐  │ │
│  │   your       │    │  │  Container           │  │ │
│  │   machine)   │    │  │  • Python 3.12       │  │ │
│  │              │    │  │  • Node.js 20        │  │ │
│  │              │    │  │  • GitHub Copilot    │  │ │
│  │              │    │  │  • Egress Firewall   │  │ │
│  │              │    │  │  • your project code │  │ │
│  └──────────────┘    │  └──────────────────────┘  │ │
│                      └────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

### Pre-Installed Tools

| Category         | Tools                                                          |
| ---------------- | -------------------------------------------------------------- |
| **Languages**    | Python 3.12, Node.js 20                                        |
| **Python**       | pip, poetry, black, ruff, ipython (via pipx)                   |
| **Node.js**      | npm, TypeScript, ts-node, ESLint, Prettier                     |
| **Git & GitHub** | Git                                                            |
| **Editor**       | GitHub Copilot, Copilot Chat, Python/Pylance, ESLint, Prettier |
| **Shell**        | zsh with Oh My Zsh                                             |

---

## Security Features

This dev container is hardened and specifically addresses risks introduced by AI agents (Copilot Agent Mode, MCP tools, etc.):

| Measure                      | Details                                                                                 |
| ---------------------------- | --------------------------------------------------------------------------------------- |
| **Rootless Container**       | Runs without host root privileges                                                       |
| **Capability Drop**          | All Linux capabilities removed, only `NET_RAW`, `DAC_OVERRIDE`, `NET_ADMIN` allowed     |
| **No New Privileges**        | Processes cannot gain additional privileges                                             |
| **Egress Firewall**          | Outbound network traffic restricted to a domain whitelist (Squid proxy + iptables DROP) |
| **SSH Agent Blocked**        | Host SSH keys are not available inside the container                                    |
| **Git Credential Isolation** | Credential helper limited to a short-lived cache (5 min)                                |
| **Resource Limits**          | Memory (8 GB), CPUs (4), PIDs (512) — prevents DoS of the host                          |
| **Sudoers Removed**          | No `sudo` available inside the container                                                |
| **`.copilotignore`**         | Sensitive files are excluded from Copilot context                                       |
| **Port Isolation**           | Only explicitly defined ports are forwarded                                             |
| **Read-Only Filesystem**     | Container root filesystem is read-only; only tmpfs and /workspaces writable             |

---

## Quick Start

### Prerequisites

1. **VS Code** with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension (`ms-vscode-remote.remote-containers`)
2. **Container Runtime** — one of the following:
   - [Rancher Desktop](https://rancherdesktop.io/) with dockerd backend — **recommended** (free, no license costs)
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/) (license required for organizations >250 employees)
3. **Windows only:** [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) is **required**. The container uses Linux features (iptables, Squid, Linux capabilities) that only work with the WSL2 backend. Hyper-V Legacy is **not** supported.

   ```powershell
   # Install WSL2 (PowerShell as Administrator)
   wsl --install
   ```

   Both Rancher Desktop and Docker Desktop must be configured to use the **WSL2 backend** (this is the default for new installations).

### Setup in 3 Steps

#### 1. Copy `.devcontainer/` into your project

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
>
> **Windows Tip:** For best performance, store your project inside the WSL2 filesystem (`\\wsl$\Ubuntu\home\...`) rather than on `C:\`. File access from the Windows filesystem into the container is significantly slower.

#### 2. Start the container

1. Open your project in VS Code
2. `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Linux/Windows)
3. Select **"Dev Containers: Reopen in Container"**
4. The first time, the image will be built (~3–5 minutes)

**How do you know you're inside the container?**

- The status bar (bottom left) shows: `Dev Container: Sandboxed Dev Environment`
- The terminal shows a zsh shell with Oh My Zsh

---

## Rancher Desktop Setup (Recommended)

[Rancher Desktop](https://rancherdesktop.io/) provides a full Docker-compatible runtime without Docker Desktop license costs. It uses the open-source dockerd (moby) engine.

### Install Rancher Desktop

```bash
# macOS
brew install --cask rancher

# Linux — see https://docs.rancherdesktop.io/getting-started/installation/#linux
```

```powershell
# Windows (winget)
winget install suse.RancherDesktop

# Alternative: download the installer from https://rancherdesktop.io/
```

### Configure Rancher Desktop

1. Open Rancher Desktop
2. Go to **Preferences → Container Engine → dockerd (moby)**
3. Verify it works:

```bash
docker info
```

### Configure VS Code

Add this setting to your VS Code User Settings (JSON) via `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Windows/Linux) → "Preferences: Open User Settings (JSON)":

```json
{
  "dev.containers.dockerPath": "docker"
}
```

### Docker Cheat Sheet

```bash
# ── Containers ──
docker ps                        # List running containers
docker ps -a                     # List all containers (including stopped)
docker exec -it <id> zsh         # Open shell in running container
docker logs <id>                 # Show container logs

# ── Cleanup ──
docker system prune -a           # Remove all unused images/containers
docker volume prune              # Remove unused volumes
```

---

## Customization

### Egress Firewall: Allowing Domains

The file `.devcontainer/allowed-domains.conf` defines which external domains the container can reach. The following are allowed by default:

- **GitHub** — Copilot, Git, API
- **npm** and **PyPI** — package installation
- **Ubuntu Repos** — apt
- **VS Code / Microsoft** — extensions, updates
- **Azure** — Portal, APIs, DevOps
- **Figma, Miro, Notion, Amplitude** — MCP servers

To allow additional domains, add them to `allowed-domains.conf` and restart the container.

### Adjusting Resource Limits

In `.devcontainer/devcontainer.json` under `runArgs`:

```jsonc
"--memory=8g",      // RAM limit (adjust for your machine)
"--cpus=4",          // CPU cores (adjust for your machine)
"--pids-limit=512"   // Max processes
```

### Port Forwarding

Ports `3000`, `5000`, `8000`, `8080` are forwarded by default. Adjust in `devcontainer.json` under `forwardPorts`. Additional ports can be forwarded manually in VS Code (`Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Windows/Linux) → "Forward a Port").

### Disabling Network Access (Offline Mode)

Add this to `runArgs` in `devcontainer.json`:

```json
"--network=none"
```

> ⚠️ **Warning:** Copilot, pip, and npm require internet access. Only use this if all dependencies are pre-installed.

---

## File Structure

```
.devcontainer/
├── devcontainer.json        # Main configuration for VS Code
├── Dockerfile               # Image definition (Ubuntu 24.04 + tools)
├── post-create.sh           # One-time setup after container creation
├── entrypoint.sh            # Container entrypoint (runs firewall as root)
├── egress-firewall.sh       # iptables-based network whitelist
└── allowed-domains.conf     # List of allowed egress domains

.copilotignore               # Files excluded from Copilot analysis
.gitignore                   # Files excluded from version control
.gitattributes               # Enforces LF line endings (critical for Windows)
```

---

## Troubleshooting

### Container Build Fails

```bash
# Clear image cache and rebuild
docker system prune -a

# In VS Code: Cmd+Shift+P (macOS) / Ctrl+Shift+P (Windows/Linux)
# → "Dev Containers: Rebuild Container"
```

### Network Issues (Domain Blocked)

The egress firewall blocks non-whitelisted domains. Check `.devcontainer/allowed-domains.conf`, add the missing domains, and restart the container.

### "Permission denied" Inside the Container

Since `sudo` has been removed, root access is only possible from outside the container:

```bash
docker exec -u root <container-id> chown -R vscode:vscode /workspaces
```

### Copilot Extension Not Loading

```bash
# Check if extensions are installed:
code --list-extensions | grep copilot

# If not listed, rebuild the container:
# Cmd+Shift+P (macOS) / Ctrl+Shift+P (Windows/Linux)
# → "Dev Containers: Rebuild Container"
```

### Windows: `/bin/bash\r: No such file or directory`

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

### Windows: Slow File Access / Container Performance

If the container feels slow (especially `npm install`, `pip install`, or file-heavy operations):

- Move your project into the **WSL2 filesystem** (`\\wsl$\Ubuntu\home\...`) instead of keeping it on `C:\`
- Windows filesystem mounts (from `C:\`) into WSL2/Docker have significant I/O overhead
- In VS Code: `Ctrl+Shift+P` → "WSL: New Window" → open your project from within WSL

---

## How Security Works in Detail

### Container Startup Flow

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
   ├── Git credential hardening (cache instead of host forwarding)
   └── Install Python/Node dependencies (if present)
```

### What Is Isolated?

| Area                 | Status | Explanation                                   |
| -------------------- | ------ | --------------------------------------------- |
| **Host Filesystem**  | ✅     | Only your project folder is visible           |
| **SSH Keys**         | ✅     | SSH agent forwarding disabled                 |
| **Git Credentials**  | ✅     | Short-lived cache (5 min), no host forwarding |
| **Network (Egress)** | ✅     | Only whitelisted domains reachable            |
| **Root Privileges**  | ✅     | sudo removed, no-new-privileges active        |
| **Resources**        | ✅     | Memory, CPU, PID limits enforced              |
| **Ports**            | ✅     | Only explicitly defined ports forwarded       |

### Known Limitations

This sandbox significantly reduces the attack surface for AI agents, but **no sandbox is 100% secure**. Security is always a cost/benefit trade-off. The following limitations are accepted risks:

#### 1. Egress Firewall Enforcement

The egress firewall uses iptables DROP rules with `--uid-owner` exceptions to **enforce** that all HTTP/HTTPS traffic goes through the Squid proxy. This means `unset HTTP_PROXY` or direct socket connections are **blocked at the kernel level** — only the Squid proxy user can make direct outbound connections.

A transparent proxy via iptables REDIRECT is not feasible because it would only work for HTTP (port 80). For HTTPS (port 443), the proxy cannot inspect encrypted traffic without TLS interception (MITM), which breaks certificate pinning and would cause Copilot/GitHub connections to fail.

> **Monitoring tip:** Check for blocked bypass attempts with `dmesg | grep EGRESS_BLOCKED`.

#### 2. Data Exfiltration via Whitelisted Domains

Even with perfect egress filtering, whitelisted domains can be used as exfiltration channels:

| Channel            | Domain                    | Method                              |
| ------------------ | ------------------------- | ----------------------------------- |
| GitHub Gist/API    | `github.com`              | `POST https://api.github.com/gists` |
| Azure Blob Storage | `*.blob.core.windows.net` | Upload to any storage account       |
| Notion API         | `api.notion.com`          | Create pages with data              |
| npm Publish        | `registry.npmjs.org`      | Publish package with data           |

This is an inherent trade-off: blocking these domains would break core functionality (Git, package installation, MCP servers). For environments handling highly sensitive data, consider a content-inspection proxy (e.g., mitmproxy) for deep packet inspection.

**Mitigation:** Review and narrow the domain whitelist in `allowed-domains.conf` for your use case. Remove domains for services you don't use (Figma, Miro, Notion, Amplitude). Replace broad Azure wildcards (`*.blob.core.windows.net`) with your specific account URLs where possible.

#### 3. DNS Tunneling

DNS traffic (UDP/TCP port 53) is allowed without restriction to ensure name resolution works. This means data could theoretically be exfiltrated by encoding it in DNS queries to an attacker-controlled domain.

**Mitigation:** Restrict DNS to the container's DNS resolver (`127.0.0.11` for Docker) via additional iptables rules. This is not done by default because the required resolver address varies between container runtimes.

#### 4. NET_RAW Capability

The `NET_RAW` capability is required for DNS resolution and general network connectivity. However, it also enables raw socket creation, which could be used for ICMP tunneling or network scanning.

**Mitigation:** Add `iptables -A OUTPUT -p icmp -j DROP` to `egress-firewall.sh` if ICMP is not needed. Consider a custom seccomp profile to block `socket(AF_PACKET, ...)` calls.

#### 5. Wildcard Domains in allowed-domains.conf

Some entries in `allowed-domains.conf` use wildcards (e.g., `*.blob.core.windows.net`, `*.visualstudio.com`). These grant access to **all** subdomains, including potentially attacker-controlled ones.

**Important:** Domains in `allowed-domains.conf` without a `*` prefix match **only the exact domain** — subdomains are not automatically included. If you need subdomains, use the explicit `*.example.com` syntax. Review the domain list and narrow wildcards to specific instances where possible.

#### 6. No MCP Server Restrictions

The dev container does not restrict which [MCP (Model Context Protocol)](https://modelcontextprotocol.io/) servers can be used by Copilot Agent Mode. Any MCP server that connects to a whitelisted domain will work. Organizations should define MCP server policies via GitHub Enterprise Copilot settings or VS Code organizational policies.

#### 7. Git Credentials

Git credentials are cached for 5 minutes after explicit authentication by the user. During this window, any process (including AI agents) can perform Git operations. The host's credential helper is **not** forwarded — only the short-lived in-memory cache is available.

**Hardening options:**

- Reduce timeout further: Change `--timeout=300` to a lower value in `post-create.sh`
- Disable entirely: Set `git config --global credential.helper ''` — but this means `git push` / `git pull` to private repos will not work at all

#### 8. Package Installation (Supply Chain)

PyPI and npm registries are whitelisted, allowing AI agents to install arbitrary packages. Malicious or typosquatted packages can execute arbitrary code via post-install scripts.

**Mitigation:** Use a private package registry with curation (e.g., Artifactory, Nexus), `pip install --require-hashes`, or restrict registry access to specific packages.

### Potential Improvements

These are not implemented but could further harden the container for high-security environments:

- **Audit Logging:** Install `auditd` or configure persistent shell history (`HISTFILE` + `PROMPT_COMMAND`) to enable forensic analysis of AI agent actions. Persist Squid `access.log` via a volume mount.
- **Custom Seccomp Profile:** Block unnecessary syscalls (`ptrace`, `mount`, `keyctl`) via `--security-opt seccomp=custom-profile.json`.
- **Container Image Pinning:** Pin the base image by SHA256 digest instead of tag to prevent supply chain attacks via compromised registry mirrors.
- **Content-Inspection Proxy:** Deploy mitmproxy or a similar tool for deep packet inspection on whitelisted domains (detects data exfiltration in request bodies).

---

## License

[MIT](LICENSE)
