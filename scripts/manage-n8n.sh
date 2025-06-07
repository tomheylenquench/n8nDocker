#!/bin/bash

# manage-n8n.sh
# Bash script to manage the n8n Docker environment

set -e

# Default values
ACTION=""
SERVICE=""
FOLLOW_LOGS=false
LINES=100

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [ACTION] [OPTIONS]

Manage n8n Docker environment

ACTIONS:
    start                    Start all services
    stop                     Stop all services
    restart                  Restart all services
    status                   Show service status
    logs [service]           Show logs (optionally for specific service)
    ps                       Show running containers
    down                     Stop and remove containers
    up                       Start services in detached mode
    update                   Update to latest images
    backup                   Create backup of data
    restore [backup-file]    Restore from backup
    reset                    Reset environment (removes all data)
    clean                    Clean up unused resources

OPTIONS:
    -f, --follow            Follow log output (tail -f)
    -n, --lines LINES       Number of log lines to show (default: 100)
    -h, --help              Show this help message

EXAMPLES:
    $0 start                 # Start all services
    $0 stop                  # Stop all services
    $0 logs n8n             # Show n8n logs
    $0 logs --follow        # Follow all logs
    $0 status               # Show service status
    $0 update               # Update to latest images

AVAILABLE SERVICES:
    n8n, postgres, redis, traefik

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        start|stop|restart|status|logs|ps|down|up|update|backup|restore|reset|clean)
            ACTION="$1"
            shift
            ;;
        -f|--follow)
            FOLLOW_LOGS=true
            shift
            ;;
        -n|--lines)
            LINES="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$SERVICE" && "$ACTION" == "logs" ]]; then
                SERVICE="$1"
            elif [[ -z "$SERVICE" && "$ACTION" == "restore" ]]; then
                SERVICE="$1"  # In this case, SERVICE is actually the backup file
            else
                echo "Unknown option: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Print functions
