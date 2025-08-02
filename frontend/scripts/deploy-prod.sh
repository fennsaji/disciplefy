#!/bin/bash
set -e

echo "🏗️  Building Flutter web..."
sh scripts/build-prod.sh

echo "📦 Optimizing build..."
# Remove source maps for production
find build/web -name "*.map" -delete

# Copy Vercel project configuration to ensure correct project deployment
echo "📋 Copying Vercel project config..."
cp -r .vercel build/web/
cp vercel.json build/web/

echo "🚀 Deploying to Vercel..."
# Deploy from build/web directory with project config
cd build/web && vercel --prod --yes

echo "✅ Deployment complete!"
echo "🌐 Your app is live at: https://disciplefy.vercel.app"