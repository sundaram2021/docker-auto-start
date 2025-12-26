#!/bin/bash

# Test script for Docker Auto-Start CLI with auto-shutdown

set -e

echo "Running tests..."

# Run unit tests
go test -v ./...

# Build to ensure it compiles
go build -o docker-autostart main.go

# Test basic functionality
./docker-autostart --help

# Test auto-shutdown flag
./docker-autostart --auto-shutdown=false --help

echo "All tests passed!"