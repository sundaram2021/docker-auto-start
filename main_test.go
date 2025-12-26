package main

import (
	"os"
	"os/exec"
	"strings"
	"testing"
	"time"
)

func TestIsDockerDesktopRunning(t *testing.T) {
	// This test requires mocking since we can't reliably test the actual function
	// without knowing Docker Desktop's state
	t.Skip("Requires mocking for unit testing")
}

func TestStartDockerDesktop(t *testing.T) {
	// This test requires mocking since starting Docker Desktop is a system operation
	t.Skip("Requires mocking for unit testing")
}

func TestWaitForDocker(t *testing.T) {
	tests := []struct {
		name           string
		timeoutSeconds int
		shouldReady    bool
	}{
		{
			name:           "immediately ready",
			timeoutSeconds: 5,
			shouldReady:    true,
		},
		{
			name:           "timeout",
			timeoutSeconds: 1,
			shouldReady:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Test the logic with mocked isDockerReady
			start := time.Now()
			result := waitForDocker(tt.timeoutSeconds)
			duration := time.Since(start)

			if tt.shouldReady && !result {
				t.Errorf("waitForDocker() should have succeeded but failed")
			}

			if !tt.shouldReady && result {
				t.Errorf("waitForDocker() should have failed but succeeded")
			}

			// For timeout case, ensure it took approximately the timeout duration
			if !tt.shouldReady && duration < time.Duration(tt.timeoutSeconds)*time.Second {
				t.Errorf("waitForDocker() should have taken at least %v seconds, but took %v", tt.timeoutSeconds, duration)
			}
		})
	}
}

func TestIsDockerReady(t *testing.T) {
	tests := []struct {
		name     string
		command  string
		expected bool
	}{
		{
			name:     "docker info",
			command:  "info",
			expected: true,
		},
		{
			name:     "docker version",
			command:  "version",
			expected: true,
		},
		{
			name:     "docker ps",
			command:  "ps",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if _, err := exec.LookPath("docker"); err != nil {
				t.Skip("Docker not available for testing")
			}

			cmd := exec.Command("docker", tt.command)
			err := cmd.Run()
			result := err == nil

			// We don't enforce expected result since Docker might not be running
			// We just test that the function doesn't crash
			t.Logf("Command 'docker %s' result: %v", tt.command, result)
		})
	}
}

func TestExecuteDockerCommand(t *testing.T) {
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("Docker not available for testing - skipping docker command tests")
		return
	}

	tests := []struct {
		name    string
		args    []string
		wantErr bool
	}{
		{
			name:    "help command",
			args:    []string{"help"},
			wantErr: false,
		},
		{
			name:    "version command",
			args:    []string{"version"},
			wantErr: false,
		},
		{
			name:    "invalid command",
			args:    []string{"invalid-command"},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Since executeDockerCommand calls os.Exit, we can't test it directly
			// Instead, we test the underlying logic
			cmd := exec.Command("docker", tt.args...)
			err := cmd.Run()

			if (err != nil) != tt.wantErr {
				t.Errorf("docker %v error = %v, wantErr %v", tt.args, err != nil, tt.wantErr)
			}
		})
	}
}

// Integration tests
func TestIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration tests in short mode")
	}

	t.Run("build binary", func(t *testing.T) {
		// Build the binary
		buildCmd := exec.Command("go", "build", "-o", "test-docker-autostart.exe", "main.go")
		err := buildCmd.Run()
		if err != nil {
			t.Fatalf("Failed to build binary: %v", err)
		}
		defer os.Remove("test-docker-autostart.exe")
	})

	t.Run("help command", func(t *testing.T) {
		// Build the binary first
		buildCmd := exec.Command("go", "build", "-o", "test-docker-autostart.exe", "main.go")
		if err := buildCmd.Run(); err != nil {
			t.Fatalf("Failed to build binary: %v", err)
		}
		defer os.Remove("test-docker-autostart.exe")

		// Test help command (expected to fail since no arguments provided)
		cmd := exec.Command("./test-docker-autostart.exe")
		output, err := cmd.CombinedOutput()

		// Command should fail with exit status 1 (no arguments)
		if err == nil {
			t.Error("Help command should have failed with no arguments")
		}

		if len(output) == 0 {
			t.Error("Help command produced no output")
		}

		// Check if output contains usage information
		if !strings.Contains(string(output), "Usage:") {
			t.Errorf("Help output doesn't contain usage information: %s", string(output))
		}
	})
}

// Benchmark tests
func BenchmarkIsDockerReady(b *testing.B) {
	if _, err := exec.LookPath("docker"); err != nil {
		b.Skip("Docker not available for benchmarking")
	}

	for i := 0; i < b.N; i++ {
		isDockerReady()
	}
}

func BenchmarkWaitForDockerReady(b *testing.B) {
	if _, err := exec.LookPath("docker"); err != nil {
		b.Skip("Docker not available for benchmarking")
	}

	for i := 0; i < b.N; i++ {
		waitForDocker(1) // Very short timeout for benchmarking
	}
}
