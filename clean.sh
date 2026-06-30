#!/bin/sh
# Remove live-build artifacts so the next build starts clean.
set -e
cd "$(dirname "$0")"
if command -v lb >/dev/null 2>&1; then
	lb clean --purge || true
fi
rm -f kisok-os-amd64.hybrid.iso live-image-*.iso *.log
echo ">> Cleaned."
