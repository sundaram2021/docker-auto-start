# Docker Auto-Start CLI

A simple Go CLI tool that automatically starts Docker Desktop when you run docker commands(You don't need to start Docker Desktop manually anymore!).

## Problem Solved

Tired of manually starting Docker Desktop before running `docker ps`? This tool automatically starts Docker Desktop if it's not running, then executes your docker command seamlessly.

## Quick Install

### Windows
```powershell
iwr -useb https://raw.githubusercontent.com/sundaram2021/docker-autostart-cli/main/scripts/install-windows.ps1 | iex
```

### macOS/Linux
```bash
curl -fsSL https://raw.githubusercontent.com/sundaram2021/docker-autostart-cli/main/scripts/install.sh | sh
```

## Usage

Use it exactly like regular docker:

```bash
# Starts Docker Desktop if needed, then shows containers
docker ps

# Run a container
docker run hello-world

# Verbose mode
docker -v ps

# Quiet mode
docker -q images

# Help
docker --help
```

## Manual Installation

1. Download the latest release from [GitHub Releases](https://github.com/sundaram2021/docker-autostart-cli/releases)
2. Extract and add to your PATH
3. Rename to `docker` (optional)

## Build from Source

```bash
git clone https://github.com/sundaram2021/docker-autostart-cli.git
cd docker-autostart-cli
go build -o docker main.go
```

## Features

- ✅ Automatic Docker Desktop detection
- ✅ Cross-platform (Windows, macOS, Linux)  
- ✅ Verbose and quiet modes
- ✅ Configurable timeout
- ✅ Drop-in replacement for docker
- ✅ Minimal overhead when Docker is running
- ✅ Auto-shutdown after 10 minutes of inactivity
- ✅ Smart resource management

## Options

- `-v`: Verbose output
- `-q`: Quiet mode  
- `-timeout N`: Timeout in seconds (default: 120)
- `-auto-shutdown`: Auto-shutdown Docker Desktop after 10 minutes of inactivity (default: true)

## Contributing

1. Fork the repository
2. Make your changes
3. Add tests
4. Run `go test -v ./...`
5. Submit a pull request

## License

MIT License - see [LICENSE](LICENSE) file.

---

**If this helps you, please give it a star! ⭐**