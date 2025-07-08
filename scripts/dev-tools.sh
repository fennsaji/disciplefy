#!/bin/bash

# 🛠️ Development Tools & Utilities
# Disciplefy: Bible Study App
# 
# Collection of useful development commands and shortcuts

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Utility functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_header() { echo -e "${PURPLE}🛠️  $1${NC}"; echo "----------------------------------------"; }

# Show available commands
show_help() {
    log_header "Disciplefy Development Tools"
    echo
    echo -e "${CYAN}Environment Management:${NC}"
    echo "  setup     - Initial Supabase environment setup"
    echo "  start     - Start all development services"
    echo "  stop      - Stop all development services"
    echo "  restart   - Restart all development services"
    echo "  status    - Show service status"
    echo "  reset     - Reset database to clean state"
    echo
    echo -e "${CYAN}Database Operations:${NC}"
    echo "  db-reset  - Reset database with fresh schema"
    echo "  db-seed   - Add sample data to database"
    echo "  db-backup - Create database backup"
    echo "  db-restore - Restore from backup"
    echo "  db-migrate - Apply pending migrations"
    echo
    echo -e "${CYAN}Development Utilities:${NC}"
    echo "  logs      - View application logs"
    echo "  cleanup   - Clean logs and temporary files"
    echo "  test      - Run all tests"
    echo "  lint      - Run code linting"
    echo "  format    - Format code"
    echo
    echo -e "${CYAN}Deployment:${NC}"
    echo "  deploy-staging    - Deploy to staging environment"
    echo "  deploy-functions  - Deploy Edge Functions"
    echo "  health-check     - Check service health"
    echo
    echo -e "${CYAN}Monitoring:${NC}"
    echo "  monitor   - Start monitoring dashboard"
    echo "  metrics   - Show performance metrics"
    echo "  errors    - Show recent errors"
    echo
    echo -e "${CYAN}Usage:${NC}"
    echo "  ./scripts/dev-tools.sh <command>"
    echo "  ./scripts/dev-tools.sh help"
}

# Environment management
cmd_setup() {
    log_header "Setting Up Development Environment"
    ./scripts/supabase-setup.sh
}

cmd_start() {
    log_header "Starting Development Services"
    cd backend/supabase
    supabase start
    cd ../..
    log_success "All services started"
    cmd_status
}

cmd_stop() {
    log_header "Stopping Development Services"
    cd backend/supabase
    supabase stop
    cd ../..
    log_success "All services stopped"
}

cmd_restart() {
    log_header "Restarting Development Services"
    cmd_stop
    sleep 2
    cmd_start
}

cmd_status() {
    log_header "Service Status"
    cd backend/supabase
    supabase status
    cd ../..
}

cmd_reset() {
    log_header "Resetting Development Environment"
    log_warning "This will delete all local data!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd backend/supabase
        supabase db reset
        cd ../..
        log_success "Environment reset complete"
    else
        log_info "Reset cancelled"
    fi
}

# Database operations
cmd_db_reset() {
    log_header "Resetting Database"
    cd backend/supabase
    supabase db reset
    cd ../..
    log_success "Database reset complete"
}

cmd_db_seed() {
    log_header "Seeding Database"
    cd backend/supabase
    if [ -f "seed.sql" ]; then
        psql postgresql://postgres:postgres@localhost:54322/postgres -f seed.sql
        log_success "Database seeded"
    else
        log_error "seed.sql file not found"
    fi
    cd ../..
}

cmd_db_backup() {
    log_header "Creating Database Backup"
    mkdir -p backups
    BACKUP_FILE="backups/dev-backup-$(date +%Y%m%d_%H%M%S).sql"
    cd backend/supabase
    supabase db dump > "../../$BACKUP_FILE"
    cd ../..
    log_success "Backup created: $BACKUP_FILE"
}

cmd_db_restore() {
    log_header "Restoring Database from Backup"
    if [ -z "$2" ]; then
        log_error "Please specify backup file: $0 db-restore <backup-file>"
        return 1
    fi
    
    if [ ! -f "$2" ]; then
        log_error "Backup file not found: $2"
        return 1
    fi
    
    log_warning "This will replace all current data!"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        psql postgresql://postgres:postgres@localhost:54322/postgres < "$2"
        log_success "Database restored from $2"
    fi
}

cmd_db_migrate() {
    log_header "Applying Database Migrations"
    cd backend/supabase
    supabase db push
    cd ../..
    log_success "Migrations applied"
}

