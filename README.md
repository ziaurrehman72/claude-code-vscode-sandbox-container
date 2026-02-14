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
│  │              │    │  │  • gh CLI + Copilot  │  │ │
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
| **Git & GitHub** | Git, GitHub CLI (`gh`), Copilot CLI Extension                  |
| **Editor**       | GitHub Copilot, Copilot Chat, Python/Pylance, ESLint, Prettier |
| **Shell**        | zsh with Oh My Zsh                                             |

---

## Security Features

This dev container is hardened and specifically addresses risks introduced by AI agents (Copilot Agent Mode, MCP tools, etc.):

| Measure                      | Details                                                                             |
| ---------------------------- | ----------------------------------------------------------------------------------- |
| **Rootless Container**       | Runs without host root privileges (Podman native, Docker compatible)                |
| **Capability Drop**          | All Linux capabilities removed, only `NET_RAW`, `DAC_OVERRIDE`, `NET_ADMIN` allowed |
| **No New Privileges**        | Processes cannot gain additional privileges                                         |
| **Egress Firewall**          | Outbound network traffic restricted to a domain whitelist (iptables + ipset)        |
| **SSH Agent Blocked**        | Host SSH keys are not available inside the container                                |
| **Git Credential Isolation** | Credential helper limited to a short-lived cache (15 min)                           |
| **Resource Limits**          | Memory (8 GB), CPUs (4), PIDs (512) — prevents DoS of the host                      |
| **Sudoers Removed**          | No `sudo` available inside the container                                            |
| **`.copilotignore`**         | Sensitive files are excluded from Copilot context                                   |
| **Port Isolation**           | Only explicitly defined ports are forwarded                                         |

---

## Quick Start

### Prerequisites

