#!/bin/bash

# 🧹 Development Environment Cleanup Script
# Disciplefy: Bible Study App
# 
# This script cleans up logs, temporary files, and development artifacts
# to maintain a clean development environment.

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KEEP_DAYS=7  # Keep logs from last 7 days
MAX_LOG_SIZE="100M"  # Maximum log file size to keep

# Utility functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_header() {
    echo -e "${BLUE}🧹 $1${NC}"
    echo "----------------------------------------"
}

# Get human-readable file size
get_size() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        du -sh "$1" 2>/dev/null | cut -f1
    else
        # Linux
        du -sh "$1" 2>/dev/null | cut -f1
    fi
}

# Clean Supabase logs
clean_supabase_logs() {
    log_header "Cleaning Supabase Logs"
    
    if [ -d "backend/supabase" ]; then
        cd backend/supabase
        
        # Clean Docker logs
        log_info "Cleaning Docker container logs..."
        if command -v docker &> /dev/null; then
            # Get Supabase container IDs
            CONTAINERS=$(docker ps -a --filter "name=supabase" --format "{{.ID}}" 2>/dev/null || true)
            
            if [ -n "$CONTAINERS" ]; then
                for container in $CONTAINERS; do
                    log_size=$(docker logs --details "$container" 2>&1 | wc -c)
                    if [ "$log_size" -gt 1048576 ]; then  # 1MB
                        log_info "Truncating logs for container $container"
                        docker logs --tail 100 "$container" > "/tmp/container_$container.log" 2>&1
                        # Note: Docker doesn't allow direct log truncation, but this shows recent logs
                    fi
                done
                log_success "Docker container logs processed"
            else
                log_info "No Supabase containers found"
            fi
        fi
        
        # Clean Supabase local logs
        if [ -d ".supabase/logs" ]; then
            log_info "Cleaning Supabase local logs..."
            
            # Remove old log files
            find .supabase/logs -name "*.log" -type f -mtime +$KEEP_DAYS -delete 2>/dev/null || true
            
            # Truncate large log files
            find .supabase/logs -name "*.log" -type f -size +$MAX_LOG_SIZE -exec truncate -s 10M {} \; 2>/dev/null || true
            
            log_success "Supabase local logs cleaned"
        fi
        
        cd ../..
    else
        log_warning "Supabase backend directory not found"
    fi
}

# Clean application logs
clean_app_logs() {
    log_header "Cleaning Application Logs"
    
    # Clean general log files
    if [ -d "logs" ]; then
        log_info "Cleaning application log directory..."
        
        # Remove old logs
        find logs -name "*.log" -type f -mtime +$KEEP_DAYS -delete 2>/dev/null || true
        find logs -name "*.out" -type f -mtime +$KEEP_DAYS -delete 2>/dev/null || true
        
        # Compress large logs
        find logs -name "*.log" -type f -size +10M -exec gzip {} \; 2>/dev/null || true
        
        log_success "Application logs cleaned"
    fi
    
    # Clean deployment logs
    if [ -f "deployments.log" ]; then
        log_info "Cleaning deployment logs..."
        
        # Keep only last 100 lines of deployment log
        tail -n 100 deployments.log > deployments.log.tmp
        mv deployments.log.tmp deployments.log
        
        log_success "Deployment logs trimmed"
    fi
    
    # Clean rollback logs
    if [ -f "rollbacks.log" ]; then
        log_info "Cleaning rollback logs..."
        
        # Keep only last 50 lines of rollback log
        tail -n 50 rollbacks.log > rollbacks.log.tmp
        mv rollbacks.log.tmp rollbacks.log
        
        log_success "Rollback logs trimmed"
    fi
}

