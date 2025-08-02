#!/bin/bash
set -e

echo "🚀 Serving existing Flutter web build..."
echo "📍 Server will be available at: http://localhost:3000"
echo "⏹️  Press Ctrl+C to stop the server"
echo ""

# Check if build exists
if [ ! -d "build/web" ]; then
    echo "❌ No build found! Run './scripts/build-prod.sh' first."
    exit 1
fi

# Serve the existing build
npx serve build/web -s -l 3000 --cors