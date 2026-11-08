# 🟠 Atyro Panel Daemon

**Atyro Panel Daemon** is the remote node agent for **Atyro Panel**, a Minecraft server management panel. It runs on each Minecraft node, receives server-management commands from the panel, executes them locally, and reports node health and command results.

> **Version:** `1.0.1`  
> **Author:** Atyro Labs  
> **Component:** Remote Minecraft Node Daemon

---

## ✨ Features

- **Panel-to-node communication** using authenticated API requests.
- **Node heartbeat reporting**, including operating system, CPU count, memory, disk space, uptime, and Node.js version.
- **Minecraft server lifecycle management:** create, start, stop, restart, reinstall, and delete.
- **Multiple server software options** supported by the daemon's downloader, including Vanilla, Paper, Purpur, Velocity, Waterfall, Fabric, Quilt, Forge, BungeeCord, and Mohist.
- **Live server statistics** such as CPU usage, memory use, disk use, player count, uptime, and status.
- **Console and log support**, including command execution and reading `logs/latest.log`.
- **Player management** for supported actions such as OP/de-OP, whitelist, kick, ban, and pardon.
- **Plugin management** and file operations through the panel command system.
- **World and backup operations**, including world management, backup creation/deletion, and backup restoration.
- **Server configuration support**, including reading, saving, and resetting server properties.
- **File management** for listing, reading, writing, uploading, downloading, renaming, zipping, and extracting files.
- **Progress reporting** for supported long-running commands.
- **Path validation** to help prevent file operations from escaping a server's directory.
- **Download URL checks** designed to block private/internal network addresses.
- **Persistent daemon logs** written to `logs/agent.log`.

Feature availability depends on the command and server software supported by the installed panel and daemon versions.

---

## 🧰 Requirements

- Node.js installed on the node host.
- npm.
- Network access from the daemon to the Atyro Panel API.
- Java installed for Java Edition servers.
- Required operating-system tools for node monitoring and process detection. On Linux, the daemon uses tools such as `df` and `ss`; Windows uses Windows-specific commands.
- A valid node ID and node authentication token issued/configured for your panel.

---

## 📦 Installation

1. Place the daemon files in a dedicated directory on the machine that will host Minecraft servers.
2. Open a terminal in that directory.
3. Install the dependencies listed in your project's `package.json`:

   ```bash
   npm install
   ```

4. Configure the panel URL, node ID, authentication token, and daemon port as described below.
5. Start the daemon using the start command defined in your `package.json`, or the appropriate Node.js entry file for your installation.

> The exact entry filename and npm scripts depend on the files included in your daemon repository. Do not assume a script name unless it exists in `package.json`.

---

## ⚙️ Configuration

The daemon supports environment variables and a `config.json` file in the daemon's root directory.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `PANEL_URL` | `http://localhost:3000` | Base URL of the Atyro Panel API. Set this to the reachable panel URL. |
| `NODE_ID` | `1` | Numeric node ID registered in the panel. |
| `NODE_TOKEN` | Empty | Authentication token for the node. Required; the daemon exits if no token is configured. |
| `DAEMON_PORT` | `8787` | Port used by the daemon's HTTP service. |
| `BIND_HOST` | `0.0.0.0` | Address on which the daemon HTTP service binds. |

Example Linux session:

```bash
export PANEL_URL="https://panel.example.com"
export NODE_ID="1"
export NODE_TOKEN="REPLACE_WITH_YOUR_NODE_TOKEN"
export DAEMON_PORT="8787"
export BIND_HOST="0.0.0.0"
```

Then start the daemon using your configured entry point.

### `config.json`

Create `config.json` in the daemon root if you prefer file-based configuration:

```json
{
  "panelUrl": "https://panel.example.com",
  "nodeId": 1,
  "token": "REPLACE_WITH_YOUR_NODE_TOKEN",
  "port": 8787,
  "bindHost": "0.0.0.0",
  "heartbeatIntervalMs": 20000,
  "commandPollIntervalMs": 1000
}
```

Replace the example URL, node ID, and token with your actual configuration. The daemon loads `config.json` and merges it with its defaults. Keep the token private and do not commit real credentials to GitHub.

---

## 📁 Runtime directories and files

The daemon creates or uses the following paths relative to its application directory:

```text
daemon/
├── config.json          # Optional local configuration
├── servers/
│   └── <server-id>/     # Minecraft server files for each server
├── logs/
│   └── agent.log        # Daemon activity log
└── ...
```

- `servers/<server-id>/` contains the files for a managed server.
- `servers/<server-id>/logs/latest.log` is owned by the Minecraft server's logging system; the daemon reads it rather than writing console output into it.
- `logs/agent.log` stores daemon activity and error messages.
- Internal files such as `.ram_mb`, `.disk_mb`, `.server.pid`, and `.server.starttime` may be used for resource accounting and process tracking.

Do not manually edit or delete runtime files while a server is running unless you understand the consequences.

---

## 🔌 How it works

1. The daemon connects to the panel using the configured panel URL and node token.
2. It periodically sends a heartbeat containing node health and system information.
3. It polls the panel for pending commands for its configured node.
4. It executes supported commands on the node.
5. It reports command results and progress to the panel.
6. It serves node-side HTTP endpoints used by the panel.

The panel and daemon must be configured with matching node IDs and credentials. The panel API routes and authentication format must also match the daemon version.

---

## 🔐 Security recommendations

- **Never publish your real `NODE_TOKEN` or `config.json` credentials.**
- Use HTTPS for panel communication when the daemon connects across an untrusted network.
- Restrict access to the daemon's HTTP port with a firewall; do not expose it publicly unless your architecture requires it and access is properly secured.
- Use a dedicated, low-privilege operating-system account where possible instead of running the daemon as root/Administrator.
- Keep Node.js and project dependencies updated.
- Back up server worlds and important configuration before reinstalling, deleting, or restoring a server.
- Review file permissions for the daemon directory and all managed server directories.
- Do not run untrusted code or install unknown plugins on production nodes.

---

## 🧪 Troubleshooting

### Daemon exits because no token is configured

Set `NODE_TOKEN` or provide the `token` property in `config.json`. Restart the daemon after updating the configuration.

### Panel connection or heartbeat fails

- Verify `PANEL_URL` is correct and reachable from the node.
- Confirm the panel is running and its API routes match this daemon version.
- Check that `NODE_ID` exists in the panel and the token is correct.
- Check DNS, TLS certificates, routing, and firewall rules.
- Review `logs/agent.log` for details.

### Minecraft server will not start

- Verify Java is installed and available in `PATH` for Java Edition servers.
- Check that the selected server software downloaded successfully.
- Review the server's own `logs/latest.log`.
- Ensure the configured game port is available and allowed by the host firewall.

### CPU/process statistics are missing on Linux

Check that required system tools are installed and that the daemon's operating-system user has permission to inspect listening processes.

---

## 🗺️ Roadmap

Potential future improvements:

- Documented service-manager installation for Linux and Windows.
- More detailed health checks and node diagnostics.
- Automated daemon update workflow.
- Expanded monitoring and operational metrics.

---

## 🤝 Contributing

Contributions, bug reports, and suggestions are welcome. Please include:

- Operating system and version.
- Node.js version.
- A concise description of the issue.
- Relevant daemon logs with tokens and other secrets removed.
- Reproduction steps where possible.

---

## 📄 License

No license information was provided in the supplied daemon source. Add a `LICENSE` file and update this section before distributing the project publicly.

---

**Atyro Panel Daemon v1.0.0**  
Made by **Atyro Labs** 🟠
