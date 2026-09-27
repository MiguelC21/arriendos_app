#!/bin/bash
# Build de Flutter web para Vercel
set -e

echo "Clonando Flutter SDK (canal stable)..."
git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter_sdk

export PATH="$PATH:$(pwd)/_flutter_sdk/bin"
git config --global --add safe.directory "$(pwd)/_flutter_sdk"

flutter config --no-analytics
flutter doctor -v

flutter pub get
flutter build web --release
