#!/bin/bash

# このスクリプトは、アプリのログから取得したアクセストークンをデコードして
# ユーザー情報（sub, email等）を表示します

# 使い方:
# 1. iOSアプリのログからアクセストークンをコピー
# 2. このスクリプトを実行: ./decode_token.sh <access_token>

if [ -z "$1" ]; then
  echo "Usage: $0 <jwt_token>"
  echo ""
  echo "Example:"
  echo "  $0 eyJraWQiOiJxxx..."
  exit 1
fi

TOKEN="$1"

# JWTは3つのパートに分かれています: header.payload.signature
# payloadをデコードします
PAYLOAD=$(echo "$TOKEN" | cut -d'.' -f2)

# Base64デコード（URLセーフ版）
# macOSのbase64コマンドはパディングを自動調整します
echo "$PAYLOAD" | base64 -d 2>/dev/null | jq '.' || {
  # パディング調整が必要な場合
  PADDED="$PAYLOAD"
  case $((${#PAYLOAD} % 4)) in
    2) PADDED="${PAYLOAD}==" ;;
    3) PADDED="${PAYLOAD}=" ;;
  esac
  echo "$PADDED" | tr '_-' '/+' | base64 -d 2>/dev/null | jq '.'
}
