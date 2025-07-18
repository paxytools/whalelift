# 🐋 whalelift

**Whalelift** is a simple Bash CLI tool that safely upgrades Docker containers by name.  
It pulls the latest image, checks if it's different from the running one, and if so, re-creates the container with the same config.

> Think of it as a tiny "manual Watchtower" — but portable and scriptable.

## 📑 Table of Contents
- [Features](#-features)
- [Installation](#-installation)
- [Usage](#-usage)
- [Uninstallation](#️-uninstallation)
- [Notes](#-notes)
- [Roadmap](#-roadmap)
- [License](#-license)
- [Contributing](#-contributing)

---

## 🚀 Features

- 🔍 Detects if a new image is available
- 🔁 Stops, removes, and re-runs the container
- 🧪 Supports dry-run mode to preview without making changes
- 📦 Keeps environment, ports, volumes, and restart policy intact
- 🐚 Pure Bash — no dependencies beyond Docker CLI

---

## 📦 Installation

Install globally with `curl`:

```bash
sudo curl -sSL https://raw.githubusercontent.com/paxytools/whalelift/main/whalelift.sh \
  -o /usr/local/bin/whalelift && sudo chmod +x /usr/local/bin/whalelift
```

> **Note:** The same command can be used to upgrade whalelift to the latest version. It will overwrite the existing script with the latest version from the repository.

## 🧪 Usage

### Basic Usage

After installation, you can run whalelift from anywhere:

```bash
whalelift <container_name>
```

### Using Without Installation

You can use whalelift directly without installation with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/paxytools/whalelift/main/whalelift.sh | bash -s -- <container_name>
```

### Command Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without applying them |
| `--print-run` | Output the docker run command and exit |
| `--tag <tag>` | Use a specific image tag instead of latest |
| `--version` | Display the version of whalelift |
| `--help` | Show usage information |

Examples:

```bash
# Upgrade a specific container
whalelift my-app

# Specify a particular version tag
whalelift --tag 1.2.3 my-app

# Dry-run mode (preview without making changes)
whalelift --dry-run my-app

# Print the equivalent docker run command
whalelift --print-run my-app

# Check the installed version
whalelift --version
```

### Example Output

When you run whalelift, you'll see output similar to this:

```bash
🔍 Container: my-app
📦 Current Image: myregistry.com/app:latest
⬇️  Pulling image...
⚠️  New image detected. Preparing to upgrade...
🛑 Stopping container...
🧹 Removing container...
🚀 Recreating container...
✅ Upgrade complete: 'my-app' is now running the latest image.
```

When using the `--tag` option:

```bash
🔍 Container: my-app
📦 Current Image: myregistry.com/app:latest
🏷️  Target Image:  myregistry.com/app:1.2.3
⬇️  Pulling image...
⚠️  New image detected. Preparing to upgrade...
🛑 Stopping container...
🧹 Removing container...
🚀 Recreating container...
✅ Upgrade complete: 'my-app' is now running image with tag '1.2.3'.
```

The tool provides clear status updates throughout the upgrade process.


## 🗑️ Uninstallation

To uninstall whalelift, simply remove the script:

```bash
sudo rm /usr/local/bin/whalelift
```

## 📌 Notes

### Requirements
- Docker CLI must be installed and in your PATH
- You must have permissions to manage Docker containers

### Windows Users
- As whalelift is a Bash script, Windows users need to use a Bash environment:
  - [Windows Subsystem for Linux (WSL)](https://docs.microsoft.com/en-us/windows/wsl/install)
  - [Git Bash](https://gitforwindows.org/)
  - Docker Desktop's built-in terminal
- Installation and usage commands are the same once in a Bash environment

### Limitations
- Assumes containers were created via `docker run` (not Compose or Swarm)
- Networks, labels, and advanced flags are not yet supported
- Without the `--tag` option, the tool uses the container's current image tag

## 🛠 Roadmap

- Support multiple containers with --all
- Add config backup/export mode (--export)
- Add support for Docker Compose
- Background agent mode (whalelifter) — optional future daemon

## 📄 License

MIT License

## 🧰 Contributing

Pull requests welcome — especially for testing, shell portability, or new flags.
Feel free to contribute by submitting pull requests or opening issues directly in this GitHub repository.
