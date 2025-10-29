#!/bin/bash

# This script decodes an access token captured from the app logs
# and prints the user claims (sub, email, etc.).

# Usage:
# 1. Copy the access token from the iOS app logs.
# 2. Run this script: ./decode_token.sh <access_token>

if [ -z "$1" ]; then
  echo "Usage: $0 <jwt_token>"
  echo ""
  echo "Example:"
  echo "  $0 eyJraWQiOiJxxx..."
  exit 1
fi

TOKEN="$1"

# A JWT has three parts: header.payload.signature.
# Decode the payload portion.
PAYLOAD=$(echo "$TOKEN" | cut -d'.' -f2)

# Base64 decode (URL-safe variant).
# The macOS base64 command automatically handles missing padding.
echo "$PAYLOAD" | base64 -d 2>/dev/null | jq '.' || {
  # Adjust padding manually if necessary.
  PADDED="$PAYLOAD"
  case $((${#PAYLOAD} % 4)) in
    2) PADDED="${PAYLOAD}==" ;;
    3) PADDED="${PAYLOAD}=" ;;
  esac
  echo "$PADDED" | tr '_-' '/+' | base64 -d 2>/dev/null | jq '.'
}
