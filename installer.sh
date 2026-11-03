#!/usr/bin/env bash
#
# Atyro Daemon Installer
# Repo   : https://github.com/atyrolabs/daemon
# Default install dir : /etc/atyro/
# Default service     : atyro-daemon
#
set -euo pipefail

# ---------- Colors ----------
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; BOLD=$'\033[1m'; NC=$'\033[0m'

log()   { echo -e "${GREEN}[OK]${NC} $*"; }
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR]${NC} $*" >&2; }
title() { echo -e "\n${BOLD}${CYAN}== $* ==${NC}\n"; }

# ---------- Must be root ----------
if [[ $EUID -ne 0 ]]; then
  err "Root/sudo ke saath chalao:  sudo bash $0"
  exit 1
fi

# ---------- Defaults ----------
DEFAULT_DIR="/etc/atyro"
DEFAULT_REPO="https://github.com/atyrolabs/daemon"
DEFAULT_BRANCH="main"
DEFAULT_SERVICE="atyro-daemon"
DEFAULT_PANEL_URL="http://localhost:3000"
DEFAULT_NODE_ID="1"
DEFAULT_TOKEN="0d5K9voC7l5__8Cin3epjbg6FhhR1IJpQsHLVWpieFE"
DEFAULT_PORT="8787"
DEFAULT_BIND="0.0.0.0"

# ---------- Helper: prompt with default ----------
ask() {
  # $1=prompt, $2=default, $3=var name (via nameref)
  local prompt="$1" def="$2" __var="$3" reply
  if [[ -n "$def" ]]; then
    read -rp "$(echo -e "${CYAN}?${NC} ${prompt} [${BOLD}${def}${NC}]: ")" reply || true
    reply="${reply:-$def}"
  else
    read -rp "$(echo -e "${CYAN}?${NC} ${prompt}: ")" reply || true
  fi
  printf -v "$__var" '%s' "$reply"
}

ask_yn() {
  # $1=prompt, $2=default(y/n) -> returns 0 yes, 1 no
  local prompt="$1" def="${2:-y}" reply
  read -rp "$(echo -e "${CYAN}?${NC} ${prompt} [$([[ $def == y ]] && echo 'Y/n' || echo 'y/N')]: ")" reply || true
  reply="${reply:-$def}"
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ---------- Banner ----------
clear || true
echo -e "${BOLD}${CYAN}"
cat <<'EOF'
   ___   _____ __   __ ____   ___    ____    _    __  __ _____ _   _
  / _ \ |_   _\ \ / /|  _ \ / _ \  |  _ \  / \  |  \/  | ____| \ | |
 / /_\ \  | |  \ V / | |_) | | | | | | | |/ _ \ | |\/| |  _| |  \| |
 |  _  |  | |   | |  |  _ <| |_| | | |_| / ___ \| |  | | |___| |\  |
 |_| |_|  |_|   |_|  |_| \_\\___/  |____/_/   \_\_|  |_|_____|_| \_|
                                                                    Installer
EOF
echo -e "${NC}"
info "Atyro Daemon install shuru ho raha hai..."
echo

# ---------- Gather inputs (sab default ke saath) ----------
title "Installation Settings (Enter dabao default ke liye)"

ask "Installation directory"                     "$DEFAULT_DIR"      INSTALL_DIR
ask "Git repository URL"                         "$DEFAULT_REPO"     REPO_URL
ask "Git branch"                                 "$DEFAULT_BRANCH"   BRANCH
ask "Systemd service name"                       "$DEFAULT_SERVICE"  SERVICE_NAME
ask "Panel URL (panelUrl)"                       "$DEFAULT_PANEL_URL" PANEL_URL
ask "Node ID (nodeId)"                           "$DEFAULT_NODE_ID"  NODE_ID
ask "Token"                                      "$DEFAULT_TOKEN"    TOKEN
ask "Port"                                       "$DEFAULT_PORT"     PORT
ask "Bind host (bindHost)"                       "$DEFAULT_BIND"     BIND_HOST

echo
title "Confirm"
cat <<EOF
  Directory      : ${INSTALL_DIR}
  Repo           : ${REPO_URL}  (branch: ${BRANCH})
  Service        : ${SERVICE_NAME}
  Panel URL      : ${PANEL_URL}
  Node ID        : ${NODE_ID}
  Token          : ${TOKEN:0:8}...${TOKEN: -6}
  Port           : ${PORT}
  Bind host      : ${BIND_HOST}
EOF
echo

if ! ask_yn "Aage badhein? (install shuru karein)" "y"; then
  warn "Cancel kar diya. Kuch change nahi hua."
  exit 0
fi

# ---------- Pre-flight deps ----------
title "Dependencies check"
need_pkgs=()
command -v git    >/dev/null 2>&1 || need_pkgs+=("git")
command -v curl   >/dev/null 2>&1 || need_pkgs+=("curl")
command -v unzip  >/dev/null 2>&1 || need_pkgs+=("unzip")
command -v node   >/dev/null 2>&1 || need_pkgs+=("nodejs")

