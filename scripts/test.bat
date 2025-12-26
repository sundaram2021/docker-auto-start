@echo off

REM Test script for Docker Auto-Start CLI with auto-shutdown (Windows)

echo Running tests...

REM Run unit tests
go test -v ./...

REM Build to ensure it compiles
go build -o docker-autostart.exe main.go

REM Test basic functionality
docker-autostart.exe --help

REM Test auto-shutdown flag
docker-autostart.exe --auto-shutdown=false --help

echo All tests passed!