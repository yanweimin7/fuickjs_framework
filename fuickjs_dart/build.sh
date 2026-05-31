#!/bin/bash
# Build fuickjs_dart → dart-demo.js for the Flutter demo app.
# Usage: ./build.sh [entry/main.dart]

set -e

ENTRY="${1:-example/main.dart}"
OUT_DIR="$(dirname "$0")/example"
DEMO_ASSETS="$(dirname "$0")/../../fuickjs_demo/app/assets/js"

echo "▶ dart compile js $ENTRY ..."
dart compile js "$ENTRY" -o "$OUT_DIR/bundle.js"

cp "$OUT_DIR/bundle.js" "$DEMO_ASSETS/dart-demo.js"
echo "✓ Written to $DEMO_ASSETS/dart-demo.js ($(wc -c < "$DEMO_ASSETS/dart-demo.js") bytes)"