# Development utilities
cmd_logs() {
    log_header "Application Logs"
    echo "Choose log type:"
    echo "1) Database logs"
    echo "2) API logs"  
    echo "3) Function logs"
    echo "4) All logs"
    read -p "Selection (1-4): " -n 1 -r
    echo
    
    cd backend/supabase
    case $REPLY in
        1) supabase logs --type database ;;
        2) supabase logs --type api ;;
        3) supabase logs --type functions ;;
        4) supabase logs ;;
        *) log_error "Invalid selection" ;;
    esac
    cd ../..
}

cmd_cleanup() {
    log_header "Cleaning Development Environment"
    ./scripts/cleanup-logs.sh
}

cmd_test() {
    log_header "Running Tests"
    
    # Test Edge Functions
    if [ -d "backend/supabase/functions" ]; then
        log_info "Testing Edge Functions..."
        cd backend/supabase
        if [ -f "package.json" ]; then
            npm test
        fi
        cd ../..
    fi
    
    # Test Flutter app
    if [ -d "frontend" ]; then
        log_info "Testing Flutter app..."
        cd frontend
        if command -v flutter &> /dev/null; then
            flutter test
        else
            log_warning "Flutter not found, skipping Flutter tests"
        fi
        cd ..
    fi
    
    log_success "All tests completed"
}

cmd_lint() {
    log_header "Running Code Linting"
    
    # Lint Edge Functions
    if [ -d "backend/supabase" ] && [ -f "backend/supabase/package.json" ]; then
        log_info "Linting Edge Functions..."
        cd backend/supabase
        npm run lint 2>/dev/null || log_warning "No lint script found in package.json"
        cd ../..
    fi
    
    # Lint Flutter code
    if [ -d "frontend" ] && command -v flutter &> /dev/null; then
        log_info "Analyzing Flutter code..."
        cd frontend
        flutter analyze
        cd ..
    fi
    
    log_success "Linting completed"
}

cmd_format() {
    log_header "Formatting Code"
    
    # Format Edge Functions
    if [ -d "backend/supabase" ] && [ -f "backend/supabase/package.json" ]; then
        log_info "Formatting TypeScript code..."
        cd backend/supabase
        npx prettier --write "functions/**/*.ts" 2>/dev/null || log_warning "Prettier not found"
        cd ../..
    fi
    
    # Format Flutter code
    if [ -d "frontend" ] && command -v flutter &> /dev/null; then
        log_info "Formatting Dart code..."
        cd frontend
        dart format .
        cd ..
    fi
    
    log_success "Code formatting completed"
}

# Deployment
cmd_deploy_staging() {
    log_header "Deploying to Staging"
    log_warning "Make sure you have STAGING_PROJECT_REF configured"
    
    if [ -z "$STAGING_PROJECT_REF" ]; then
        log_error "STAGING_PROJECT_REF environment variable not set"
        return 1
    fi
    
    cd backend/supabase
    log_info "Deploying migrations..."
    supabase db push --project-ref "$STAGING_PROJECT_REF"
    
    log_info "Deploying functions..."
    supabase functions deploy --project-ref "$STAGING_PROJECT_REF"
    cd ../..
    
    log_success "Staging deployment completed"
}

cmd_deploy_functions() {
    log_header "Deploying Edge Functions"
    cd backend/supabase
    supabase functions deploy
    cd ../..
    log_success "Edge Functions deployed"
}

cmd_health_check() {
    log_header "Health Check"
    
    # Check local services
    log_info "Checking local services..."
    
    # Database
    if psql postgresql://postgres:postgres@localhost:54322/postgres -c "SELECT 1;" &>/dev/null; then
        log_success "Database: ✅ Healthy"
    else
        log_error "Database: ❌ Unavailable"
    fi
    
    # API
    if curl -s "http://localhost:54321/rest/v1/" &>/dev/null; then
        log_success "API: ✅ Healthy"
    else
        log_error "API: ❌ Unavailable"
    fi
    
    # Health endpoint
    HEALTH_RESPONSE=$(curl -s "http://localhost:54321/functions/v1/health-check" 2>/dev/null || echo "ERROR")
    if [[ $HEALTH_RESPONSE == *"healthy"* ]]; then
        log_success "Health Endpoint: ✅ Healthy"
    else
        log_warning "Health Endpoint: ⚠️ May be unavailable"
    fi
}

# Monitoring
cmd_monitor() {
    log_header "Starting Monitoring Dashboard"
    log_info "Opening Supabase Studio..."
    
    # Open Supabase Studio
    if command -v open &> /dev/null; then
        open "http://localhost:54323"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "http://localhost:54323"
    else
        echo "Open http://localhost:54323 in your browser"
    fi
    
    log_success "Monitoring dashboard should be opening..."
}

