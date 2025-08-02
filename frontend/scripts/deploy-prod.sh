#!/bin/bash
set -e

echo "🏗️  Building Flutter web..."
sh scripts/build-prod.sh

echo "📦 Optimizing build..."
# Remove source maps for production
find build/web -name "*.map" -delete

echo "🚀 Deploying to Vercel..."
cd build/web && vercel --prod --yes

echo "✅ Deployment complete!"
echo "🌐 Your app is live at: https://disciplefy.vercel.app"