# Clean temporary files
clean_temp_files() {
    log_header "Cleaning Temporary Files"
    
    # Clean common temporary directories
    TEMP_DIRS=(
        ".tmp"
        "tmp"
        ".cache"
        "node_modules/.cache"
        ".dart_tool"
        "build/temp"
    )
    
    for dir in "${TEMP_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            log_info "Cleaning $dir..."
            rm -rf "$dir"/*
            log_success "Cleaned $dir"
        fi
    done
    
    # Clean temporary files
    find . -name "*.tmp" -type f -delete 2>/dev/null || true
    find . -name "*.temp" -type f -delete 2>/dev/null || true
    find . -name ".DS_Store" -type f -delete 2>/dev/null || true
    find . -name "Thumbs.db" -type f -delete 2>/dev/null || true
    
    log_success "Temporary files cleaned"
}

# Clean Flutter build artifacts
clean_flutter_artifacts() {
    log_header "Cleaning Flutter Build Artifacts"
    
    if [ -d "frontend" ]; then
        cd frontend
        
        if command -v flutter &> /dev/null; then
            log_info "Running flutter clean..."
            flutter clean
            
            # Clean pub cache if it's large
            if [ -d "$HOME/.pub-cache" ]; then
                CACHE_SIZE=$(get_size "$HOME/.pub-cache")
                log_info "Pub cache size: $CACHE_SIZE"
                
                # If cache is larger than 1GB, clean it
                if [[ "$CACHE_SIZE" == *"G"* ]] && [[ "${CACHE_SIZE%G*}" -gt 1 ]]; then
                    log_info "Cleaning large pub cache..."
                    flutter pub cache clean
                fi
            fi
            
            log_success "Flutter artifacts cleaned"
        else
            log_warning "Flutter not found, skipping Flutter cleanup"
        fi
        
        cd ..
    else
        log_info "Frontend directory not found, skipping Flutter cleanup"
    fi
}

# Clean Node.js artifacts
clean_node_artifacts() {
    log_header "Cleaning Node.js Artifacts"
    
    # Clean backend node_modules if they exist
    if [ -d "backend/supabase/node_modules" ]; then
        log_info "Checking backend node_modules size..."
        
        SIZE=$(get_size "backend/supabase/node_modules")
        log_info "Backend node_modules size: $SIZE"
        
        # If it's very large, suggest reinstall
        if [[ "$SIZE" == *"G"* ]] && [[ "${SIZE%G*}" -gt 1 ]]; then
            log_warning "Large node_modules detected ($SIZE)"
            read -p "Remove and reinstall node_modules? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cd backend/supabase
                rm -rf node_modules
                npm install
                cd ../..
                log_success "Node modules reinstalled"
            fi
        fi
    fi
    
    # Clean npm cache
    if command -v npm &> /dev/null; then
        log_info "Cleaning npm cache..."
        npm cache clean --force 2>/dev/null || true
        log_success "npm cache cleaned"
    fi
}

# Clean development databases
clean_dev_databases() {
    log_header "Cleaning Development Databases"
    
    if [ -d "backend/supabase" ]; then
        cd backend/supabase
        
        log_info "Checking Supabase volumes..."
        
        if command -v docker &> /dev/null; then
            # Show Supabase volumes
            VOLUMES=$(docker volume ls --filter "name=supabase" --format "{{.Name}}" 2>/dev/null || true)
            
            if [ -n "$VOLUMES" ]; then
                echo "Supabase volumes found:"
                for volume in $VOLUMES; do
                    SIZE=$(docker system df -v 2>/dev/null | grep "$volume" | awk '{print $3}' || echo "unknown")
                    echo "  - $volume ($SIZE)"
                done
                
                read -p "Reset development database? This will delete all data (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Resetting Supabase database..."
                    supabase db reset
                    log_success "Development database reset"
                fi
            else
                log_info "No Supabase volumes found"
            fi
        fi
        
        cd ../..
    fi
}

# Clean backup files
clean_backups() {
    log_header "Cleaning Old Backup Files"
    
    if [ -d "backups" ]; then
        log_info "Cleaning old backup files..."
        
        # Remove backups older than 30 days
        find backups -name "*.sql" -type f -mtime +30 -delete 2>/dev/null || true
        find backups -name "*.backup" -type f -mtime +30 -delete 2>/dev/null || true
        
        # Compress old backups (7-30 days old)
        find backups -name "*.sql" -type f -mtime +7 -mtime -30 -exec gzip {} \; 2>/dev/null || true
        
        log_success "Old backups cleaned"
    fi
}

# Show disk usage summary
show_disk_usage() {
    log_header "Disk Usage Summary"
    
    echo "Project directory sizes:"
    
    DIRS_TO_CHECK=(
        "backend/supabase"
        "frontend"
        "docs"
        "scripts"
        "logs"
        "backups"
        ".git"
    )
    
    for dir in "${DIRS_TO_CHECK[@]}"; do
        if [ -d "$dir" ]; then
            SIZE=$(get_size "$dir")
            printf "  %-20s %s\n" "$dir:" "$SIZE"
        fi
    done
    
    echo
    TOTAL_SIZE=$(get_size ".")
    echo "Total project size: $TOTAL_SIZE"
}

# Main cleanup function
main() {
    log_header "🧹 Disciplefy Development Environment Cleanup"
    echo "This script will clean logs, temporary files, and development artifacts"
    echo
    
    # Check if we're in the right directory
    if [ ! -f "scripts/supabase-setup.sh" ]; then
        log_error "Please run this script from the project root directory"
        exit 1
    fi
    
    # Show current disk usage
    show_disk_usage
    echo
    
    # Confirm cleanup
    read -p "Proceed with cleanup? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Cleanup cancelled"
        exit 0
    fi
    
    # Run cleanup functions
    clean_supabase_logs
    clean_app_logs
    clean_temp_files
    clean_flutter_artifacts
    clean_node_artifacts
    clean_backups
    
    # Optional database cleanup
    echo
    read -p "Clean development database? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        clean_dev_databases
    fi
    
    echo
    log_success "🎉 Cleanup completed!"
    echo
    
    # Show updated disk usage
    show_disk_usage
    
    echo
    log_info "💡 Cleanup Tips:"
    echo "  • Run this script weekly to maintain a clean environment"
    echo "  • Use 'supabase logs' to view recent logs"
    echo "  • Monitor disk usage with 'du -sh .' in project root"
    echo "  • Large node_modules? Consider 'npm ci' instead of 'npm install'"
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}⚠️  Cleanup interrupted${NC}"; exit 1' INT

# Run main function
main "$@"