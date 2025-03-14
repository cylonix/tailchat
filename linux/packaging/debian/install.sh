#!/bin/bash

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo"
    exit 1
fi

# Check if running on Debian-based system
if ! command -v dpkg &> /dev/null; then
    echo "Error: This installer requires a Debian-based Linux distribution (Ubuntu, Debian, etc.)"
    exit 1
fi

# Check if it's Ubuntu or Debian
if [ ! -f "/etc/os-release" ]; then
    echo "Error: Cannot determine OS type"
    exit 1
fi

. /etc/os-release
if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
    echo "Error: This installer is only for Ubuntu or Debian systems"
    echo "Current OS: $PRETTY_NAME"
    exit 1
fi

echo "Installing Tailchat..."

# Create temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

# Download the .deb package
echo "Downloading Tailchat package..."
if ! curl -f#SL "https://cylonix.io/sw/tailchat/tailchat.deb" -o tailchat.deb; then
    echo "Error: Failed to download Tailchat package"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Install the package
echo "Installing package..."
if ! dpkg -i tailchat.deb; then
    echo "Error: Failed to install Tailchat"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Clean up
rm -rf "$TMP_DIR"

echo "Tailchat has been successfully installed!"
echo "You can now start Tailchat from your applications menu"