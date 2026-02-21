#!/bin/bash
#
# Generates the VueNativeCounter.xcodeproj from project.yml using XcodeGen.
#
# Prerequisites:
#   brew install xcodegen
#
# Usage:
#   cd examples/counter/ios
#   ./generate-project.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Check that xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "Error: xcodegen is not installed."
    echo "Install it with: brew install xcodegen"
    exit 1
fi

# Check that the JS bundle exists
BUNDLE_PATH="../dist/vue-native-bundle.js"
if [ ! -f "$BUNDLE_PATH" ]; then
    echo "Error: JS bundle not found at $BUNDLE_PATH"
    echo "Build the counter example first:"
    echo "  cd examples/counter && npm run build"
    exit 1
fi

# Check that the native package exists
NATIVE_PKG="../../../native/Package.swift"
if [ ! -f "$NATIVE_PKG" ]; then
    echo "Error: VueNativeCore package not found at $NATIVE_PKG"
    exit 1
fi

echo "Generating Xcode project..."
xcodegen generate

echo ""
echo "Done! Open the project with:"
echo "  open VueNativeCounter.xcodeproj"
echo ""
echo "Then select an iOS Simulator and press Cmd+R to run."