cmd_metrics() {
    log_header "Performance Metrics"
    
    cd backend/supabase
    
    # Database metrics
    log_info "Database Performance:"
    psql postgresql://postgres:postgres@localhost:54322/postgres -c "
    SELECT 
      'Active Connections' as metric,
      count(*) as value
    FROM pg_stat_activity 
    WHERE state = 'active'
    UNION ALL
    SELECT 
      'Database Size' as metric,
      pg_size_pretty(pg_database_size('postgres')) as value;
    " 2>/dev/null || log_warning "Could not fetch database metrics"
    
    # API metrics (if available)
    echo
    log_info "API Status:"
    curl -s "http://localhost:54321/functions/v1/health-check" | jq . 2>/dev/null || log_warning "Health check unavailable"
    
    cd ../..
}

cmd_errors() {
    log_header "Recent Errors"
    
    log_info "Checking recent logs for errors..."
    cd backend/supabase
    
    # Check function logs for errors
    supabase logs --type functions --level error 2>/dev/null | tail -20 || log_info "No recent function errors"
    
    # Check database logs for errors  
    supabase logs --type database --level error 2>/dev/null | tail -10 || log_info "No recent database errors"
    
    cd ../..
}

# Interactive mode
cmd_interactive() {
    while true; do
        echo
        log_header "Interactive Development Tools"
        echo "Select an option:"
        echo "1) Service Management"
        echo "2) Database Operations" 
        echo "3) Development Tools"
        echo "4) Monitoring"
        echo "5) Health Check"
        echo "q) Quit"
        echo
        read -p "Choice: " -n 1 -r
        echo
        
        case $REPLY in
            1)
                echo "1) Start  2) Stop  3) Restart  4) Status"
                read -p "Choice: " -n 1 -r
                echo
                case $REPLY in
                    1) cmd_start ;;
                    2) cmd_stop ;;
                    3) cmd_restart ;;
                    4) cmd_status ;;
                esac
                ;;
            2)
                echo "1) Reset  2) Seed  3) Backup  4) Migrate"
                read -p "Choice: " -n 1 -r
                echo
                case $REPLY in
                    1) cmd_db_reset ;;
                    2) cmd_db_seed ;;
                    3) cmd_db_backup ;;
                    4) cmd_db_migrate ;;
                esac
                ;;
            3)
                echo "1) Test  2) Lint  3) Format  4) Cleanup"
                read -p "Choice: " -n 1 -r
                echo
                case $REPLY in
                    1) cmd_test ;;
                    2) cmd_lint ;;
                    3) cmd_format ;;
                    4) cmd_cleanup ;;
                esac
                ;;
            4)
                echo "1) Monitor  2) Metrics  3) Errors  4) Logs"
                read -p "Choice: " -n 1 -r
                echo
                case $REPLY in
                    1) cmd_monitor ;;
                    2) cmd_metrics ;;
                    3) cmd_errors ;;
                    4) cmd_logs ;;
                esac
                ;;
            5) cmd_health_check ;;
            q|Q) log_info "Goodbye!"; break ;;
            *) log_warning "Invalid option" ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Main execution
main() {
    # Check if we're in the right directory
    if [ ! -f "scripts/supabase-setup.sh" ]; then
        log_error "Please run this script from the project root directory"
        exit 1
    fi
    
    case "${1:-help}" in
        setup) cmd_setup ;;
        start) cmd_start ;;
        stop) cmd_stop ;;
        restart) cmd_restart ;;
        status) cmd_status ;;
        reset) cmd_reset ;;
        
        db-reset) cmd_db_reset ;;
        db-seed) cmd_db_seed ;;
        db-backup) cmd_db_backup ;;
        db-restore) cmd_db_restore "$@" ;;
        db-migrate) cmd_db_migrate ;;
        
        logs) cmd_logs ;;
        cleanup) cmd_cleanup ;;
        test) cmd_test ;;
        lint) cmd_lint ;;
        format) cmd_format ;;
        
        deploy-staging) cmd_deploy_staging ;;
        deploy-functions) cmd_deploy_functions ;;
        health-check) cmd_health_check ;;
        
        monitor) cmd_monitor ;;
        metrics) cmd_metrics ;;
        errors) cmd_errors ;;
        
        interactive|i) cmd_interactive ;;
        
        help|--help|-h) show_help ;;
        *) 
            log_error "Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}⚠️  Operation interrupted${NC}"; exit 1' INT

# Run main function
main "$@"