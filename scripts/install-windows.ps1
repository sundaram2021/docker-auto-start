#!/usr/bin/env pwsh

# Docker Auto-Start CLI Installation Script
# Works on Windows

param(
    [switch]$Force,
    [string]$InstallDir = "$env:LOCALAPPDATA\Programs\docker-autostart"
)

# Colors for output
$colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    White = "White"
}

# Functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $colors.Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $colors.Red
    exit 1
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $colors.Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $colors.White
}

# Check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Detect platform
function Get-PlatformInfo {
    $os = "windows"
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") { "amd64" } else { "arm64" }
    
    Write-Success "Detected platform: $os-$arch"
    return @{ OS = $os; Arch = $arch }
}

# Get latest release version
function Get-LatestVersion {
    param([string]$Repo)
    
    Write-Info "Fetching latest release..."
    
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest"
        $version = $response.tag_name
        
        if ([string]::IsNullOrEmpty($version)) {
            Write-Error "Failed to fetch latest version"
        }
        
        Write-Success "Latest version: $version"
        return $version
    }
    catch {
        Write-Error "Failed to fetch latest version: $($_.Exception.Message)"
    }
}

# Download binary
function Download-Binary {
    param(
        [string]$Repo,
        [string]$Version,
        [hashtable]$Platform
    )
    
    $filename = "docker-autostart-$($Platform.OS)-$($Platform.Arch).zip"
    $downloadUrl = "https://github.com/$Repo/releases/download/$Version/$filename"
    
    Write-Info "Downloading from: $downloadUrl"
    
    # Create temporary directory
    $tmpDir = Join-Path $env:TEMP "docker-autostart-install"
    if (Test-Path $tmpDir) {
        Remove-Item $tmpDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    
    try {
        # Download file
        Invoke-WebRequest -Uri $downloadUrl -OutFile (Join-Path $tmpDir $filename)
        
        # Extract
        $extractPath = Join-Path $tmpDir "extracted"
        New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
        
        Expand-Archive -Path (Join-Path $tmpDir $filename) -DestinationPath $extractPath -Force
        
        $binaryPath = Join-Path $extractPath "docker-autostart-windows-amd64.exe"
        if (-not (Test-Path $binaryPath)) {
            Write-Error "Binary not found in archive"
        }
        
        return $binaryPath
    }
    catch {
        Write-Error "Failed to download or extract binary: $($_.Exception.Message)"
    }
}

# Install binary
function Install-Binary {
    param(
        [string]$BinaryPath,
        [string]$InstallDir
    )
    
    Write-Info "Installing to $InstallDir..."
    
    # Create installation directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    
    # Copy binary
    $targetPath = Join-Path $InstallDir "docker.exe"
    Copy-Item $BinaryPath $targetPath -Force
    
    if (-not (Test-Path $targetPath)) {
        Write-Error "Installation failed"
    }
    
    return $targetPath
}

# Add to PATH
function Add-ToPath {
    param([string]$InstallDir)
    
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    
    if ($currentPath -notlike "*$InstallDir*") {
        Write-Info "Adding to user PATH..."
        
        $newPath = $currentPath + ";" + $InstallDir
        [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
        
        # Update current session
        $env:PATH = $newPath
        
        Write-Success "Added to PATH. You may need to restart your terminal."
    } else {
        Write-Success "Already in PATH"
    }
}

# Create symbolic link for original docker (if exists)
function Create-Symlink {
    param([string]$InstallDir)
    
    try {
        $originalDocker = Get-Command docker -ErrorAction SilentlyContinue
        if ($originalDocker -and $originalDocker.Source -notlike "*$InstallDir*") {
            Write-Warning "Original docker found at $($originalDocker.Source)"
            Write-Info "Creating copy for original docker"
            
            $originalPath = Join-Path $InstallDir "docker-original.exe"
            Copy-Item $originalDocker.Source $originalPath -Force
            Write-Success "Original docker available as 'docker-original'"
        }
    }
    catch {
        Write-Warning "Could not create backup of original docker"
    }
}

# Verify installation
function Verify-Installation {
    param([string]$InstallDir)
    
    Write-Info "Verifying installation..."
    
    # Refresh PATH
    $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "User")
    
    try {
        # Add installation directory to PATH for current session
        $env:PATH = $InstallDir + ";" + $env:PATH
        
        $result = & docker --help 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Installation successful!"
        } else {
            Write-Error "Installation verification failed"
        }
    }
    catch {
        Write-Error "Installation verification failed: $($_.Exception.Message)"
    }
}

# Cleanup
function Cleanup {
    param([string]$TempDir)
    
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force
    }
}

# Main installation flow
function Main {
    param(
        [switch]$Force,
        [string]$InstallDir
    )
    
    Write-Info "Installing Docker Auto-Start CLI..."
    
    # Check if already installed
    $targetPath = Join-Path $InstallDir "docker.exe"
    if ((Test-Path $targetPath) -and -not $Force) {
        Write-Warning "Docker Auto-Start CLI is already installed"
        $choice = Read-Host "Do you want to reinstall? (y/N)"
        if ($choice -notmatch '^[Yy]') {
            Write-Info "Installation cancelled"
            exit 0
        }
    }
    
    # Configuration
    $repo = "sundaram2021/docker-autostart-cli"
    $tmpDir = Join-Path $env:TEMP "docker-autostart-install"
    
    try {
        $platform = Get-PlatformInfo
        $version = Get-LatestVersion -Repo $repo
        $binaryPath = Download-Binary -Repo $repo -Version $version -Platform $platform
        $installedPath = Install-Binary -BinaryPath $binaryPath -InstallDir $InstallDir
        Add-ToPath -InstallDir $InstallDir
        Create-Symlink -InstallDir $InstallDir
        Verify-Installation -InstallDir $InstallDir
        
        Write-Success "Docker Auto-Start CLI has been installed successfully!"
        Write-Host ""
        Write-Info "Usage:"
        Write-Host "  docker ps                    # Show running containers"
        Write-Host "  docker -v ps                  # Verbose mode"
        Write-Host "  docker -q --timeout 300 run   # Quiet mode with 5min timeout"
        Write-Host "  docker --help                 # Show all options"
        Write-Host ""
        Write-Info "Uninstall:"
        Write-Host "  Remove-Item '$InstallDir' -Recurse -Force"
        Write-Host "  Remove '$InstallDir' from your PATH environment variable"
        Write-Host ""
        Write-Warning "Please consider giving this project a star on GitHub!"
        Write-Warning "https://github.com/$repo"
    }
    finally {
        Cleanup -TempDir $tmpDir
    }
}

# Check prerequisites
if (-not (Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue)) {
    Write-Error "PowerShell is not available or missing required cmdlets"
}

# Run main function
Main -Force:$Force -InstallDir $InstallDir