# Set faster keyboard repeat rate (only on X11)
if command -v xset > /dev/null 2>&1 && [ -n "$DISPLAY" ]; then
  xset r rate 200 60 2> /dev/null || true
fi
