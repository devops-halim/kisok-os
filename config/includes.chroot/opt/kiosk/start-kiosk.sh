#!/bin/sh
# Kiosk session entry point. Started by ~/.xinitrc once X is running.
set -eu

# Load configuration (KIOSK_URL).
KIOSK_URL="https://www.youtube.com"
if [ -r /etc/kiosk/kiosk.conf ]; then
	# shellcheck disable=SC1091
	. /etc/kiosk/kiosk.conf
fi

# --- Display power management: never blank or sleep the screen ---
xset -dpms
xset s off
xset s noblank

# Hide the mouse cursor when idle.
unclutter -idle 0.5 -root &

# Minimal window manager so Chromium gets a usable, fullscreen window.
openbox &

# --- Welcome screen: show the IT-Schmiede splash while things warm up ---
WELCOME_IMG="/opt/kiosk/welcome.png"
WELCOME_SECONDS=4
if [ -r "$WELCOME_IMG" ]; then
	feh --fullscreen --auto-zoom --hide-pointer --no-menus \
		--image-bg "#ffffff" "$WELCOME_IMG" &
	WELCOME_PID=$!
fi

# --- Audio: bring up the PipeWire stack for speaker + microphone ---
# (In a bare autologin session there is no desktop to start these for us.)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pipewire &
pipewire-pulse &
wireplumber &

# Unmute and raise the default output + capture volumes so sound works
# out of the box. Ignore errors on machines without those controls.
sleep 2
amixer -q set Master unmute        >/dev/null 2>&1 || true
amixer -q set Master 90%           >/dev/null 2>&1 || true
amixer -q set Capture cap          >/dev/null 2>&1 || true
amixer -q set Capture 80%          >/dev/null 2>&1 || true

# Keep the welcome screen up for a few seconds, then dismiss it.
if [ -n "${WELCOME_PID:-}" ]; then
	sleep "$WELCOME_SECONDS"
	kill "$WELCOME_PID" >/dev/null 2>&1 || true
fi

# Chromium profile lives on the writable overlay so settings persist
# within a session (the live image itself stays read-only).
PROFILE_DIR="$HOME/.config/chromium-kiosk"
mkdir -p "$PROFILE_DIR"

# --- Launch Chromium in kiosk mode, auto-restart if it ever exits ---
while true; do
	chromium \
		--user-data-dir="$PROFILE_DIR" \
		--kiosk "$KIOSK_URL" \
		--start-fullscreen \
		--window-position=0,0 \
		--no-first-run \
		--fast \
		--fast-start \
		--disable-infobars \
		--disable-translate \
		--disable-features=TranslateUI \
		--disable-session-crashed-bubble \
		--disable-pinch \
		--overscroll-history-navigation=0 \
		--noerrdialogs \
		--check-for-update-interval=31536000 \
		--autoplay-policy=no-user-gesture-required \
		--use-fake-ui-for-media-stream \
		--enable-features=WebRTC \
		--password-store=basic
	sleep 2
done
