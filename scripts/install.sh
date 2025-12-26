#!/bin/bash

# Docker Auto-Start CLI Installation Script
# Works on macOS and Linux

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO="sundaram2021/docker-autostart-cli"
BINARY_NAME="docker-autostart"
INSTALL_DIR="/usr/local/bin"

# Functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo "ℹ $1"
}

# Detect platform
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case $OS in
        darwin)
            OS="darwin"
            ;;
        linux)
            OS="linux"
            ;;
        *)
            print_error "Unsupported operating system: $OS"
            ;;
    esac

    case $ARCH in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            ;;
    esac

    print_success "Detected platform: $OS-$ARCH"
}

# Get latest release version
get_latest_version() {
    print_info "Fetching latest release..."
    VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"tag_name": ?"([^"]+)".*/\1/')
    
    if [ -z "$VERSION" ]; then
        print_error "Failed to fetch latest version"
    fi
    
    print_success "Latest version: $VERSION"
}

# Download binary
download_binary() {
    FILENAME="${BINARY_NAME}-${OS}-${ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/$FILENAME"
    
    print_info "Downloading from: $DOWNLOAD_URL"
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download
    if command -v curl >/dev/null 2>&1; then
        curl -L -o "$FILENAME" "$DOWNLOAD_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -O "$FILENAME" "$DOWNLOAD_URL"
    else
        print_error "Neither curl nor wget is available"
    fi
    
    # Extract
    tar -xzf "$FILENAME"
    
    if [ ! -f "$BINARY_NAME" ]; then
        print_error "Binary not found in archive"
    fi
    
    # Make executable
    chmod +x "$BINARY_NAME"
}

# Install binary
install_binary() {
    print_info "Installing to $INSTALL_DIR..."
    
    # Check if installation directory exists and is writable
    if [ ! -d "$INSTALL_DIR" ]; then
        print_error "Installation directory $INSTALL_DIR does not exist"
    fi
    
    if [ ! -w "$INSTALL_DIR" ]; then
        print_error "No write permission to $INSTALL_DIR. Try running with sudo."
    fi
    
    # Move binary
    mv "$BINARY_NAME" "$INSTALL_DIR/docker"
    
    # Verify installation
    if [ ! -f "$INSTALL_DIR/docker" ]; then
        print_error "Installation failed"
    fi
}

# Create symbolic link for original docker (if exists)
create_symlink() {
    if command -v docker >/dev/null 2>&1; then
        ORIGINAL_DOCKER=$(which docker)
        if [ "$ORIGINAL_DOCKER" != "$INSTALL_DIR/docker" ]; then
            print_warning "Original docker found at $ORIGINAL_DOCKER"
            print_info "Creating symbolic link for original docker"
            ln -sf "$ORIGINAL_DOCKER" "$INSTALL_DIR/docker-original"
            print_success "Original docker available as 'docker-original'"
        fi
    fi
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    # Check if docker command works
    if docker --help >/dev/null 2>&1; then
        print_success "Installation successful!"
    else
        print_error "Installation verification failed"
    fi
}

# Cleanup
cleanup() {
    if [ -n "$TMP_DIR" ] && [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

# Main installation flow
main() {
    print_info "Installing Docker Auto-Start CLI..."
    
    detect_platform
    get_latest_version
    download_binary
    install_binary
    create_symlink
    verify_installation
    
    print_success "Docker Auto-Start CLI has been installed successfully!"
    echo
    print_info "Usage:"
    echo "  docker ps                    # Show running containers"
    echo "  docker -v ps                  # Verbose mode"
    echo "  docker -q --timeout 300 run   # Quiet mode with 5min timeout"
    echo "  docker --help                 # Show all options"
    echo
    print_info "Uninstall:"
    echo "  sudo rm /usr/local/bin/docker"
    echo "  sudo rm /usr/local/bin/docker-original  # if exists"
    echo
    print_warning "Please consider giving this project a star on GitHub!"
    print_warning "https://github.com/$REPO"
}

# Trap cleanup
trap cleanup EXIT

# Run main function
main "$@"