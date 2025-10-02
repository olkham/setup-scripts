#!/bin/bash

# Script to install Python 3.11+ using pyenv on Ubuntu 20.04
# This is an alternative when deadsnakes PPA doesn't work

set -e  # Exit on any error

echo "🐍 Installing Python 3.11+ via pyenv on Ubuntu..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user."
   exit 1
fi

# Update package list
print_status "Updating package list..."
sudo apt update

# Install dependencies for building Python
print_status "Installing build dependencies for Python..."
sudo apt install -y \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    curl \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    python3-openssl \
    git

# Check if pyenv is already installed
if [ -d "$HOME/.pyenv" ]; then
    print_warning "pyenv is already installed at $HOME/.pyenv"
    print_status "Updating pyenv..."
    cd "$HOME/.pyenv" && git pull
else
    # Install pyenv
    print_status "Installing pyenv..."
    curl https://pyenv.run | bash
fi

# Setup environment variables
BASHRC="$HOME/.bashrc"
PYENV_ROOT="$HOME/.pyenv"

# Add pyenv to PATH if not already there
if ! grep -q 'PYENV_ROOT' "$BASHRC"; then
    print_status "Adding pyenv to ~/.bashrc..."
    echo '' >> "$BASHRC"
    echo '# Pyenv configuration' >> "$BASHRC"
    echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$BASHRC"
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "$BASHRC"
    echo 'eval "$(pyenv init -)"' >> "$BASHRC"
fi

# Source the changes
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Update pyenv
print_status "Updating pyenv and Python build definitions..."
pyenv update || true

# Check available Python versions
print_status "Checking available Python versions..."
AVAILABLE_VERSIONS=$(pyenv install --list | grep -E "^\s+3\.(11|12|13)\." | grep -v "[a-zA-Z]" | tail -3)
echo "Latest stable versions available:"
echo "$AVAILABLE_VERSIONS"

# Get the latest 3.11 version
PYTHON_VERSION=$(pyenv install --list | grep -E "^\s+3\.11\." | grep -v "[a-zA-Z]" | tail -1 | tr -d ' ')

if [ -z "$PYTHON_VERSION" ]; then
    print_error "Could not find Python 3.11 in pyenv. Trying 3.12..."
    PYTHON_VERSION=$(pyenv install --list | grep -E "^\s+3\.12\." | grep -v "[a-zA-Z]" | tail -1 | tr -d ' ')
fi

if [ -z "$PYTHON_VERSION" ]; then
    print_error "Could not find suitable Python version. Please install manually."
    print_error "List available versions with: pyenv install --list"
    exit 1
fi

print_status "Installing Python $PYTHON_VERSION (this may take several minutes)..."
pyenv install -s "$PYTHON_VERSION"

# Set as global default
print_status "Setting Python $PYTHON_VERSION as global default..."
pyenv global "$PYTHON_VERSION"

# Create convenient aliases in ~/.local/bin
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

print_status "Creating convenient command aliases..."
rm -f "$LOCAL_BIN/python" "$LOCAL_BIN/pip"

# Create wrapper scripts
cat > "$LOCAL_BIN/python" << 'EOF'
#!/bin/bash
eval "$(pyenv init -)"
exec python "$@"
EOF

cat > "$LOCAL_BIN/pip" << 'EOF'
#!/bin/bash
eval "$(pyenv init -)"
exec pip "$@"
EOF

chmod +x "$LOCAL_BIN/python" "$LOCAL_BIN/pip"

# Add ~/.local/bin to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    if ! grep -q "export PATH=\"\$HOME/.local/bin:\$PATH\"" "$BASHRC"; then
        print_status "Adding ~/.local/bin to PATH in ~/.bashrc..."
        echo "" >> "$BASHRC"
        echo "# Add local bin to PATH" >> "$BASHRC"
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$BASHRC"
    fi
fi

# Verify installation
print_status "Verifying installation..."
echo ""

# Initialize pyenv for current shell
eval "$(pyenv init -)"

# Check Python version
if command -v python &> /dev/null; then
    INSTALLED_PYTHON_VERSION=$(python --version 2>&1)
    print_status "✅ Python installed: $INSTALLED_PYTHON_VERSION"
    print_status "   Command: $(which python)"
else
    print_error "❌ Python command not found in current shell"
fi

# Check pip version
if command -v pip &> /dev/null; then
    INSTALLED_PIP_VERSION=$(pip --version 2>&1 | head -1)
    print_status "✅ Pip installed: $INSTALLED_PIP_VERSION"
    print_status "   Command: $(which pip)"
else
    print_error "❌ Pip command not found in current shell"
fi

# Check pyenv
if command -v pyenv &> /dev/null; then
    PYENV_VERSION=$(pyenv --version 2>&1)
    print_status "✅ Pyenv installed: $PYENV_VERSION"
else
    print_warning "⚠️  Pyenv not in PATH for current shell"
fi

echo ""
print_status "🎉 Installation complete!"
print_status ""
print_status "IMPORTANT: Close and reopen your terminal, or run:"
print_status "  source ~/.bashrc"
print_status ""
print_status "After that, test with:"
print_status "  python --version"
print_status "  pip --version"
print_status "  pyenv versions"
print_status ""
print_status "Commands available:"
print_status "  python    -> Python $PYTHON_VERSION (via pyenv)"
print_status "  pip       -> pip for Python $PYTHON_VERSION"
print_status "  pyenv     -> Manage Python versions"
print_status ""
print_status "To install additional Python versions:"
print_status "  pyenv install 3.12.0    # Install Python 3.12"
print_status "  pyenv global 3.12.0     # Set as default"
print_status "  pyenv versions          # List installed versions"
print_status ""
print_status "To create virtual environments:"
print_status "  python -m venv myenv"
print_status "  source myenv/bin/activate"

echo ""
print_warning "Note: You MUST restart your terminal or run 'source ~/.bashrc' for the changes to take effect."