if ((${#need_pkgs[@]})); then
  info "Install ho rahe hain: ${need_pkgs[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y "${need_pkgs[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "${need_pkgs[@]}"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "${need_pkgs[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    pacman -Sy --noconfirm "${need_pkgs[@]}"
  else
    err "Package manager detect nahi hua. Manually install karo: ${need_pkgs[*]}"
    exit 1
  fi
fi
log "Dependencies ready."

# ---------- Prepare install dir ----------
title "Preparing ${INSTALL_DIR}"
mkdir -p "$INSTALL_DIR"

# Backup if exists
if [[ -d "$INSTALL_DIR/.git" || -n "$(ls -A "$INSTALL_DIR" 2>/dev/null || true)" ]]; then
  BACKUP="${INSTALL_DIR}.bak.$(date +%Y%m%d-%H%M%S)"
  warn "Purana content mila. Backup ban raha hai: ${BACKUP}"
  cp -a "$INSTALL_DIR" "$BACKUP"
fi

# ---------- Clone repo ----------
title "Cloning repository"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  info "Already git repo. Fetch + reset kar rahe hain."
  git -C "$INSTALL_DIR" fetch --all --prune
  git -C "$INSTALL_DIR" checkout "$BRANCH"
  git -C "$INSTALL_DIR" reset --hard "origin/$BRANCH"
else
  rm -rf "${INSTALL_DIR:?}"/*
  rm -rf "${INSTALL_DIR:?}"/.[!.]* 2>/dev/null || true
  git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi
log "Repo ready: ${INSTALL_DIR}"

# ---------- daemon.zip ----------
title "daemon.zip handle kar rahe hain"
ZIP_PATH=""
for cand in \
  "${INSTALL_DIR}/daemon.zip" \
  "${INSTALL_DIR}/dist/daemon.zip" \
  "${INSTALL_DIR}/build/daemon.zip" \
  "$(pwd)/daemon.zip"; do
  if [[ -f "$cand" ]]; then ZIP_PATH="$cand"; break; fi
done

if [[ -n "$ZIP_PATH" ]]; then
  info "Mil gaya: $ZIP_PATH  ->  unzip into ${INSTALL_DIR}"
  unzip -o "$ZIP_PATH" -d "$INSTALL_DIR" >/dev/null
  log "daemon.zip unzip ho gaya."
else
  # try GitHub release download as fallback
  warn "daemon.zip local mein nahi mila. GitHub release se try kar rahe hain..."
  REL_URL="https://github.com/atyrolabs/daemon/releases/latest/download/daemon.zip"
  if curl -fsSL "$REL_URL" -o "${INSTALL_DIR}/daemon.zip"; then
    unzip -o "${INSTALL_DIR}/daemon.zip" -d "$INSTALL_DIR" >/dev/null
    log "Release se daemon.zip download + unzip ho gaya."
  else
    warn "daemon.zip nahi mila (na local, na release). Skip kar rahe hain."
  fi
fi

# ---------- config.json ----------
title "config.json likh rahe hain"
CONFIG_PATH="${INSTALL_DIR}/config.json"
cat > "$CONFIG_PATH" <<EOF
{
  "panelUrl": "${PANEL_URL}",
  "nodeId": ${NODE_ID},
  "token": "${TOKEN}",
  "port": ${PORT},
  "bindHost": "${BIND_HOST}"
}
EOF
chmod 600 "$CONFIG_PATH"
log "Config saved: ${CONFIG_PATH}"

# ---------- Auto-detect entrypoint ----------
title "Entry point detect kar rahe hain"
ENTRY=""
for f in daemon.js index.js server.js app.js main.js dist/daemon.js dist/index.js dist/server.js; do
  if [[ -f "${INSTALL_DIR}/${f}" ]]; then ENTRY="$f"; break; fi
done

if [[ -f "${INSTALL_DIR}/package.json" ]]; then
  info "package.json mila -> npm install kar rahe hain"
  if command -v npm >/dev/null 2>&1; then
    ( cd "$INSTALL_DIR" && npm install --omit=dev --no-audit --no-fund ) || \
      warn "npm install fail hua (optional)."
  else
    warn "npm available nahi hai, skip."
  fi
  if [[ -z "$ENTRY" ]]; then
    # try package.json main
    ENTRY="$(node -e 'try{const p=require(process.argv[1]);console.log(p.main||"")}catch(e){}' "${INSTALL_DIR}/package.json" 2>/dev/null || true)"
  fi
fi

[[ -z "$ENTRY" ]] && ENTRY="index.js"
log "Entry point: ${ENTRY}"

# ---------- Systemd service ----------
title "Systemd service create kar rahe hain"
NODE_BIN="$(command -v node || echo /usr/bin/node)"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Atyro Daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${NODE_BIN} ${INSTALL_DIR}/${ENTRY}
Restart=always
RestartSec=3
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null
systemctl restart "$SERVICE_NAME"

sleep 1.5
if systemctl is-active --quiet "$SERVICE_NAME"; then
  log "Service chalu: ${SERVICE_NAME}"
else
  err "Service start nahi hui. Logs dekho:  journalctl -u ${SERVICE_NAME} -n 100 --no-pager"
fi

# ---------- Summary ----------
title "Installation Complete 🎉"
cat <<EOF
  Install dir   : ${INSTALL_DIR}
  Config        : ${CONFIG_PATH}
  Entry point   : ${ENTRY}
  Service       : ${SERVICE_NAME}.service
  Panel URL     : ${PANEL_URL}
  Node ID       : ${NODE_ID}
  Port          : ${PORT}  (bind: ${BIND_HOST})

  Status        : $(systemctl is-active "$SERVICE_NAME")
  Start         : sudo systemctl start ${SERVICE_NAME}
  Stop          : sudo systemctl stop ${SERVICE_NAME}
  Restart       : sudo systemctl restart ${SERVICE_NAME}
  Logs          : journalctl -u ${SERVICE_NAME} -f
  Edit config   : sudo nano ${CONFIG_PATH}

EOF
log "Ho gaya bhai! 🚀"
