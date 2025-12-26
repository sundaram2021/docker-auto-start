package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"syscall"
	"time"
)

var (
	verbose = flag.Bool("v", false, "Verbose output")
	quiet   = flag.Bool("q", false, "Quiet mode")
	timeout = flag.Int("timeout", 120, "Timeout in seconds for Docker to start")
)

func main() {
	flag.Parse()

	if len(flag.Args()) < 1 {
		fmt.Fprintf(os.Stderr, "Usage: docker-autostart [options] <docker-command> [args...]\n")
		fmt.Fprintf(os.Stderr, "Example: docker-autostart ps\n")
		fmt.Fprintf(os.Stderr, "Options:\n")
		flag.PrintDefaults()
		os.Exit(1)
	}

	// Check if Docker Desktop is running
	if !isDockerDesktopRunning() {
		if !*quiet {
			fmt.Println("Docker Desktop is not running. Starting it...")
		}

		if err := startDockerDesktop(); err != nil {
			fmt.Fprintf(os.Stderr, "Failed to start Docker Desktop: %v\n", err)
			os.Exit(1)
		}

		// Wait for Docker to be ready
		if !*quiet {
			fmt.Printf("Waiting for Docker to be ready (timeout: %ds)...\n", *timeout)
		}

		if !waitForDocker(*timeout) {
			fmt.Fprintf(os.Stderr, "Docker failed to start within %d seconds\n", *timeout)
			os.Exit(1)
		}

		if !*quiet {
			fmt.Println("Docker is ready!")
		}
	} else if *verbose {
		fmt.Println("Docker Desktop is already running")
	}

	// Execute the docker command with all arguments
	executeDockerCommand(flag.Args())
}

// isDockerDesktopRunning checks if Docker Desktop is running
func isDockerDesktopRunning() bool {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "windows":
		// More robust Windows detection using PowerShell
		cmd = exec.Command("powershell", "-Command", "Get-Process 'Docker Desktop' -ErrorAction SilentlyContinue")
	case "darwin":
		cmd = exec.Command("pgrep", "-f", "Docker Desktop")
	case "linux":
		cmd = exec.Command("pgrep", "-f", "docker-desktop")
	default:
		return false
	}

	output, err := cmd.Output()
	if err != nil {
		if *verbose {
			fmt.Printf("Debug: Error checking Docker Desktop: %v\n", err)
		}
		return false
	}

	running := len(strings.TrimSpace(string(output))) > 0
	if *verbose {
		fmt.Printf("Debug: Docker Desktop running: %v\n", running)
	}
	return running
}

// startDockerDesktop starts Docker Desktop
func startDockerDesktop() error {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "windows":
		// Enhanced Windows detection with more paths and better error handling
		paths := []string{
			`C:\Program Files\Docker\Docker\Docker Desktop.exe`,
			`C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe`,
			`%LOCALAPPDATA%\Programs\Docker\Docker\Docker Desktop.exe`,
		}

		var dockerPath string
		for _, path := range paths {
			// Expand environment variables
			expandedPath := os.ExpandEnv(path)
			if _, err := os.Stat(expandedPath); err == nil {
				dockerPath = expandedPath
				if *verbose {
					fmt.Printf("Debug: Found Docker Desktop at: %s\n", dockerPath)
				}
				break
			}
		}

		if dockerPath == "" {
			// Try to find via registry or common locations as fallback
			if *verbose {
				fmt.Println("Debug: Docker Desktop not found in standard paths, trying alternative methods...")
			}
			return fmt.Errorf("Docker Desktop not found. Please ensure Docker Desktop is installed")
		}

		cmd = exec.Command(dockerPath)
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}

	case "darwin":
		cmd = exec.Command("open", "-a", "Docker Desktop")

	case "linux":
		// For Linux, try to start docker service directly
		cmd = exec.Command("sudo", "systemctl", "start", "docker")

	default:
		return fmt.Errorf("unsupported platform: %s", runtime.GOOS)
	}

	if *verbose {
		fmt.Printf("Debug: Starting Docker Desktop with command: %v\n", cmd.Args)
	}

	return cmd.Start()
}

// waitForDocker waits for Docker to be ready
func waitForDocker(timeoutSeconds int) bool {
	timeout := time.After(time.Duration(timeoutSeconds) * time.Second)
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()

	startTime := time.Now()

	for {
		select {
		case <-timeout:
			if *verbose {
				fmt.Printf("Debug: Timeout reached after %v\n", time.Since(startTime))
			}
			return false
		case <-ticker.C:
			if isDockerReady() {
				if *verbose {
					fmt.Printf("Debug: Docker ready after %v\n", time.Since(startTime))
				}
				return true
			}
			if *verbose {
				fmt.Printf("Debug: Still waiting... (%v elapsed)\n", time.Since(startTime))
			}
		}
	}
}

// isDockerReady checks if Docker is ready to accept commands
func isDockerReady() bool {
	// Try multiple methods to check if Docker is ready
	methods := []func() bool{
		func() bool {
			cmd := exec.Command("docker", "info")
			err := cmd.Run()
			return err == nil
		},
		func() bool {
			cmd := exec.Command("docker", "version")
			err := cmd.Run()
			return err == nil
		},
		func() bool {
			cmd := exec.Command("docker", "ps")
			err := cmd.Run()
			return err == nil
		},
	}

	for i, method := range methods {
		if method() {
			if *verbose {
				fmt.Printf("Debug: Docker ready check passed (method %d)\n", i+1)
			}
			return true
		}
	}

	return false
}

func executeDockerCommand(args []string) {
	if *verbose {
		fmt.Printf("Debug: Executing docker command: %v\n", args)
	}

	cmd := exec.Command("docker", args...)

	// Set up stdin, stdout, stderr
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Run the command
	if err := cmd.Run(); err != nil {
		if *verbose {
			fmt.Printf("Debug: Docker command failed: %v\n", err)
		}

		// Exit with the same code as docker command
		if exitError, ok := err.(*exec.ExitError); ok {
			os.Exit(exitError.ExitCode())
		}
		fmt.Fprintf(os.Stderr, "Error executing docker command: %v\n", err)
		os.Exit(1)
	}
}
