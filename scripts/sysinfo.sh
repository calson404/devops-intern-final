#!/usr/bin/env bash
#
# sysinfo.sh — report host environment details.
# Part of the DevOps Intern Final Assessment (Task 2).
#
set -euo pipefail

main() {
    echo "===== System Information ====="
    echo "Date (ISO-8601 UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Current user:        $(id -un)"
    echo "Effective UID:       $(id -u)"
    echo "Hostname:            $(hostname)"
    echo "Kernel release:      $(uname -r)"
    echo

    echo "===== Disk Usage ====="
    df -h
    echo

    echo "===== Memory Usage ====="
    if command -v free >/dev/null 2>&1; then
        free -h
    elif [ -r /proc/meminfo ]; then
        grep -E '^(MemTotal|MemFree|MemAvailable):' /proc/meminfo
    else
        echo "(memory info unavailable on this platform)"
    fi
    echo

    echo "===== Docker Daemon ====="
    if ! command -v docker >/dev/null 2>&1; then
        echo "Docker CLI: not installed"
        exit 1
    fi

    if docker info >/dev/null 2>&1; then
        echo "Docker daemon: running"
        docker version --format 'Server version: {{.Server.Version}}'
    else
        echo "Docker daemon: NOT running (or not reachable)"
        exit 1
    fi
}

main "$@"