print_step() {
    echo -e "\n${GREEN}🚀 $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to test if Docker is running
test_docker_running() {
    if docker version >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to test if Docker Compose is available
test_docker_compose_available() {
    if docker compose version >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to check if project is set up
check_project_setup() {
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found. Please run this script from the project root."
        exit 1
    fi
    
    if [ ! -f ".env" ]; then
        print_error ".env file not found. Please run deployment script first."
        exit 1
    fi
}

# Function to get container names
get_container_names() {
    docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" 2>/dev/null || true
}

# Function to wait for user confirmation
confirm_action() {
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled."
        exit 0
    fi
}

# Main logic
echo -e "${BLUE}🐳 n8n Docker Management Script${NC}"
echo -e "${BLUE}===============================${NC}"

# Check prerequisites
if ! test_docker_running; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

if ! test_docker_compose_available; then
    print_error "Docker Compose is not available. Please install Docker Compose and try again."
    exit 1
fi

# Change to project directory
PROJECT_ROOT=$(dirname "$(readlink -f "$0")")/../
cd "$PROJECT_ROOT"

# Check project setup
check_project_setup

print_info "Working directory: $(pwd)"

# Execute action
case "$ACTION" in
    start)
        print_step "Starting n8n services..."
        docker compose start
        print_success "Services started successfully!"
        echo
        print_info "Check status with: $0 status"
        ;;
        
    stop)
        print_step "Stopping n8n services..."
        docker compose stop
        print_success "Services stopped successfully!"
        ;;
        
    restart)
        print_step "Restarting n8n services..."
        docker compose restart
        print_success "Services restarted successfully!"
        echo
        print_info "Check status with: $0 status"
        ;;
        
    status)
        print_step "Service Status:"
        echo
        docker compose ps
        echo
        print_info "Detailed status:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
        ;;
        
    ps)
        print_step "Running containers:"
        docker compose ps
        ;;
        
    logs)
        if [ -n "$SERVICE" ]; then
            print_step "Showing logs for service: $SERVICE"
            if [ "$FOLLOW_LOGS" == "true" ]; then
                docker compose logs -f "$SERVICE"
            else
                docker compose logs --tail="$LINES" "$SERVICE"
            fi
        else
            print_step "Showing logs for all services"
            if [ "$FOLLOW_LOGS" == "true" ]; then
                docker compose logs -f
            else
                docker compose logs --tail="$LINES"
            fi
        fi
        ;;
        
    down)
        confirm_action "⚠️  This will stop and remove all containers. Data volumes will be preserved."
        print_step "Stopping and removing containers..."
        docker compose down
        print_success "Containers stopped and removed successfully!"
        ;;
        
    up)
        print_step "Starting services in detached mode..."
        docker compose up -d
        print_success "Services started successfully!"
        echo
        print_info "Check status with: $0 status"
        ;;
        
    update)
        print_step "Updating to latest images..."
        print_info "Pulling latest images..."
        docker compose pull
        
        print_info "Recreating containers with new images..."
        docker compose up -d --force-recreate
        
        print_info "Cleaning up old images..."
        docker image prune -f
        
        print_success "Update completed successfully!"
        echo
        print_info "Check status with: $0 status"
        ;;
        
    backup)
        BACKUP_DIR="backups"
        BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
        BACKUP_FILE="$BACKUP_DIR/n8n_backup_$BACKUP_DATE.tar.gz"
        
        mkdir -p "$BACKUP_DIR"
        
        print_step "Creating backup..."
        print_info "Stopping services for consistent backup..."
        docker compose stop
        
        print_info "Creating backup archive: $BACKUP_FILE"
        tar -czf "$BACKUP_FILE" \
            docker-compose.yml \
            .env \
            secrets/ \
            certs/ \
            $(docker volume ls --filter "name=$(basename $(pwd))" --format "{{.Mountpoint}}" 2>/dev/null || echo "")
        
        print_info "Restarting services..."
        docker compose start
        
        print_success "Backup created: $BACKUP_FILE"
        print_info "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
        ;;
        
    restore)
        if [ -z "$SERVICE" ]; then
            print_error "Please specify backup file to restore from."
            print_info "Usage: $0 restore <backup-file>"
            exit 1
        fi
        
        BACKUP_FILE="$SERVICE"
        if [ ! -f "$BACKUP_FILE" ]; then
            print_error "Backup file not found: $BACKUP_FILE"
            exit 1
        fi
        
        confirm_action "⚠️  This will restore from backup and overwrite current data."
        
        print_step "Restoring from backup: $BACKUP_FILE"
        print_info "Stopping services..."
        docker compose down
        
        print_info "Extracting backup..."
        tar -xzf "$BACKUP_FILE"
        
        print_info "Starting services..."
        docker compose up -d
        
        print_success "Restore completed successfully!"
        ;;
        
    reset)
        confirm_action "⚠️  This will completely reset the environment and DELETE ALL DATA."
        confirm_action "🚨 Are you absolutely sure? This cannot be undone."
        
        print_step "Resetting n8n environment..."
        print_info "Stopping and removing containers..."
        docker compose down -v
        
        print_info "Removing generated files..."
        rm -rf secrets/ certs/
        
        print_info "Cleaning up Docker resources..."
        docker volume prune -f
        docker network prune -f
        
        print_success "Environment reset completed!"
        print_info "Run deployment script to set up again."
        ;;
        
    clean)
        print_step "Cleaning up unused Docker resources..."
        print_info "Removing unused containers..."
        docker container prune -f
        
        print_info "Removing unused images..."
        docker image prune -f
        
        print_info "Removing unused volumes..."
        docker volume prune -f
        
        print_info "Removing unused networks..."
        docker network prune -f
        
        print_success "Cleanup completed!"
        ;;
        
    *)
        if [ -z "$ACTION" ]; then
            show_help
        else
            print_error "Unknown action: $ACTION"
            show_help
            exit 1
        fi
        ;;
esac 