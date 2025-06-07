#!/bin/bash

# generate-secrets.sh
# Bash script to generate secure passwords and keys for n8n deployment

set -e

# Default values
SECRETS_PATH="secrets"
DOMAIN="n8n.yourdomain.com"
EMAIL="n8n@localdomain.com"

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate secure passwords and keys for n8n deployment

OPTIONS:
    -d, --domain DOMAIN      Domain name (default: n8n.yourdomain.com)
    -e, --email EMAIL        Email address (default: n8n@localdomain.com)
    -p, --path PATH          Secrets path (default: secrets)
    -h, --help              Show this help message

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -p|--path)
            SECRETS_PATH="$2"
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

# Function to generate random password
generate_password() {
    local length=${1:-32}
    if command -v openssl &> /dev/null; then
        openssl rand -base64 $((length * 3 / 4)) | tr -d "=+/" | cut -c1-${length}
    elif [ -c /dev/urandom ]; then
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w ${length} | head -n 1
    else
        # Fallback method using date and random
        echo $RANDOM$(date +%s) | md5sum | head -c ${length}
    fi
}

# Function to generate encryption key
generate_encryption_key() {
    if command -v openssl &> /dev/null; then
        openssl rand -hex 32
    else
        # Fallback method
        cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 64 | head -n 1
    fi
}

# Ensure secrets directory exists
mkdir -p "$SECRETS_PATH"

print_step "Generating secure passwords and keys for n8n deployment..."

# Generate PostgreSQL password
print_info "🔐 Generating PostgreSQL password..."
POSTGRES_PASSWORD=$(generate_password 24)
echo -n "$POSTGRES_PASSWORD" > "$SECRETS_PATH/postgres_password.txt"
chmod 600 "$SECRETS_PATH/postgres_password.txt"

# Generate Redis password
print_info "🔐 Generating Redis password..."
REDIS_PASSWORD=$(generate_password 24)
echo -n "$REDIS_PASSWORD" > "$SECRETS_PATH/redis_password.txt"
chmod 600 "$SECRETS_PATH/redis_password.txt"

# Generate n8n encryption key
print_info "🔐 Generating n8n encryption key..."
N8N_ENCRYPTION_KEY=$(generate_encryption_key)
echo -n "$N8N_ENCRYPTION_KEY" > "$SECRETS_PATH/n8n_encryption_key.txt"
chmod 600 "$SECRETS_PATH/n8n_encryption_key.txt"

# Generate n8n admin password
print_info "🔐 Generating n8n admin password..."
N8N_ADMIN_PASSWORD=$(generate_password 16)
echo -n "$N8N_ADMIN_PASSWORD" > "$SECRETS_PATH/n8n_admin_password.txt"
chmod 600 "$SECRETS_PATH/n8n_admin_password.txt"

# Generate JWT secret
print_info "🔐 Generating JWT secret..."
JWT_SECRET=$(generate_encryption_key)
echo -n "$JWT_SECRET" > "$SECRETS_PATH/jwt_secret.txt"
chmod 600 "$SECRETS_PATH/jwt_secret.txt"

# Generate webhook password
print_info "🔐 Generating webhook password..."
WEBHOOK_PASSWORD=$(generate_password 20)
echo -n "$WEBHOOK_PASSWORD" > "$SECRETS_PATH/webhook_password.txt"
chmod 600 "$SECRETS_PATH/webhook_password.txt"

# Create or update .env file
print_info "📝 Creating/updating .env file..."
ENV_FILE=".env"

# Read existing .env file or use template
if [ -f ".env.template" ]; then
    cp ".env.template" "$ENV_FILE"
elif [ ! -f "$ENV_FILE" ]; then
    # Create basic .env file if neither exists
    cat > "$ENV_FILE" << EOF
# n8n Configuration
N8N_DOMAIN=$DOMAIN
N8N_EMAIL=$EMAIL
N8N_PROTOCOL=https
N8N_PORT=443

# Database Configuration
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password

# Redis Configuration
REDIS_PASSWORD_FILE=/run/secrets/redis_password

# n8n Security
N8N_ENCRYPTION_KEY_FILE=/run/secrets/n8n_encryption_key
N8N_USER_MANAGEMENT_JWT_SECRET_FILE=/run/secrets/jwt_secret

# Webhook Security
N8N_WEBHOOK_TUNNEL_AUTH_TOKEN_FILE=/run/secrets/webhook_password

# Timezone
GENERIC_TIMEZONE=UTC
TZ=UTC

# Network
TRAEFIK_WEB_NETWORK=web

# Logging
N8N_LOG_LEVEL=info
EOF
fi

# Update domain and email in .env file if they exist
if command -v sed &> /dev/null; then
    sed -i.bak "s/^N8N_DOMAIN=.*/N8N_DOMAIN=$DOMAIN/" "$ENV_FILE" 2>/dev/null || true
    sed -i.bak "s/^N8N_EMAIL=.*/N8N_EMAIL=$EMAIL/" "$ENV_FILE" 2>/dev/null || true
    rm -f "$ENV_FILE.bak"
fi

# Generate secrets summary file
SECRETS_INFO_PATH="$SECRETS_PATH/SECRETS_INFO.md"
cat > "$SECRETS_INFO_PATH" << EOF
# Secrets Information
Generated on: $(date "+%Y-%m-%d %H:%M:%S")

## Generated Secrets
- **postgres_password.txt**: PostgreSQL database password (24 chars)
- **redis_password.txt**: Redis cache password (24 chars)  
- **n8n_encryption_key.txt**: n8n data encryption key (64 hex chars)
- **n8n_admin_password.txt**: n8n admin user password (16 chars)
- **jwt_secret.txt**: JWT signing secret (64 hex chars)
- **webhook_password.txt**: Webhook authentication token (20 chars)

## Configuration
- Domain: $DOMAIN
- Email: $EMAIL
- Environment file: .env

## Security Notes
- All password files have 600 permissions (owner read-only)
- Never commit secrets to version control
- Store backups securely if needed
- Rotate secrets regularly in production

## Usage
These secrets are automatically mounted in Docker containers via Docker secrets.
The .env file contains references to these secret files.

## Admin Access
- Username: admin
- Password: $(cat "$SECRETS_PATH/n8n_admin_password.txt")
- URL: https://$DOMAIN

## Backup Command
To backup all secrets:
tar -czf n8n-secrets-backup-\$(date +%Y%m%d).tar.gz secrets/

## Restore Command
To restore from backup:
tar -xzf n8n-secrets-backup-YYYYMMDD.tar.gz
EOF

chmod 600 "$SECRETS_INFO_PATH"

print_success "All secrets generated successfully!"
print_info "📁 PostgreSQL password: $SECRETS_PATH/postgres_password.txt"
print_info "📁 Redis password: $SECRETS_PATH/redis_password.txt"
print_info "📁 n8n encryption key: $SECRETS_PATH/n8n_encryption_key.txt"
print_info "📁 n8n admin password: $SECRETS_PATH/n8n_admin_password.txt"
print_info "📁 JWT secret: $SECRETS_PATH/jwt_secret.txt"
print_info "📁 Webhook password: $SECRETS_PATH/webhook_password.txt"
print_info "📁 Environment config: $ENV_FILE"
print_info "📁 Secrets info: $SECRETS_INFO_PATH"

echo
print_success "🎉 Secret generation complete!"
print_warning "⚠️  Keep these secrets secure and never commit to version control"
print_info "🔑 Admin password: $N8N_ADMIN_PASSWORD" 