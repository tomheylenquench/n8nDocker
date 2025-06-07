#!/bin/bash

# generate-certificates.sh
# Bash script to generate self-signed SSL certificates for n8n deployment

set -e

# Default values
CERTS_PATH="certs"
DOMAIN="n8n.yourdomain.com"
VALIDITY_DAYS=365

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Generate SSL certificates for n8n deployment

OPTIONS:
    -d, --domain DOMAIN      Domain name (default: n8n.yourdomain.com)
    -p, --path PATH          Certificates path (default: certs)
    -v, --validity DAYS      Validity in days (default: 365)
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
        -p|--path)
            CERTS_PATH="$2"
            shift 2
            ;;
        -v|--validity)
            VALIDITY_DAYS="$2"
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

# Ensure certs directory exists
mkdir -p "$CERTS_PATH"

print_step "Generating SSL certificates for n8n deployment..."

# Check if OpenSSL is available
if ! command -v openssl &> /dev/null; then
    print_error "OpenSSL is not installed. Please install OpenSSL first."
    echo "On Ubuntu/Debian: sudo apt update && sudo apt install openssl"
    echo "On macOS: brew install openssl"
    exit 1
fi

print_info "Using OpenSSL for certificate generation..."

# Generate CA private key
print_info "🔑 Generating CA private key..."
CA_KEY_PATH="$CERTS_PATH/ca.key"
openssl genrsa -out "$CA_KEY_PATH" 4096

# Generate CA certificate
print_info "📜 Generating CA certificate..."
CA_PATH="$CERTS_PATH/ca.crt"
openssl req -new -x509 -days "$VALIDITY_DAYS" -key "$CA_KEY_PATH" -out "$CA_PATH" \
    -subj "/C=US/O=n8n-deployment/CN=n8n-CA"

# Generate server private key
print_info "🔑 Generating server private key..."
SERVER_KEY_PATH="$CERTS_PATH/server.key"
openssl genrsa -out "$SERVER_KEY_PATH" 2048

# Generate server certificate signing request
print_info "📝 Generating certificate signing request..."
CSR_PATH="$CERTS_PATH/server.csr"
openssl req -new -key "$SERVER_KEY_PATH" -out "$CSR_PATH" \
    -subj "/C=US/O=n8n-deployment/CN=$DOMAIN"

# Create certificate extensions file
print_info "📋 Creating certificate extensions..."
EXT_PATH="$CERTS_PATH/server.ext"
cat > "$EXT_PATH" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Generate server certificate signed by CA
print_info "🌐 Generating server certificate..."
CERT_PATH="$CERTS_PATH/server.crt"
openssl x509 -req -in "$CSR_PATH" -CA "$CA_PATH" -CAkey "$CA_KEY_PATH" \
    -CAcreateserial -out "$CERT_PATH" -days "$VALIDITY_DAYS" \
    -extfile "$EXT_PATH"

# Generate combined certificate chain
print_info "🔗 Creating certificate chain..."
CHAIN_PATH="$CERTS_PATH/fullchain.pem"
cat "$CERT_PATH" "$CA_PATH" > "$CHAIN_PATH"

# Set appropriate permissions
print_info "🔒 Setting certificate permissions..."
chmod 600 "$SERVER_KEY_PATH" "$CA_KEY_PATH"
chmod 644 "$CERT_PATH" "$CA_PATH" "$CHAIN_PATH"

# Clean up temporary files
rm -f "$CSR_PATH" "$EXT_PATH"

print_success "SSL certificates generated successfully!"
print_info "📁 CA Certificate: $CA_PATH"
print_info "📁 CA Private Key: $CA_KEY_PATH"
print_info "📁 Server Certificate: $CERT_PATH"
print_info "📁 Server Private Key: $SERVER_KEY_PATH"
print_info "📁 Certificate Chain: $CHAIN_PATH"

# Generate certificate information file
CERT_INFO_PATH="$CERTS_PATH/CERTIFICATE_INFO.md"
cat > "$CERT_INFO_PATH" << EOF
# SSL Certificate Information
Generated on: $(date "+%Y-%m-%d %H:%M:%S")

## Certificate Details
Domain: $DOMAIN
Validity: $VALIDITY_DAYS days
Algorithm: RSA
Key Length: 2048 bits (server), 4096 bits (CA)

## Files Generated
- ca.crt: Certificate Authority certificate
- ca.key: Certificate Authority private key
- server.crt: Server certificate for $DOMAIN
- server.key: Server private key
- fullchain.pem: Combined certificate chain (server + CA)

## Usage in Docker Compose
The certificates are automatically mounted in the containers:
- Traefik: Uses server.crt and server.key
- PostgreSQL: Uses ca.crt for SSL connections
- n8n: Trusts ca.crt for internal communications

## Security Notes
- These are self-signed certificates for development/testing
- For production, use certificates from a trusted CA
- Keep private keys secure and never commit to version control
- Consider using Let's Encrypt for production deployments

## Trust the CA Certificate
### Linux (Ubuntu/Debian):
sudo cp ca.crt /usr/local/share/ca-certificates/n8n-ca.crt
sudo update-ca-certificates

### macOS:
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt

### Windows:
Import ca.crt into "Trusted Root Certification Authorities" store
EOF

print_info "📋 Certificate information saved to: $CERT_INFO_PATH"
echo
print_success "🎉 Certificate generation complete!"
print_warning "⚠️  For production use, replace with certificates from a trusted CA" 