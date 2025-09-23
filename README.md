# 🌀 Zen Manager

**Easily install, update, and manage [Zen Browser](https://zen-browser.app) on Linux.**  
With one script, you can install Zen for the first time, update to the latest release, or even switch to specific versions — all while keeping your system clean with `.deb` packaging.  

---

## ✨ Features

- 🚀 **One command to install Zen** on Debian/Ubuntu systems  
- 🔄 **Update to the latest release** directly from GitHub  
- 📦 **Builds proper `.deb` packages** for clean installs/uninstalls  
- 🎯 **Supports multiple CPU architectures** (`amd64`, `arm64`)  
- 🛠 **Interactive or fully automated** (use flags for scripting)  
- 🧹 Option to **keep or remove installer files** after use  
- 🔍 **Dependency pre-checks** to avoid build errors  
- 🐛 Debug mode for troubleshooting builds  

---

## 📦 Requirements

- Debian 10+ / Ubuntu 20.04+ (or derivatives: Mint, Pop!_OS, etc.)  
- `sudo` privileges  
- Internet connection  

---

## ⚙️ Installation

Clone this repository and make the script executable:  

```bash
git clone https://github.com/totallyfamousguy/zen-manager.git
cd zen-manager
chmod +x zen-manager.sh
```

---

## 🚀 Usage

Run the script with `sudo`:  

```bash
sudo ./zen-manager.sh
```

### Example runs:

- **Install or update Zen (interactive mode):**

```bash
sudo ./zen-manager.sh
```

- **Auto-install/update without prompts:**

```bash
sudo ./zen-manager.sh --yes
```

- **Install but keep `.deb` and tarball files:**

```bash
sudo ./zen-manager.sh --keep
```

- **Build with full logs for debugging:**

```bash
sudo ./zen-manager.sh --debug
```

- **Install a specific version (instead of latest):**

```bash
sudo ./zen-manager.sh --version-tag 1.15b
```

- **Show script version:**

```bash
./zen-manager.sh --version
```

- **Show help menu:**

```bash
./zen-manager.sh --help
```

---

## 📝 Available Flags

| Flag            | Description |
|-----------------|-------------|
| `--help`        | Show usage information |
| `--yes`         | Auto-confirm all prompts (non-interactive mode) |
| `--keep`        | Keep `.deb` and tarball files after execution |
| `--debug`       | Show verbose `dpkg-deb` build logs |
| `--version`     | Show script version |
| `--version-tag` | Install a specific Zen release (e.g. `1.15b`) |

---


## ⚠️ Notes

- This script is for **Debian/Ubuntu-based systems only**.  
- Must be run with **root privileges** (`sudo`).  
- Installs via `apt` for proper dependency handling.  
- If you don’t install immediately, the built `.deb` file will remain in your directory.  

---

## 🛠 Troubleshooting

- If dependencies are missing, the script will prompt you to install them.  
- Use `--debug` for detailed `.deb` build logs.  
- Run the script from a directory with write permissions (e.g. your home folder).  

---

## 📄 License

MIT License – free to use, modify, and share.  
