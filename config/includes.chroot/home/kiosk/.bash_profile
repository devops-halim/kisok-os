# Start the graphical kiosk automatically after autologin on tty1.
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
	exec startx -- -nocursor
fi
