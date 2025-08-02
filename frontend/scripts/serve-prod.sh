#!/bin/bash
set -e

echo "🏗️  Building and serving Flutter web for production..."

# Build for production
sh scripts/build-prod.sh

echo "🚀 Starting production server..."
echo "📍 Server will be available at: http://localhost:59641"
echo "⏹️  Press Ctrl+C to stop the server"
echo ""

# Serve the production build
npx serve build/web -s -l 59641 --cors