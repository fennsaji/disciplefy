#!/bin/bash
# Quick TypeScript compilation check
# Usage: ./scripts/check-quick.sh

find supabase/functions -name "*.ts" -exec deno check {} + && echo "✅ All TypeScript files compile successfully!"