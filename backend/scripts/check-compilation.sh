#!/bin/bash
set -e

echo "🔍 Checking TypeScript compilation for all Edge Functions..."
echo ""

# Change to backend directory if not already there
if [[ ! -d "supabase/functions" ]]; then
    echo "📁 Changing to backend directory..."
    cd "$(dirname "$0")/.."
fi

# Check if Deno is available
if ! command -v deno &> /dev/null; then
    echo "❌ Deno not found. Please install Deno first:"
    echo "   curl -fsSL https://deno.land/install.sh | sh"
    exit 1
fi

echo "🔧 Using Deno: $(deno --version | head -n1)"
echo ""

# Find and check all TypeScript files
success=0
total=0
failed_files=()

echo "📋 Checking TypeScript files..."
while IFS= read -r -d '' file; do
    echo -n "Checking $(basename "$file"): "
    if deno check "$file" >/dev/null 2>&1; then
        echo "✅ OK"
        ((success++))
    else
        echo "❌ ERRORS"
        failed_files+=("$file")
    fi
    ((total++))
done < <(find supabase/functions -name "*.ts" -print0)

echo ""
echo "📊 Compilation Results:"
echo "   Total files: $total"
echo "   Successful: $success"
echo "   Failed: $((total - success))"

if [ ${#failed_files[@]} -gt 0 ]; then
    echo ""
    echo "❌ Files with compilation errors:"
    for file in "${failed_files[@]}"; do
        echo "   • $file"
        echo "     Error details:"
        deno check "$file" 2>&1 | sed 's/^/       /'
        echo ""
    done
    echo "🚨 Fix the errors above before deploying to production."
    exit 1
else
    echo ""
    echo "🎉 All TypeScript files compile successfully!"
    echo "✅ Backend is ready for deployment."
fi