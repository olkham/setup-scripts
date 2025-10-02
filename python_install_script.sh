#!/bin/bash

# Script to install Python 3.11+ on Ubuntu without breaking the system Python
# Makes python and pip commands available alongside python3 and pip3
# Tested on WSL2 Ubuntu 22.04

set -e  # Exit on any error

echo "🐍 Installing Python 3.11+ on Ubuntu..."

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

# Install dependencies
print_status "Installing build dependencies..."

# Core dependencies that should be available on all systems
CORE_DEPS="software-properties-common build-essential libssl-dev libffi-dev libncurses5-dev libsqlite3-dev libreadline-dev wget curl"

# Optional dependencies that might not be available on WSL or minimal installations
OPTIONAL_DEPS="libtk8.6-dev libgdm-dev libdb4o-cil-dev libpcap-dev"

# Install core dependencies
sudo apt install -y $CORE_DEPS

# Try to install optional dependencies, but don't fail if they're not available
print_status "Installing optional build dependencies (may skip some on WSL)..."
for dep in $OPTIONAL_DEPS; do
    if apt-cache show "$dep" &> /dev/null; then
        print_status "Installing $dep..."
        sudo apt install -y "$dep" || print_warning "Failed to install $dep, continuing..."
    else
        print_warning "Package $dep not available, skipping..."
    fi
done

# Add deadsnakes PPA for newer Python versions
print_status "Adding deadsnakes PPA..."
if ! sudo add-apt-repository -y ppa:deadsnakes/ppa; then
    print_error "Failed to add deadsnakes PPA. Checking repository access..."
    exit 1
fi

print_status "Updating package list after adding PPA..."
if ! sudo apt update; then
    print_error "Failed to update package list. Check your internet connection and repository access."
    exit 1
fi

# Verify the PPA was added successfully by checking if any python3.1x packages are available
print_status "Verifying deadsnakes PPA packages are available..."

# First try to find packages with the regex pattern
AVAILABLE_PYTHONS=$(apt-cache search '^python3\.(11|12|13)$' 2>/dev/null | wc -l)

# If regex doesn't work, try simple search
if [ "$AVAILABLE_PYTHONS" -eq 0 ]; then
    AVAILABLE_PYTHONS=$(apt-cache search python3.11 python3.12 python3.13 2>/dev/null | grep -c "^python3\.1[123] ")
fi

# Check by looking for specific package names
if [ "$AVAILABLE_PYTHONS" -eq 0 ]; then
    for ver in 3.11 3.12 3.13; do
        if apt-cache show "python${ver}" &> /dev/null; then
            AVAILABLE_PYTHONS=$((AVAILABLE_PYTHONS + 1))
        fi
    done
fi

if [ "$AVAILABLE_PYTHONS" -eq 0 ]; then
    print_error "No Python 3.11+ packages found after adding deadsnakes PPA."
    print_error ""
    print_error "The deadsnakes PPA may not support your Ubuntu version ($(lsb_release -cs))."
    print_error "This is a known issue with older Ubuntu releases."
    print_error ""
    print_warning "Recommended solutions:"
    print_warning "  1. Upgrade to Ubuntu 22.04 or later (recommended)"
    print_warning "  2. Use pyenv to build Python from source:"
    print_warning "     curl https://pyenv.run | bash"
    print_warning "     pyenv install 3.11.9"
    print_warning "  3. Use Docker/containers with newer Python"
    print_warning "  4. Build from source: https://www.python.org/downloads/"
    print_error ""
    print_error "Exiting installation."
    exit 1
fi

# Check for conflicting Python installations and clean them up
print_status "Checking for conflicting Python installations..."
if dpkg -l | grep -q "python3.11.*rc"; then
    print_warning "Found conflicting Python 3.11 release candidate installation. Cleaning up..."
    
    # Fix any broken package states first
    sudo apt --fix-broken install -y || true
    
    # Remove conflicting Python 3.11 packages
    print_status "Removing conflicting Python 3.11 packages..."
    sudo apt remove -y python3.11 python3.11-minimal libpython3.11-stdlib libpython3.11-minimal 2>/dev/null || true
    sudo apt purge -y python3.11 python3.11-minimal libpython3.11-stdlib libpython3.11-minimal 2>/dev/null || true
    
    # Clean up any remaining issues
    sudo apt autoremove -y
    sudo apt autoclean
    
    # Update package list again
    sudo apt update
fi

# Check available Python versions and install the latest 3.11+
print_status "Checking available Python versions..."
AVAILABLE_VERSIONS=""
for ver in 3.13 3.12 3.11; do
    if apt-cache show "python${ver}" &> /dev/null; then
        AVAILABLE_VERSIONS="${ver} ${AVAILABLE_VERSIONS}"
    fi
done

