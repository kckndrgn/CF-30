#!/bin/bash

# List of candidate serial ports
PORTS=(/dev/ttyS0 /dev/ttyS1 /dev/ttyS2 /dev/ttyS3)
BAUD=9600
SLEEP_TIME=3

echo "Scanning serial ports for GPS data..."

for port in "${PORTS[@]}"; do
  [ -e "$port" ] || continue

  echo "Configuring $port at $BAUD baud..."
  stty -F "$port" $BAUD cs8 -cstopb -parenb -ixon -ixoff -crtscts

  port_num="${port##*/ttyS}"  # Extract number from /dev/ttySx

  rx_before=$(awk -v p="$port_num" '$1 ~ "^"p":" {split($6,a,":"); print a[2]}' /proc/tty/driver/serial)
  timeout 2 cat "$port"
  rx_after=$(awk -v p="$port_num" '$1 ~ "^"p":" {split($6,a,":"); print a[2]}' /proc/tty/driver/serial)
  echo "$port: rx before = $rx_before, after = $rx_after"

  if [ "$rx_after" -gt "$rx_before" ]; then
    echo "Activity detected on $port"
    echo "Updating /etc/default/gpsd..."
    sed -i "s|^DEVICES=.*|DEVICES=\"$port\"|" /etc/default/gpsd
    systemctl enable gpsd
    systemctl restart gpsd
    exit 0
  fi
done

echo "No GPS data detected on any serial ports."
exit 1

