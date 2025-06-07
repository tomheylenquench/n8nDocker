#!/bin/bash

# deploy-n8n.sh
# Bash script to deploy the secure n8n Docker environment

set -e

# Default values
GENERATE_SECRETS=false
GENERATE_CERTS=false
CREATE_NETWORKS=false
DEPLOY=false
ALL=false
DOMAIN="n8n.yourdomain.com"
EMAIL="n8n@localdomain.com"

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy secure n8n Docker environment

OPTIONS:
    -s, --generate-secrets   Generate passwords and keys
    -c, --generate-certs     Generate SSL certificates
    -n, --create-networks    Create Docker networks
    -y, --deploy            Deploy services only
    -a, --all               Complete setup and deployment
    -d, --domain DOMAIN     Domain name (default: n8n.yourdomain.com)
    -e, --email EMAIL       Email address (default: n8n@localdomain.com)
    -h, --help              Show this help message

EXAMPLES:
    $0 --all                     # Complete setup and deployment
    $0 --generate-secrets        # Generate passwords and keys
    $0 --generate-certs          # Generate SSL certificates
    $0 --create-networks         # Create Docker networks
    $0 --deploy                  # Deploy services only

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--generate-secrets)
            GENERATE_SECRETS=true
            shift
            ;;
        -c|--generate-certs)
            GENERATE_CERTS=true
            shift
            ;;
        -n|--create-networks)
            CREATE_NETWORKS=true
            shift
            ;;
        -y|--deploy)
            DEPLOY=true
            shift
            ;;
        -a|--all)
            ALL=true
            shift
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
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

# Main deployment logic
echo -e "${BLUE}🐳 n8n Secure Docker Deployment Script${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check prerequisites
print_step "Checking prerequisites..."

if ! test_docker_running; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

if ! test_docker_compose_available; then
    print_error "Docker Compose is not available. Please install Docker Compose and try again."
    exit 1
fi

print_success "Docker and Docker Compose are available"

# Change to project directory
PROJECT_ROOT=$(dirname "$(readlink -f "$0")")/../
cd "$PROJECT_ROOT"
print_info "Working directory: $(pwd)"

# Generate secrets if requested or if All is specified
if [[ "$GENERATE_SECRETS" == "true" || "$ALL" == "true" ]]; then
    print_step "Generating secrets..."
    bash "$(dirname "$0")/generate-secrets.sh" --domain "$DOMAIN" --email "$EMAIL"
    if [ $? -ne 0 ]; then
        print_error "Failed to generate secrets"
        exit 1
    fi
fi

# Generate certificates if requested or if All is specified
if [[ "$GENERATE_CERTS" == "true" || "$ALL" == "true" ]]; then
    print_step "Generating SSL certificates..."
    bash "$(dirname "$0")/generate-certificates.sh" --domain "$DOMAIN"
    if [ $? -ne 0 ]; then
        print_error "Failed to generate certificates"
        exit 1
    fi
fi

# Create Docker networks if requested or if All is specified
if [[ "$CREATE_NETWORKS" == "true" || "$ALL" == "true" ]]; then
    print_step "Creating Docker networks..."
    
    # Check if web network exists
    if ! docker network ls --filter name=web --format "{{.Name}}" | grep -q "^web$"; then
        print_info "Creating 'web' network..."
        docker network create web
        if [ $? -ne 0 ]; then
            print_error "Failed to create 'web' network"
            exit 1
        fi
    else
        print_success "'web' network already exists"
    fi
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    if [ -f ".env.template" ]; then
        print_warning ".env file not found. Copying from template..."
        cp ".env.template" ".env"
        print_warning "Please edit .env file with your domain and settings before deploying!"
        
        if [[ "$DEPLOY" != "true" && "$ALL" != "true" ]]; then
            print_info "Deployment skipped. Edit .env file and run with --deploy flag."
            exit 0
        fi
    else
        print_error ".env file not found and no template available"
        exit 1
    fi
fi

# Validate required files
print_step "Validating required files..."

REQUIRED_FILES=(
    "docker-compose.yml"
    ".env"
    "secrets/postgres_password.txt"
    "secrets/redis_password.txt"
    "secrets/n8n_encryption_key.txt"
    "secrets/n8n_admin_password.txt"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file missing: $file"
        print_info "Run with --all flag to generate all required files"
        exit 1
    fi
done

print_success "All required files present"

# Deploy if requested or if All is specified
if [[ "$DEPLOY" == "true" || "$ALL" == "true" ]]; then
    print_step "Deploying n8n environment..."
    
    # Load environment variables from .env file
    print_info "Loading environment variables from .env file..."
    if [ -f ".env" ]; then
        set -a  # Automatically export all variables
        source ".env"
        set +a  # Turn off automatic export
        print_success "Environment variables loaded"
    fi
    
    # Pull latest images
    print_info "Pulling latest Docker images..."
    docker compose pull
    
    # Start services
    print_info "Starting services..."
    docker compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "🎉 Deployment successful!"
        
        # Wait for services to be ready
        print_info "Waiting for services to be ready..."
        sleep 30
        
        # Check service status
        print_step "Checking service status..."
        docker compose ps
        
        # Display access information
        echo -e "\n${YELLOW}📋 Access Information:${NC}"
        echo -e "${CYAN}🌐 n8n URL: https://$DOMAIN${NC}"
        echo -e "${CYAN}👤 Username: admin${NC}"
        
        if [ -f "secrets/n8n_admin_password.txt" ]; then
            PASSWORD=$(cat "secrets/n8n_admin_password.txt")
            echo -e "${CYAN}🔑 Password: $PASSWORD${NC}"
        fi
        
        echo -e "\n${YELLOW}📊 Monitoring Commands:${NC}"
        echo -e "${GRAY}docker compose logs -f${NC}"
        echo -e "${GRAY}docker compose ps${NC}"
        echo -e "${GRAY}docker stats${NC}"
        
        echo -e "\n${YELLOW}🔧 Management Commands:${NC}"
        echo -e "${GRAY}docker compose stop${NC}"
        echo -e "${GRAY}docker compose start${NC}"
        echo -e "${GRAY}docker compose restart${NC}"
        echo -e "${GRAY}docker compose down${NC}"
        
    else
        print_error "Deployment failed"
        print_info "Check logs with: docker compose logs"
        exit 1
    fi
fi

# Show help if no options provided
if [[ "$GENERATE_SECRETS" != "true" && "$GENERATE_CERTS" != "true" && "$CREATE_NETWORKS" != "true" && "$DEPLOY" != "true" && "$ALL" != "true" ]]; then
    show_help
fi 