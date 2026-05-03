#!/bin/sh
# Fan control daemon: 4-level PWM based on CPU temperature.
# Matches vendor Mwrt fancts.sh thresholds.

TEMP_PATH="/sys/class/thermal/thermal_zone0/temp"

# Locate the pwm-fan hwmon node dynamically (avoids hardcoding hwmon index)
find_pwm() {
	find /sys/devices/platform -path "*/pwm*/hwmon/hwmon*/pwm1" 2>/dev/null | head -1
}

PWM_PATH=$(find_pwm)
if [ -z "$PWM_PATH" ]; then
	logger -t fancontrol "PWM path not found, retrying in 30s"
	sleep 30
	PWM_PATH=$(find_pwm)
fi
[ -z "$PWM_PATH" ] && { logger -t fancontrol "PWM path not found, exiting"; exit 1; }

logger -t fancontrol "Fan control started, PWM at $PWM_PATH"

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
