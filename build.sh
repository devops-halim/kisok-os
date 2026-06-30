#!/bin/sh
# Build the kisok-os bootable ISO using Debian live-build.
#
# Requirements: a Debian/Ubuntu host (or container), run as root, with the
# `live-build` package installed. The result is ./kisok-os-amd64.hybrid.iso
set -e

if [ "$(id -u)" -ne 0 ]; then
	echo "ERROR: live-build must be run as root. Try: sudo ./build.sh" >&2
	exit 1
fi

if ! command -v lb >/dev/null 2>&1; then
	echo "ERROR: live-build is not installed." >&2
	echo "Install it with:  sudo apt-get update && sudo apt-get install -y live-build" >&2
	exit 1
fi

cd "$(dirname "$0")"

echo ">> Cleaning previous build state (keeps package cache)..."
lb clean || true

echo ">> Configuring image (lb config)..."
lb config

echo ">> Building image (lb build). This downloads packages and can take a while..."
lb build

# Normalise the output name regardless of live-build version.
for f in live-image-amd64.hybrid.iso live-image-amd64.iso; do
	if [ -f "$f" ]; then
		mv -f "$f" kisok-os-amd64.hybrid.iso
		break
	fi
done

if [ -f kisok-os-amd64.hybrid.iso ]; then
	echo ""
	echo ">> Done:  $(pwd)/kisok-os-amd64.hybrid.iso"
	echo ">> Flash it to a USB stick, e.g.:"
	echo "     sudo dd if=kisok-os-amd64.hybrid.iso of=/dev/sdX bs=4M status=progress oflag=sync"
else
	echo "WARNING: build finished but no ISO was found. Check the log above." >&2
	exit 1
fi
