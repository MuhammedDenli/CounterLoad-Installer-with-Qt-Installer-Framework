#!/bin/bash
# CounterLoad Windows Installer Build Script
# This is a wrapper around build-installer.sh to build the Windows installer.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the main build script with Windows and Sign flags and forward all arguments
"$SCRIPT_DIR/build-installer.sh" --build-windows --sign-windows "$@"
