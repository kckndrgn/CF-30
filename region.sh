#!/bin/bash

DEVICE="/dev/sr0"
TARGET_REGION=1

# Ensure regionset is installed
if ! command -v regionset &> /dev/null; then
  echo "Installing regionset..."
  sudo apt-get install -y regionset
fi

# Get current region info
OUTPUT=$(sudo regionset $DEVICE <<< "q")
CURRENT_REGION=$(echo "$OUTPUT" | grep "Drive plays " | awk -F: '{print $2}' | tr -d ' ')

if [[ "$CURRENT_REGION" == "0" ]]; then
  echo "DVD drive region is not set. Setting to Region $TARGET_REGION..."
  echo "$TARGET_REGION" | sudo regionset $DEVICE
elif [[ "$CURRENT_REGION" == "$TARGET_REGION" ]]; then
  echo "DVD drive is already set to Region $TARGET_REGION."
else
  echo "DVD drive is set to Region $CURRENT_REGION, not Region $TARGET_REGION."
  echo "You can only change the region a limited number of times."
  
  read -p "Do you want to change the region to $TARGET_REGION? [y/N]: " RESPONSE
  if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    echo "$TARGET_REGION" | sudo regionset $DEVICE
  else
    echo "Region change aborted."
  fi
fi