1. **VS Code** with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension (`ms-vscode-remote.remote-containers`)
2. **Container Runtime** — one of the following:
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/) (default)
   - [Podman](https://podman.io/) (rootless, daemonless)

### Setup in 3 Steps

#### 1. Copy `.devcontainer/` into your project

```bash
# Clone this repository (one-time)
git clone https://github.com/MSWagner/github-copilot-vscode-sandbox-container.git

# Copy the .devcontainer folder into your project
cp -r github-copilot-vscode-sandbox-container/.devcontainer/ /path/to/your/project/

# Optional: copy security files as well
cp github-copilot-vscode-sandbox-container/.copilotignore /path/to/your/project/
cp github-copilot-vscode-sandbox-container/.gitignore /path/to/your/project/
```

> **Tip:** If your project already has a `.gitignore`, merge the entries from the provided file instead of overwriting it.

#### 2. Start the container

1. Open your project in VS Code
2. `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` (Linux/Windows)
3. Select **"Dev Containers: Reopen in Container"**
4. The first time, the image will be built (~3–5 minutes)

**How do you know you're inside the container?**

- The status bar (bottom left) shows: `Dev Container: Sandboxed Dev Environment`
- The terminal shows a zsh shell with Oh My Zsh

#### 3. Authenticate GitHub CLI (for Copilot CLI)

```bash
# In the container terminal:
gh auth login
# → Follow the browser flow (enter the code)

# Install the Copilot CLI extension
gh extension install github/gh-copilot
```

> **Note:** The Copilot editor extension (inline suggestions + chat) works immediately — `gh auth login` is only needed for the CLI (`gh copilot suggest/explain`).

---

## Podman Setup (macOS)

If you use Podman instead of Docker, some additional setup is required.

### Install Podman

```bash
# Install via Homebrew
brew install podman

# Create a lightweight Linux VM (macOS has no Linux kernel)
podman machine init --cpus 4 --memory 4096

# Start the VM (required once after every reboot)
podman machine start

# Verify everything works
podman info
```

> **Note:** You need to run `podman machine start` once after every Mac reboot before using the dev container.

### Configure VS Code for Podman

Add these settings to your VS Code User Settings (JSON) via `Cmd+Shift+P` → "Preferences: Open User Settings (JSON)":

```json
{
  "dev.containers.dockerPath": "podman",
  "dev.containers.dockerComposePath": "podman-compose"
}
```

### Podman Cheat Sheet

```bash
# ── VM Management ──
podman machine list              # List all VMs and their status
podman machine start             # Start VM (required after reboot)
podman machine stop              # Stop VM (saves resources)
podman machine rm                # Delete VM completely

# ── Containers ──
podman ps                        # List running containers
podman ps -a                     # List all containers (including stopped)
podman exec -it <id> zsh         # Open shell in running container
podman logs <id>                 # Show container logs

# ── Cleanup ──
podman system prune -a           # Remove all unused images/containers
podman volume prune              # Remove unused volumes

# ── Update ──
brew upgrade podman              # Update Podman
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

Ports `3000`, `5000`, `8000`, `8080` are forwarded by default. Adjust in `devcontainer.json` under `forwardPorts`. Additional ports can be forwarded manually in VS Code (`Cmd+Shift+P` → "Forward a Port").

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
```

---

## Troubleshooting

### Container Build Fails

```bash
# Clear image cache and rebuild
docker system prune -a    # or: podman system prune -a

# In VS Code: Cmd+Shift+P → "Dev Containers: Rebuild Container"
```

### Network Issues (Domain Blocked)

The egress firewall blocks non-whitelisted domains. Check `.devcontainer/allowed-domains.conf`, add the missing domains, and restart the container.

### "Permission denied" Inside the Container

Since `sudo` has been removed, root access is only possible from outside the container:

```bash
docker exec -u root <container-id> chown -R vscode:vscode /workspaces
# or:
podman exec -u root <container-id> chown -R vscode:vscode /workspaces
```

### Copilot Extension Not Loading

```bash
# Check if extensions are installed:
code --list-extensions | grep copilot

# If not listed, rebuild the container:
# Cmd+Shift+P → "Dev Containers: Rebuild Container"
```

### "Cannot connect to Podman" / "Connection Refused"

The Podman VM is not running:

```bash
podman machine start
```

### Container Is Slow

Too few resources allocated to the Podman VM:

```bash
# Stop, delete, and recreate with more resources
podman machine stop
podman machine rm
podman machine init --cpus 6 --memory 8192
podman machine start
```

---

## How Security Works in Detail

### Container Startup Flow

```
1. Container starts as root (containerUser: root)
2. entrypoint.sh is executed:
   └── egress-firewall.sh sets iptables rules
       ├── Domains from allowed-domains.conf → DNS → IP addresses → ipset
       ├── Only whitelisted IPs allowed on port 80/443
       └── Everything else is dropped
3. VS Code connects as user "vscode" (remoteUser)
4. post-create.sh runs once:
   ├── Git credential hardening (cache instead of host forwarding)
   ├── Install Copilot CLI (if gh is authenticated)
   └── Install Python/Node dependencies (if present)
```

### What Is Isolated?

| Area                 | Status | Explanation                                    |
| -------------------- | ------ | ---------------------------------------------- |
| **Host Filesystem**  | ✅     | Only your project folder is visible            |
| **SSH Keys**         | ✅     | SSH agent forwarding disabled                  |
| **Git Credentials**  | ✅     | Short-lived cache (15 min), no host forwarding |
| **Network (Egress)** | ✅     | Only whitelisted domains reachable             |
| **Root Privileges**  | ✅     | sudo removed, no-new-privileges active         |
| **Resources**        | ✅     | Memory, CPU, PID limits enforced               |
| **Ports**            | ✅     | Only explicitly defined ports forwarded        |

### Known Limitations

- The egress firewall resolves domains to IPs at container startup. CDN IP rotation may require a container restart.
- Data exfiltration to whitelisted hosts (e.g., via GitHub Gist) remains theoretically possible.
- For production environments, a content-inspection proxy is recommended for stronger egress control.

---

## License

[MIT](LICENSE)
