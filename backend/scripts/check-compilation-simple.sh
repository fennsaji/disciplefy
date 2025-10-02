#!/bin/bash
set -e

echo "🔍 Simple TypeScript compilation check for Edge Functions..."
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

# Find all main Edge Function files (index.ts)
echo "📋 Finding Edge Function index files..."
main_files=($(find supabase/functions -name "index.ts" | sort))

total=${#main_files[@]}
echo "Found $total Edge Function files"
echo ""

# Check each file individually (no parallel processing)
success=0
failed_files=()

echo "🚀 Running compilation checks..."
for file in "${main_files[@]}"; do
    function_name=$(basename "$(dirname "$file")")
    echo -n "  Checking $function_name... "

    if deno check "$file" >/dev/null 2>&1; then
        echo "✅ OK"
        ((success++))
    else
        echo "❌ ERRORS"
        failed_files+=("$file")
    fi
done

echo ""
echo "📊 Compilation Results:"
echo "   Total Edge Functions: $total"
echo "   Successful: $success"
echo "   Failed: $((total - success))"

if [ ${#failed_files[@]} -gt 0 ]; then
    echo ""
    echo "❌ Edge Functions with compilation errors:"
    for file in "${failed_files[@]}"; do
        function_name=$(basename "$(dirname "$file")")
        echo ""
        echo "  🔴 $function_name ($file):"
        deno check "$file" 2>&1 | sed 's/^/     /'
    done
    echo ""
    echo "🚨 Fix the errors above before deploying to production."
    exit 1
else
    echo ""
    echo "🎉 All Edge Functions compile successfully!"
    echo "✅ Backend is ready for deployment."
fi