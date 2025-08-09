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

# Check if GNU parallel is available for faster processing
if ! command -v parallel &> /dev/null; then
    echo "💡 Tip: Install GNU parallel for 3-5x faster compilation checks:"
    echo "   brew install parallel    # macOS"
    echo "   sudo apt install parallel # Ubuntu"
fi
echo ""

# Find all TypeScript files first
echo "📋 Finding TypeScript files..."

# Use a more compatible way to read files into array
ts_files=()
while IFS= read -r file; do
    ts_files+=("$file")
done <<< "$(find supabase/functions -name '*.ts')"

total=${#ts_files[@]}

echo "Found $total TypeScript files"
echo "🚀 Running parallel compilation checks..."
echo ""

# Function to check a single file
check_file() {
    local file="$1"
    local basename=$(basename "$file")
    
    if deno check "$file" >/dev/null 2>&1; then
        echo "✅ $basename: OK"
        return 0
    else
        echo "❌ $basename: ERRORS"
        return 1
    fi
}

# Export function so it can be used by parallel
export -f check_file

# Run checks in parallel (limit to 8 concurrent jobs to avoid overwhelming system)
if command -v parallel &> /dev/null; then
    # Use GNU parallel if available
    echo "Using GNU parallel for faster compilation checks..."
    success=$(printf '%s\n' "${ts_files[@]}" | parallel -j8 check_file | grep -c "✅" || true)
    
    # Collect failed files
    failed_files=()
    for file in "${ts_files[@]}"; do
        if ! deno check "$file" >/dev/null 2>&1; then
            failed_files+=("$file")
        fi
    done
else
    # Fallback: use xargs for parallel processing (more compatible)
    echo "Using xargs for parallel compilation checks..."
    
    # Create a temporary function script
    temp_script=$(mktemp)
    cat > "$temp_script" << 'EOF'
#!/bin/bash
check_single_file() {
    local file="$1"
    local basename=$(basename "$file")
    
    if deno check "$file" >/dev/null 2>&1; then
        echo "✅ $basename: OK"
        return 0
    else
        echo "❌ $basename: ERRORS"
        return 1
    fi
}

check_single_file "$1"
EOF
    chmod +x "$temp_script"
    
    # Run checks in parallel using xargs
    success=0
    failed_files=()
    
    # Use xargs to run up to 8 processes in parallel
    printf '%s\n' "${ts_files[@]}" | xargs -n1 -P8 "$temp_script" || true
    
    # Count successes and collect failures
    for file in "${ts_files[@]}"; do
        if deno check "$file" >/dev/null 2>&1; then
            ((success++))
        else
            failed_files+=("$file")
        fi
    done
    
    # Cleanup
    rm -f "$temp_script"
fi 

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