
#!/usr/bin/env bash
#
# Atyro Daemon Installer v3.0
# Author: Atyro Labs
# Repository: https://github.com/atyrolabs/daemon
# Process Manager: PM2
# Default Directory: /etc/atyro
#

set -Eeuo pipefail

# ==========================================
# COLORS
# ==========================================

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

log()  { echo -e "${GREEN}[OK]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
title(){ echo -e "\n${BOLD}${CYAN}========== $* ==========${NC}\n"; }

die() {
    err "$*"
    exit 1
}

trap 'err "Installation failed at line $LINENO."' ERR

# ==========================================
# ROOT CHECK
# ==========================================

if [[ $EUID -ne 0 ]]; then
    die "Run installer using: sudo bash installer.sh"
fi

# ==========================================
# DEFAULT SETTINGS
# ==========================================

DEFAULT_DIR="/etc/atyro"
DEFAULT_REPO="https://github.com/atyrolabs/daemon"
DEFAULT_BRANCH="main"
DEFAULT_PROCESS="atyro-daemon"
DEFAULT_PANEL="http://localhost:3000"
DEFAULT_NODE="1"
DEFAULT_PORT="8787"
DEFAULT_BIND="0.0.0.0"

# ==========================================
# INPUT HELPERS
# ==========================================

ask() {
    local prompt="$1"
    local default="$2"
    local variable="$3"
    local reply=""

    read -rp "$(echo -e "${CYAN}?${NC} ${prompt} [${default}]: ")" reply || true

    printf -v "$variable" '%s' "${reply:-$default}"
}

ask_secret() {
    local reply=""

    while [[ -z "$reply" ]]; do
        read -rsp "$(echo -e "${CYAN}?${NC} Node authentication token: ")" reply || true
        echo

        [[ -n "$reply" ]] || warn "Token cannot be empty."
    done

    TOKEN="$reply"
}

ask_yn() {
    local reply=""

    read -rp "$(echo -e "${CYAN}?${NC} $1 [Y/n]: ")" reply || true

    reply="${reply:-y}"

    [[ "$reply" =~ ^[Yy]$ ]]
}

# ==========================================
# BANNER
# ==========================================

clear 2>/dev/null || true

echo -e "${CYAN}${BOLD}"

cat <<'EOF'

     _  _____ __   __ _____   ___
    / \|_   _|\ \ / /|  _  | / _ \
   / _ \ | |   \ V / | |_| || | | |
  / ___ \| |    | |  |  _  || |_| |
 /_/   \_\_|    |_|  |_| |_| \___/

          ATYRO DAEMON
          PM2 INSTALLER v3.0

EOF

echo -e "${NC}"

info "Welcome to Atyro Daemon Installer!"

# ==========================================
# CONFIGURATION
# ==========================================

title "Installation Configuration"

ask "Installation directory" "$DEFAULT_DIR" INSTALL_DIR
ask "Git repository URL" "$DEFAULT_REPO" REPO_URL
ask "Git branch" "$DEFAULT_BRANCH" BRANCH
ask "PM2 process name" "$DEFAULT_PROCESS" PROCESS_NAME
ask "Panel URL" "$DEFAULT_PANEL" PANEL_URL
ask "Node ID" "$DEFAULT_NODE" NODE_ID
ask "Daemon port" "$DEFAULT_PORT" PORT
ask "Bind host" "$DEFAULT_BIND" BIND_HOST

ask_secret

# ==========================================
# VALIDATION
# ==========================================

title "Validating Configuration"

[[ "$INSTALL_DIR" == /* ]] ||
    die "Installation directory must be absolute."

[[ "$PROCESS_NAME" =~ ^[a-zA-Z0-9_.-]+$ ]] ||
    die "Invalid PM2 process name."

[[ "$NODE_ID" =~ ^[0-9]+$ ]] ||
    die "Node ID must be numeric."

[[ "$PORT" =~ ^[0-9]+$ ]] &&
    (( PORT >= 1 && PORT <= 65535 )) ||
    die "Invalid daemon port."

[[ "$PANEL_URL" =~ ^https?://[^[:space:]]+$ ]] ||
    die "Invalid panel URL."

[[ "$REPO_URL" =~ ^https://github\.com/[^/]+/[^/]+/?$ ]] ||
    die "Invalid GitHub repository URL."

[[ "$BRANCH" =~ ^[a-zA-Z0-9._/-]+$ ]] ||
    die "Invalid Git branch."

# ==========================================
# CONFIRMATION
# ==========================================

title "Installation Summary"

cat <<EOF
Directory       : $INSTALL_DIR
Repository      : $REPO_URL
Branch          : $BRANCH
PM2 Process     : $PROCESS_NAME
Panel URL       : $PANEL_URL
Node ID         : $NODE_ID
Port            : $PORT
Bind Host       : $BIND_HOST
Token           : ********
EOF

echo

ask_yn "Start installation?" ||
    die "Installation cancelled."

# ==========================================
# DETECT PACKAGE MANAGER
# ==========================================

title "Detecting Operating System"

[[ -f /etc/os-release ]] ||
    die "Cannot detect operating system."

source /etc/os-release

info "Operating System: ${PRETTY_NAME:-Unknown}"

if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
elif command -v pacman >/dev/null 2>&1; then
    PKG_MANAGER="pacman"
else
    die "Unsupported package manager."
fi

log "Package manager: $PKG_MANAGER"

# ==========================================
# INSTALL SYSTEM PACKAGES
# ==========================================

title "Installing System Dependencies"

install_packages() {

    case "$PKG_MANAGER" in

        apt)
            export DEBIAN_FRONTEND=noninteractive

            apt-get update

            apt-get install -y \
                ca-certificates \
                curl \
                git \
                build-essential \
                python3 \
                make \
                g++ \
                procps \
                iproute2 \
                util-linux \
                coreutils \
                findutils \
                grep \
                sed \
                gawk \
                tar \
                gzip \
                xz-utils
            ;;

        dnf)
            dnf install -y \
                ca-certificates \
                curl git \
                gcc gcc-c++ \
                make python3 \
                procps-ng \
                iproute \
                util-linux \
                coreutils \
                findutils \
                grep sed gawk \
                tar gzip xz
            ;;

        yum)
            yum install -y \
                ca-certificates \
                curl git \
                gcc gcc-c++ \
                make python3 \
                procps-ng \
                iproute \
                util-linux \
                coreutils \
                findutils \
                grep sed gawk \
                tar gzip xz
            ;;

        pacman)
            pacman -Sy --noconfirm \
                ca-certificates \
                curl git \
                base-devel \
                python \
                procps-ng \
                iproute2 \
                util-linux \
                coreutils \
                findutils \
                grep sed gawk \
                tar gzip xz
            ;;
    esac
}

install_packages

log "System packages installed."

# ==========================================
# INSTALL NODE.JS 22 LTS
# ==========================================

title "Checking Node.js and npm"

install_nodejs() {

    local install_required=0

    if command -v node >/dev/null 2>&1 &&
       command -v npm >/dev/null 2>&1; then

        local version
        version="$(node -p 'process.versions.node.split(".")[0]')"

        if (( version >= 20 )); then
            log "Node.js $(node --version) already installed."
            return
        fi
    fi

    install_required=1

    if (( install_required )); then

        info "Installing Node.js 22 LTS..."

        case "$PKG_MANAGER" in

            apt)
                curl -fsSL \
                    https://deb.nodesource.com/setup_22.x \
                    -o /tmp/atyro-node-setup.sh

                bash /tmp/atyro-node-setup.sh

                rm -f /tmp/atyro-node-setup.sh

                apt-get install -y nodejs
                ;;

            dnf|yum)
                curl -fsSL \
                    https://rpm.nodesource.com/setup_22.x \
                    -o /tmp/atyro-node-setup.sh

                bash /tmp/atyro-node-setup.sh

                rm -f /tmp/atyro-node-setup.sh

                if [[ "$PKG_MANAGER" == "dnf" ]]; then
                    dnf install -y nodejs
                else
                    yum install -y nodejs
                fi
                ;;

            pacman)
                pacman -S --noconfirm nodejs npm
                ;;
        esac
    fi

    command -v node >/dev/null ||
        die "Node.js installation failed."

    command -v npm >/dev/null ||
        die "npm installation failed."

    local version
    version="$(node -p 'process.versions.node.split(".")[0]')"

    (( version >= 20 )) ||
        die "Node.js 20 or newer is required."
}

install_nodejs

log "Node.js: $(node --version)"
log "npm: $(npm --version)"

# ==========================================
# PREPARE GLOBAL NPM PATH
# ==========================================

NPM_PREFIX="$(npm config get prefix)"

export PATH="$NPM_PREFIX/bin:/usr/local/bin:/usr/bin:$PATH"

# ==========================================
# PREPARE INSTALLATION DIRECTORY
# ==========================================

title "Preparing Installation Directory"

mkdir -p "$(dirname "$INSTALL_DIR")"

BACKUP=""

if [[ -d "$INSTALL_DIR" ]] &&
   [[ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null || true)" ]]; then

    if [[ ! -d "$INSTALL_DIR/.git" ]]; then
        die "Directory already contains files but is not a Git repository. Choose another directory or move the existing files."
    fi

    BACKUP="${INSTALL_DIR}.backup.$(date +%Y%m%d-%H%M%S)"

    info "Creating backup: $BACKUP"

    cp -a "$INSTALL_DIR" "$BACKUP"

    log "Backup created."
fi

mkdir -p "$INSTALL_DIR"

# ==========================================
# CLONE / UPDATE GIT REPOSITORY
# ==========================================

title "Cloning Atyro Daemon Repository"

if [[ -d "$INSTALL_DIR/.git" ]]; then

    info "Existing Git repository detected."

    git -C "$INSTALL_DIR" fetch \
        --depth 1 \
        origin "$BRANCH"

    git -C "$INSTALL_DIR" checkout -B \
        "$BRANCH" "origin/$BRANCH"

    git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH"

else

    git clone \
        --depth 1 \
        --single-branch \
        --branch "$BRANCH" \
        "$REPO_URL" \
        "$INSTALL_DIR"

fi

log "Repository cloned successfully."

# ==========================================
# VERIFY REPOSITORY
# ==========================================

title "Checking Daemon Files"

[[ -f "$INSTALL_DIR/agent.js" ]] ||
    die "agent.js not found in repository."

[[ -f "$INSTALL_DIR/package.json" ]] ||
    die "package.json not found in repository."

log "agent.js found."
log "package.json found."

# ==========================================
# INSTALL NPM DEPENDENCIES
# ==========================================

title "Installing Daemon Dependencies"

cd "$INSTALL_DIR"

npm install \
    --omit=dev \
    --no-audit \
    --no-fund

# Verify production dependencies.
node <<'NODE'
const fs = require("fs");
const p = JSON.parse(fs.readFileSync("package.json", "utf8"));

for (const name of Object.keys(p.dependencies || {})) {
    try {
        require.resolve(name);
    } catch (error) {
        console.error("Missing dependency:", name);
        process.exitCode = 1;
    }
}
NODE

log "npm dependencies installed successfully."

# ==========================================
# CREATE RUNTIME DIRECTORIES
# ==========================================

title "Creating Runtime Directories"

mkdir -p "$INSTALL_DIR/servers"
mkdir -p "$INSTALL_DIR/logs"

# ==========================================
# GENERATE CONFIG.JSON
# ==========================================

title "Generating Daemon Configuration"

CONFIG_PATH="$INSTALL_DIR/config.json"

CONFIG_PANEL="$PANEL_URL" \
CONFIG_NODE="$NODE_ID" \
CONFIG_TOKEN="$TOKEN" \
CONFIG_PORT="$PORT" \
CONFIG_BIND="$BIND_HOST" \
node <<'NODE'
const fs = require("fs");

const config = {
    panelUrl: process.env.CONFIG_PANEL,
    nodeId: Number(process.env.CONFIG_NODE),
    token: process.env.CONFIG_TOKEN,
    port: Number(process.env.CONFIG_PORT),
    bindHost: process.env.CONFIG_BIND
};

fs.writeFileSync(
    "config.json",
    JSON.stringify(config, null, 2) + "\n",
    { mode: 0o600 }
);
NODE

chmod 600 "$CONFIG_PATH"

log "Configuration generated successfully."

# ==========================================
# VERIFY DAEMON
# ==========================================

title "Checking Daemon Syntax"

node --check "$INSTALL_DIR/agent.js"

log "agent.js syntax check passed."

# ==========================================
# INSTALL PM2 GLOBALLY
# ==========================================

title "Installing PM2 Process Manager"

npm install pm2@latest -g \
    --no-audit \
    --no-fund

NPM_PREFIX="$(npm config get prefix)"

export PATH="$NPM_PREFIX/bin:/usr/local/bin:/usr/bin:$PATH"

command -v pm2 >/dev/null ||
    die "PM2 installation failed."

log "PM2 version: $(pm2 --version)"

# ==========================================
# START DAEMON USING PM2
# ==========================================

title "Starting Atyro Daemon"

cd "$INSTALL_DIR"

# Remove previous process with the same name.
pm2 delete "$PROCESS_NAME" >/dev/null 2>&1 || true

# Start daemon.
pm2 start agent.js \
    --name "$PROCESS_NAME" \
    --time

# Save process list.
pm2 save

log "Daemon started using PM2."

# ==========================================
# CONFIGURE PM2 STARTUP
# ==========================================

title "Configuring Automatic Startup"

# Generate PM2 startup integration for root.
# This configures boot-time startup through PM2.

pm2 startup systemd -u root --hp /root

# Save process list for reboot recovery.
pm2 save

log "PM2 startup configured."

# ==========================================
# VERIFY PM2 PROCESS
# ==========================================

title "Verifying Daemon Process"

sleep 3

STATUS="$(
    pm2 jlist | node -e '
        let data = "";
        process.stdin.on("data", chunk => data += chunk);
        process.stdin.on("end", () => {
            const processes = JSON.parse(data);
            const process = processes.find(
                p => p.name === process.env.PROCESS_NAME
            );
            console.log(process?.pm2_env?.status || "not-found");
        });
    ' PROCESS_NAME="$PROCESS_NAME"
)"

if [[ "$STATUS" != "online" ]]; then

    err "Daemon failed to start."

    pm2 logs "$PROCESS_NAME" \
        --lines 50 \
        --nostream || true

    die "PM2 process is not online. Check the daemon logs."

fi

log "Daemon is online."

# ==========================================
# FINAL PM2 SAVE
# ==========================================

pm2 save

# ==========================================
# INSTALLATION SUMMARY
# ==========================================

title "ATYRO DAEMON INSTALLATION COMPLETE"

cat <<EOF

       ATYRO DAEMON v3.0

--------------------------------------------

Installation Directory : $INSTALL_DIR
Configuration          : $CONFIG_PATH
Repository             : $REPO_URL
Branch                 : $BRANCH

Node.js                : $(node --version)
npm                    : $(npm --version)
PM2                    : $(pm2 --version)

Panel URL              : $PANEL_URL
Node ID                : $NODE_ID
Daemon Port            : $PORT
Bind Host              : $BIND_HOST

Process Manager        : PM2
Process Name           : $PROCESS_NAME
Process Status         : $STATUS

Backup                 : ${BACKUP:-None}

--------------------------------------------

PM2 COMMANDS

Start:
pm2 start $PROCESS_NAME

Stop:
pm2 stop $PROCESS_NAME

Restart:
pm2 restart $PROCESS_NAME

Delete:
pm2 delete $PROCESS_NAME

Status:
pm2 status

Live Logs:
pm2 logs $PROCESS_NAME

Save Processes:
pm2 save

--------------------------------------------

CONFIGURATION:
nano $CONFIG_PATH

--------------------------------------------

EOF

log "Atyro Daemon successfully installed with PM2!"
