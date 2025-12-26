#!/bin/bash

# Test script for Docker Auto-Start CLI

set -e

echo "Running tests..."

# Run unit tests
go test -v ./...

# Build to ensure it compiles
go build -o docker-autostart main.go

# Test basic functionality
./docker-autostart --help

echo "All tests passed!"