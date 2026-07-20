#!/bin/bash
# CounterLoad Linux Installer Build Script
# This is a wrapper around build-installer.sh to build the Linux installer.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the main build script with Linux flag and forward all arguments
"$SCRIPT_DIR/build-installer.sh" --build-linux "$@"
