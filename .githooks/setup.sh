#!/bin/bash
#
# Git Hooks Setup Script
# 
# This script configures Git to use the hooks in .githooks directory
# Run this once after cloning the repository
#

set -e

echo "🔧 Setting up Git hooks for Disciplefy Bible Study App..."
echo ""

# Get the root directory of the repository
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Configure Git to use .githooks directory
echo "📁 Configuring Git hooks path..."
git config core.hooksPath .githooks

echo "🔍 Available hooks:"
ls -la .githooks/

echo ""
echo "✅ Git hooks setup completed!"
echo ""
echo "📋 What this enables:"
echo "   • Pre-commit: TypeScript and Dart compilation checks"
echo "   • Prevents broken code from being committed"
echo "   • Runs automatically on every commit"
echo ""
echo "💡 To test the pre-commit hook:"
echo "   git add . && git commit -m 'test commit' --dry-run"
echo ""
echo "⚠️  To skip hooks (not recommended):"
echo "   git commit --no-verify"