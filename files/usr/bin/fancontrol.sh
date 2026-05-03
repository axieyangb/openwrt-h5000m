#!/bin/sh
# Fan control daemon: 4-level PWM based on CPU temperature
# Thresholds match vendor Mwrt fancts.sh behaviour

PWM_PATH="/sys/devices/platform/pwm-fan/hwmon/hwmon2/pwm1"
TEMP_PATH="/sys/class/thermal/thermal_zone0/temp"

[ -e "$PWM_PATH" ] || { logger -t fancontrol "PWM path not found, exiting"; exit 1; }

logger -t fancontrol "Fan control daemon started"

while true; do
	temp=$(cat "$TEMP_PATH" 2>/dev/null)
	[ -z "$temp" ] && { sleep 10; continue; }

	if   [ "$temp" -gt 85000 ]; then pwm=255
	elif [ "$temp" -gt 60000 ]; then pwm=192
	elif [ "$temp" -gt 50000 ]; then pwm=128
	else                              pwm=64
	fi

	cur=$(cat "$PWM_PATH" 2>/dev/null)
	[ "$cur" != "$pwm" ] && echo "$pwm" > "$PWM_PATH"
	sleep 8
done
