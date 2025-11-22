#!/bin/bash
set -e

echo "=== Docker + Compose installer for WSL ==="

# --- Prerequisites ---
echo ">>> Installing prerequisites..."
sudo apt-get update -y
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release jq

# --- Check if Docker is installed ---
if ! command -v docker &>/dev/null; then
  echo ">>> Docker not found, installing..."

  # Setup GPG key
  sudo install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  # Setup repo if not already present
  if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  fi

  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io

else
  echo ">>> Docker already installed: $(docker --version)"
fi

# --- Install Docker Compose ---
echo ">>> Checking Docker Compose..."
LATEST_COMPOSE=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
COMPOSE_PATH="/usr/local/bin/docker-compose"

if [ -x "$COMPOSE_PATH" ]; then
  INSTALLED_COMPOSE=$($COMPOSE_PATH version --short 2>/dev/null || echo "none")
  if [ "$INSTALLED_COMPOSE" = "$LATEST_COMPOSE" ]; then
    echo ">>> Docker Compose already up-to-date: v$INSTALLED_COMPOSE"
  else
    echo ">>> Updating Docker Compose to $LATEST_COMPOSE"
    sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE}/docker-compose-$(uname -s)-$(uname -m)" \
      -o $COMPOSE_PATH
    sudo chmod +x $COMPOSE_PATH
  fi
else
  echo ">>> Installing Docker Compose $LATEST_COMPOSE"
  sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE}/docker-compose-$(uname -s)-$(uname -m)" \
    -o $COMPOSE_PATH
  sudo chmod +x $COMPOSE_PATH
fi

# --- Ensure docker group ---
echo ">>> Ensuring user is in docker group"
sudo groupadd docker || true
sudo usermod -aG docker $USER

# --- Final check ---
echo
echo "=== Final check ==="
docker --version || echo "⚠️ Docker not detected (dockerd may not be running)"
docker-compose --version || echo "⚠️ Docker Compose not detected"

echo
echo "✅ Setup complete!"
echo "⚠️ Restart your WSL session or run: exec su - $USER"
echo "👉 To start Docker manually, run: sudo dockerd &"