if [ -z "$AVAILABLE_VERSIONS" ]; then
    print_error "No Python 3.11+ versions available in repositories."
    print_error "Please check:"
    print_error "  1. Internet connection"
    print_error "  2. Run: apt-cache policy python3.11"
    print_error "  3. Run: sudo apt update && sudo apt-cache search python3.11"
    exit 1
fi

# Get the highest available version
PYTHON_VERSION=$(echo "$AVAILABLE_VERSIONS" | awk '{print $1}')
print_status "Found available Python versions: $AVAILABLE_VERSIONS"
print_status "Will install Python ${PYTHON_VERSION}"

print_status "Installing Python${PYTHON_VERSION}..."
# Try to fix any broken dependencies first
sudo apt --fix-broken install -y || true

# Verify packages exist before attempting installation
for pkg in python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv; do
    if ! apt-cache show "$pkg" &> /dev/null; then
        print_error "Package $pkg not found in repositories!"
        print_error "Run 'apt-cache search python${PYTHON_VERSION}' to see available packages."
        exit 1
    fi
done

# Install Python with error handling
if ! sudo apt install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv; then
    print_warning "Standard installation failed. Trying alternative approach..."
    
    # Force overwrite conflicting files if necessary
    if ! sudo apt install -y --reinstall python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv; then
        print_error "Failed to install Python${PYTHON_VERSION}. Attempting final recovery..."
        sudo dpkg --configure -a
        sudo apt --fix-broken install -y
        if ! sudo apt install -y python${PYTHON_VERSION} python${PYTHON_VERSION}-dev python${PYTHON_VERSION}-venv; then
            print_error "All installation attempts failed."
            print_error "Please check the error messages above and try:"
            print_error "  1. sudo apt update"
            print_error "  2. apt-cache policy python${PYTHON_VERSION}"
            print_error "  3. Check internet connection and repository access"
            exit 1
        fi
    fi
fi

# Install pip for the new Python version
print_status "Installing pip for Python${PYTHON_VERSION}..."
sudo apt install -y python${PYTHON_VERSION}-distutils
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python${PYTHON_VERSION} get-pip.py --user
rm get-pip.py

# Get the user's local bin directory
LOCAL_BIN="$HOME/.local/bin"
BASHRC="$HOME/.bashrc"

# Create local bin directory if it doesn't exist
mkdir -p "$LOCAL_BIN"

# Create symlinks for python and pip commands
print_status "Creating convenient command aliases..."

# Remove existing symlinks if they exist
rm -f "$LOCAL_BIN/python" "$LOCAL_BIN/pip"

# Create new symlinks
ln -s "/usr/bin/python${PYTHON_VERSION}" "$LOCAL_BIN/python"
ln -s "$HOME/.local/bin/pip${PYTHON_VERSION}" "$LOCAL_BIN/pip"

# Add ~/.local/bin to PATH if not already there
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    print_status "Adding ~/.local/bin to PATH in ~/.bashrc..."
    echo "" >> "$BASHRC"
    echo "# Add local bin to PATH for custom Python installation" >> "$BASHRC"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$BASHRC"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Verify installation
print_status "Verifying installation..."
echo ""

# Source bashrc to get updated PATH
export PATH="$HOME/.local/bin:$PATH"

# Check Python version
if command -v python &> /dev/null; then
    INSTALLED_PYTHON_VERSION=$(python --version 2>&1)
    print_status "✅ Python installed: $INSTALLED_PYTHON_VERSION"
    print_status "   Command: $(which python)"
else
    print_error "❌ Python command not found"
fi

# Check pip version
if command -v pip &> /dev/null; then
    INSTALLED_PIP_VERSION=$(pip --version 2>&1)
    print_status "✅ Pip installed: $INSTALLED_PIP_VERSION"
    print_status "   Command: $(which pip)"
else
    print_error "❌ Pip command not found"
fi

# Check system Python is still intact
if command -v python3 &> /dev/null; then
    SYSTEM_PYTHON_VERSION=$(python3 --version 2>&1)
    print_status "✅ System Python3 intact: $SYSTEM_PYTHON_VERSION"
else
    print_warning "⚠️  System python3 command not found (this might be normal)"
fi

echo ""
print_status "🎉 Installation complete!"
print_status ""
print_status "Next steps:"
print_status "1. Close and reopen your terminal, or run: source ~/.bashrc"
print_status "2. Test with: python --version && pip --version"
print_status ""
print_status "Commands available:"
print_status "  python    -> Python ${PYTHON_VERSION}"
print_status "  pip       -> pip for Python ${PYTHON_VERSION}"
print_status "  python3   -> System Python (unchanged)"
print_status "  pip3      -> System pip (unchanged)"
print_status ""
print_status "To create virtual environments:"
print_status "  python -m venv myenv"
print_status "  source myenv/bin/activate"

echo ""
print_warning "Note: You may need to restart your terminal or run 'source ~/.bashrc' for the new commands to work."
