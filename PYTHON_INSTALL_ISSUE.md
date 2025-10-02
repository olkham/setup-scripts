# Python Installation Issue on Ubuntu 20.04

## Problem

The error you're experiencing occurs because **the deadsnakes PPA for Ubuntu 20.04 (focal) is empty or deprecated**. The PPA repository exists and can be added, but it contains no packages for Python 3.11+.

### Evidence

When checking the repository directly:
```bash
curl -s "http://ppa.launchpad.net/deadsnakes/ppa/ubuntu/dists/focal/main/binary-amd64/Packages.gz" | gunzip
# Returns empty/nearly empty file (20 bytes)
```

This explains why:
- `apt update` succeeds (repository metadata exists)
- Package searches fail (no packages in repository)
- Installation fails with "Unable to locate package python3.11"

## Solutions

### Option 1: Use Pyenv (Recommended for Ubuntu 20.04)

Use the provided `python_install_pyenv.sh` script:

```bash
bash python_install_pyenv.sh
```

**Advantages:**
- Works on Ubuntu 20.04
- Allows multiple Python versions side-by-side
- No system Python conflicts
- Easy version switching
- Active maintenance

**What it does:**
- Installs pyenv (Python version manager)
- Builds Python 3.11+ from source
- Sets up convenient `python` and `pip` commands
- No sudo required for Python management

**After installation:**
```bash
source ~/.bashrc        # Reload shell configuration
python --version        # Should show Python 3.11+
pip --version          # Should show pip for Python 3.11+
pyenv versions         # List all installed versions
```

### Option 2: Upgrade Ubuntu (Best Long-term Solution)

Upgrade to Ubuntu 22.04 LTS or later:

```bash
# Backup your data first!
sudo do-release-upgrade
```

**Advantages:**
- Official LTS support
- Newer package versions
- Better security updates
- deadsnakes PPA works properly

**Ubuntu 22.04 comes with:**
- Python 3.10 by default
- Working deadsnakes PPA for 3.11+

### Option 3: Use Docker

Run Python in containers:

```bash
docker run -it python:3.11 bash
```

**Advantages:**
- Isolated environment
- Easy to manage
- Works on any Ubuntu version

**Disadvantages:**
- Requires Docker knowledge
- Additional overhead
- Not always suitable for development

### Option 4: Build from Source (Manual)

Download and compile Python manually:

```bash
# Install dependencies
sudo apt install -y build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev \
    liblzma-dev python3-openssl git

# Download Python
wget https://www.python.org/ftp/python/3.11.9/Python-3.11.9.tgz
tar -xzf Python-3.11.9.tgz
cd Python-3.11.9

# Configure and build
./configure --enable-optimizations --prefix=$HOME/.local
make -j$(nproc)
make install

# Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Disadvantages:**
- Time consuming (20-30 minutes)
- Manual updates required
- More complex troubleshooting

## Recommendation

For Ubuntu 20.04, **use Option 1 (pyenv)** - it's the most practical solution that:
- Works immediately
- Requires no OS upgrade
- Provides version management
- Is actively maintained

For new installations or long-term, **upgrade to Ubuntu 22.04 LTS** for better package support and security updates.

## Why the Original Script Failed

The `python_install_script.sh` assumed the deadsnakes PPA would contain packages for all Ubuntu versions. However:

1. Ubuntu 20.04 (focal) reached standard support end in April 2025
2. The deadsnakes maintainers may have stopped updating focal packages
3. The repository structure exists but contains no actual packages

The script has now been updated to detect this condition and provide helpful error messages with alternatives.

## Verification Commands

Check if Python 3.11 is available in your repositories:
```bash
apt-cache show python3.11
# If this returns "Unable to locate package", Python 3.11 is not available
```

Check deadsnakes PPA status:
```bash
apt-cache search python3.11
# Should return packages if PPA is working
```

Check Ubuntu version:
```bash
lsb_release -a
# Shows your Ubuntu version and codename
```

## Next Steps

1. **Use pyenv** (fastest solution):
   ```bash
   bash python_install_pyenv.sh
   source ~/.bashrc
   python --version
   ```

2. **Or upgrade Ubuntu** (recommended long-term):
   ```bash
   # Backup first!
   sudo do-release-upgrade
   ```

## Additional Resources

- [Pyenv documentation](https://github.com/pyenv/pyenv)
- [Python official downloads](https://www.python.org/downloads/)
- [Ubuntu release cycle](https://ubuntu.com/about/release-cycle)
- [Deadsnakes PPA on Launchpad](https://launchpad.net/~deadsnakes/+archive/ubuntu/ppa)
