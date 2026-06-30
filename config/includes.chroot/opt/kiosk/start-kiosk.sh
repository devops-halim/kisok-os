#!/bin/sh
# Kiosk session entry point. Started by ~/.xinitrc once X is running.
#
# Note: we deliberately do NOT use `set -e` here. The Chromium loop must keep
# retrying even if a launch exits non-zero, and optional steps (audio mixer,
# welcome image) must never tear down the whole session.

# Load configuration (KIOSK_URL, KIOSK_DISABLE_GPU, WELCOME_SECONDS).
KIOSK_URL="https://www.youtube.com"
KIOSK_DISABLE_GPU="auto"   # auto | yes | no
WELCOME_SECONDS=4
if [ -r /etc/kiosk/kiosk.conf ]; then
	# shellcheck disable=SC1091
	. /etc/kiosk/kiosk.conf
fi

LOG="$HOME/kiosk.log"
echo "=== kiosk session started $(date) ===" > "$LOG" 2>/dev/null

# --- Display power management: never blank or sleep the screen ---
xset -dpms      2>>"$LOG" || true
xset s off      2>>"$LOG" || true
xset s noblank  2>>"$LOG" || true

# A non-alarming background instead of pure black while things start.
xsetroot -solid "#0a0c10" 2>>"$LOG" || true

# Hide the mouse cursor when idle.
unclutter -idle 0.5 -root >/dev/null 2>&1 &

# Minimal window manager so Chromium gets a usable, fullscreen window.
openbox >/dev/null 2>&1 &

# --- Welcome screen: show the IT-Schmiede splash while things warm up ---
WELCOME_IMG="/opt/kiosk/welcome.png"
if [ -r "$WELCOME_IMG" ]; then
	feh --fullscreen --auto-zoom --hide-pointer --no-menus \
		--image-bg "#ffffff" "$WELCOME_IMG" >/dev/null 2>&1 &
	WELCOME_PID=$!
fi

# --- Audio: bring up the PipeWire stack for speaker + microphone ---
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
pipewire        >/dev/null 2>&1 &
pipewire-pulse  >/dev/null 2>&1 &
wireplumber     >/dev/null 2>&1 &

# Unmute and raise the default output + capture volumes so sound works
# out of the box. Ignore errors on machines without those controls.
sleep 2
amixer -q set Master unmute >/dev/null 2>&1 || true
amixer -q set Master 90%    >/dev/null 2>&1 || true
amixer -q set Capture cap   >/dev/null 2>&1 || true
amixer -q set Capture 80%   >/dev/null 2>&1 || true

# Keep the welcome screen up for a few seconds, then dismiss it.
if [ -n "${WELCOME_PID:-}" ]; then
	sleep "$WELCOME_SECONDS"
	kill "$WELCOME_PID" >/dev/null 2>&1 || true
fi

# --- Decide whether to disable the GPU ---------------------------------------
# In a virtual machine (VirtualBox/QEMU/VMware) Chromium's GL backend often
# renders a black window. Software rendering is slower but always works, so we
# auto-disable the GPU when a VM is detected. Override via KIOSK_DISABLE_GPU.
GPU_FLAGS=""
case "$KIOSK_DISABLE_GPU" in
	yes)
		GPU_FLAGS="--disable-gpu"
		;;
	no)
		GPU_FLAGS=""
		;;
	*)
		if command -v systemd-detect-virt >/dev/null 2>&1 && \
		   systemd-detect-virt -q; then
			echo "VM detected ($(systemd-detect-virt)); disabling GPU." >>"$LOG"
			GPU_FLAGS="--disable-gpu"
		fi
		;;
esac

# Chromium profile lives on the writable overlay so settings persist
# within a session (the live image itself stays read-only).
PROFILE_DIR="$HOME/.config/chromium-kiosk"
mkdir -p "$PROFILE_DIR"

# --- Launch Chromium in kiosk mode, auto-restart if it ever exits ---
while true; do
	echo "--- launching chromium $(date) ---" >>"$LOG"
	# shellcheck disable=SC2086
	chromium \
		--user-data-dir="$PROFILE_DIR" \
		--kiosk "$KIOSK_URL" \
		--start-fullscreen \
		--window-position=0,0 \
		--no-first-run \
		--no-sandbox \
		--disable-dev-shm-usage \
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
		--password-store=basic \
		$GPU_FLAGS >>"$LOG" 2>&1
	echo "chromium exited ($?) $(date)" >>"$LOG"
	sleep 2
done
