# Linux/macOS/WSL Guide

Complete setup guide for n8n Docker deployment on Linux, macOS, and Windows Subsystem for Linux (WSL) using Bash scripts for testing production-like environments locally.

## 📋 Prerequisites

✅ **Docker** and **Docker Compose** installed  
✅ **OpenSSL** (usually pre-installed on Linux/macOS)  
✅ **Bash 4.0+** (default on most modern systems)  
✅ **4GB+ RAM** recommended  
✅ **Domain name** ready (or use localhost for testing)  

### Installing Prerequisites

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install docker.io docker-compose-v2 openssl curl
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

**macOS (with Homebrew):**
```bash
brew install docker docker-compose openssl
# Start Docker Desktop manually or via Applications
```

**Alpine Linux:**
```bash
apk add docker docker-compose openssl curl
rc-update add docker boot
service docker start
```

**WSL2 on Windows:**
- Install Docker Desktop on Windows with WSL2 integration enabled
- OpenSSL is typically already available in WSL

## 🚀 Quick Start

Get your secure n8n deployment running in 5 minutes!

### Step 1: One-Command Deployment

```bash
# Navigate to the project directory
cd /path/to/n8nDocker

# Complete setup and deployment
./scripts/deploy-n8n.sh --all --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"
```

**For WSL users on Windows:**
```bash
# From Windows PowerShell/CMD
wsl ./scripts/deploy-n8n.sh --all --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"

# Or enter WSL first
wsl
cd /mnt/d/source/repos/n8nDocker
./scripts/deploy-n8n.sh --all --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"
```

**Replace `n8n.yourdomain.com` with your actual domain and `admin@yourdomain.com` with your email!**

**Note**: The email parameter is optional but recommended for certificate generation.

### Step 2: Wait for Services

The script will:
- ✅ Generate secure passwords and encryption keys
- ✅ Create SSL certificates
- ✅ Set up Docker networks
- ✅ Deploy all services

Wait for the "🎉 Deployment successful!" message.

**Note**: Workers may restart a few times during initial setup (2-3 minutes). This is normal while services synchronize.

### Step 3: Access n8n

1. **URL**: `https://n8n.yourdomain.com`
2. **Username**: `admin`
3. **Password**: Check the deployment output or view `secrets/SECRETS_INFO.md`

**Tip**: The `secrets/SECRETS_INFO.md` file contains all your login credentials and connection details.

### Step 4: Trust the Certificate (Development)

For self-signed certificates:

**Linux (Ubuntu/Debian):**
```bash
sudo cp certs/ca.crt /usr/local/share/ca-certificates/n8n-ca.crt
sudo update-ca-certificates
```

**macOS:**
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
```

**WSL (copy to Windows):**
- Copy `ca.crt` to Windows and import to "Trusted Root Certification Authorities"

## 📜 Bash Scripts Reference

### 1. **deploy-n8n.sh** - Master Deployment Script

```bash
# Complete setup and deployment with email
./scripts/deploy-n8n.sh --all --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"

# Individual steps
./scripts/deploy-n8n.sh --generate-secrets --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"
./scripts/deploy-n8n.sh --generate-certs --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"
./scripts/deploy-n8n.sh --create-networks
./scripts/deploy-n8n.sh --deploy

# Help
./scripts/deploy-n8n.sh --help
```

**Options:**
- `-s, --generate-secrets`: Generate passwords and encryption keys
- `-c, --generate-certs`: Generate SSL certificates
- `-n, --create-networks`: Create Docker networks
- `-y, --deploy`: Deploy services only
- `-a, --all`: Complete setup and deployment
- `-d, --domain DOMAIN`: Domain name (default: n8n.yourdomain.com)
- `-e, --email EMAIL`: Email address for certificate generation (optional, default: n8n@localdomain.com)

### 2. **generate-secrets.sh** - Secure Password Generation

```bash
# Basic usage
./scripts/generate-secrets.sh

# With custom domain and email
./scripts/generate-secrets.sh --domain "n8n.mycompany.com" --email "admin@mycompany.com"

# Help
./scripts/generate-secrets.sh --help
```

**Generated Secrets:**
- PostgreSQL password (24 characters)
- Redis password (24 characters)
- n8n encryption key (64 hex characters)
- n8n admin password (16 characters)
- JWT secret (64 hex characters)
- Webhook password (20 characters)

### 3. **generate-certificates.sh** - SSL Certificate Generation

```bash
# Basic usage
./scripts/generate-certificates.sh

# With custom domain and validity
./scripts/generate-certificates.sh --domain "n8n.mycompany.com" --validity 730

# Help
./scripts/generate-certificates.sh --help
```

**Options:**
- `-d, --domain DOMAIN`: Domain name (default: n8n.yourdomain.com)
- `-p, --path PATH`: Certificates path (default: certs)
- `-v, --validity DAYS`: Validity in days (default: 365)

### 4. **manage-n8n.sh** - Service Management

```bash
# Service control
./scripts/manage-n8n.sh start
./scripts/manage-n8n.sh stop
./scripts/manage-n8n.sh restart
./scripts/manage-n8n.sh status

# Logs
./scripts/manage-n8n.sh logs
./scripts/manage-n8n.sh logs n8n
./scripts/manage-n8n.sh logs --follow

# Scaling
./scripts/manage-n8n.sh scale 4  # Scale to 4 workers

# Maintenance
./scripts/manage-n8n.sh update
./scripts/manage-n8n.sh backup
./scripts/manage-n8n.sh clean

# Help
./scripts/manage-n8n.sh --help
```

**Actions:**
- `start/stop/restart`: Service control
- `status`: Show service status
- `logs [service]`: Show logs (optionally for specific service)
- `update`: Update to latest images
- `backup/restore`: Backup management
- `reset`: Complete environment reset
- `clean`: Clean up unused resources

## 🔧 Detailed Setup Process

### Step 1: Generate Secrets

```bash
./scripts/generate-secrets.sh --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"
```

This creates:
- Secure passwords for all services
- Encryption keys for n8n
- Environment configuration file (`.env`)
- Secrets summary file (`secrets/SECRETS_INFO.md`)

### Step 2: Generate SSL Certificates

```bash
./scripts/generate-certificates.sh --domain "n8n.yourdomain.com" --email "admin@yourdomain.com"
```

This creates:
- Self-signed CA certificate for local testing
- Server certificate for your domain
- Certificate chain for Traefik
- Certificate information file (`certs/CERTIFICATE_INFO.md`)

### Step 3: Create Docker Networks

```bash
./scripts/deploy-n8n.sh --create-networks
```

Creates the `web` network for Traefik communication.

### Step 4: Deploy Services

```bash
./scripts/deploy-n8n.sh --deploy
```

Starts all services:
- Traefik (reverse proxy)
- PostgreSQL (database)
- Redis (message queue)
- n8n main instance
- n8n worker instances

## 🛠️ Management Operations

### Service Management

```bash
# Check status
./scripts/manage-n8n.sh status

# View logs
./scripts/manage-n8n.sh logs --follow

# Restart services
./scripts/manage-n8n.sh restart

# Scale workers (tested up to 4+ workers)
./scripts/manage-n8n.sh scale 4
```

### Backup & Recovery

```bash
# Create backup
./scripts/manage-n8n.sh backup

# List backups
ls -la backups/

# Restore from backup
./scripts/manage-n8n.sh restore backups/n8n_backup_20240607_143022.tar.gz
```

### Updates

```bash
# Update to latest n8n version
./scripts/manage-n8n.sh update
```

### Monitoring

```bash
# All services logs
docker compose logs -f

# Specific service
docker compose logs -f n8n

# Worker logs
docker compose logs -f n8n-worker-1

# Resource usage
docker stats

# Service status
docker compose ps
```

## 🎯 What You Get

After successful deployment:

- **Secure n8n** with SSL/TLS encryption
- **Queue mode** with 2 worker instances (scalable)
- **PostgreSQL** database with SSL
- **Redis** message broker
- **Traefik** reverse proxy
- **Automated backups** capability
- **Health monitoring** for all services

## 🔧 WSL Usage from Windows

If you're using WSL from Windows:

### Method 1: Direct WSL Commands
```bash
# Run scripts through WSL from PowerShell/CMD
wsl ./scripts/deploy-n8n.sh --all --domain "n8n.mydomain.com"
wsl ./scripts/manage-n8n.sh status
wsl ./scripts/manage-n8n.sh logs --follow
```

### Method 2: Enter WSL Environment
```bash
# Enter WSL
wsl

# Navigate to project (adjust path as needed)
cd /mnt/d/source/repos/n8nDocker

# Run scripts normally
./scripts/deploy-n8n.sh --all
./scripts/manage-n8n.sh status
```

### WSL Path Mapping
- Windows: `D:\source\repos\n8nDocker`
- WSL: `/mnt/d/source/repos/n8nDocker`

## 🚨 Platform-Specific Troubleshooting

### Common Issues

#### "Permission denied" executing scripts
```bash
# Fix script permissions
chmod +x scripts/*.sh

# For WSL from Windows
wsl chmod +x scripts/*.sh
```

#### "Docker not found"
```bash
# Check Docker status (Linux)
sudo systemctl status docker
sudo systemctl start docker

# Check Docker status (macOS)
brew services list | grep docker

# For WSL - ensure Docker Desktop integration is enabled
```

#### "OpenSSL not found"
```bash
# Ubuntu/Debian
sudo apt install openssl

# macOS
brew install openssl

# Alpine
apk add openssl
```

#### Certificate trust issues
```bash
# Regenerate certificates
./scripts/generate-certificates.sh --domain "your-domain.com"

# Check certificate validity
openssl x509 -in certs/server.crt -text -noout

# Linux: Update CA certificates
sudo update-ca-certificates

# macOS: Check keychain
security find-certificate -a -c "n8n-CA"
```

#### "Required file missing"
```bash
# Ensure you're in the correct directory
pwd
# Should show your project directory

# Check if secrets exist
ls -la secrets/

# If missing, regenerate
./scripts/generate-secrets.sh --domain "your-domain.com"
```

### WSL-Specific Issues

#### File permissions in WSL
```bash
# WSL may show different permissions
# Files should be executable for scripts
ls -la scripts/

# Fix if needed
chmod +x scripts/*.sh
```

#### Docker integration issues
```bash
# Check if Docker is accessible from WSL
docker version

# If issues, restart Docker Desktop and ensure WSL integration is enabled
# Docker Desktop -> Settings -> Resources -> WSL Integration
```

#### Path issues
```bash
# Use WSL paths, not Windows paths in .env files
# Correct: /mnt/d/source/repos/n8nDocker
# Incorrect: D:\source\repos\n8nDocker

# Convert Windows path to WSL path
wslpath "D:\source\repos\n8nDocker"
```

### Performance Issues

#### High Memory Usage
```bash
# Check Docker resource usage
docker stats

# Scale workers instead of increasing concurrency
./scripts/manage-n8n.sh scale 3

# Monitor system resources
htop  # Linux
top   # macOS/Linux
```

#### Slow Startup
```bash
# Check available disk space
df -h

# Check Docker system resources
docker system df
docker system prune  # Clean up if needed

# For WSL: Check Windows disk space for Docker Desktop
```

### Platform-Specific Features

#### Linux systemd integration
```bash
# Create systemd service (optional)
sudo tee /etc/systemd/system/n8n-docker.service > /dev/null <<EOF
[Unit]
Description=n8n Docker Compose
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/n8nDocker
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable n8n-docker
sudo systemctl start n8n-docker
```

#### macOS launchd integration
```bash
# Create launchd service (optional)
mkdir -p ~/Library/LaunchAgents

cat > ~/Library/LaunchAgents/com.n8n.docker.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.n8n.docker</string>
    <key>WorkingDirectory</key>
    <string>/path/to/n8nDocker</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/docker</string>
        <string>compose</string>
        <string>up</string>
        <string>-d</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.n8n.docker.plist
```

## 📂 Linux/macOS/WSL File Structure

```
├── scripts/                     # Bash scripts
│   ├── deploy-n8n.sh           # 🚀 Main deployment
│   ├── manage-n8n.sh           # 🛠️ Management operations
│   ├── generate-secrets.sh     # 🔐 Password generation
│   └── generate-certificates.sh # 🔒 SSL certificates
├── secrets/                     # 🔐 Generated secrets (DO NOT COMMIT)
│   ├── postgres_password.txt
│   ├── redis_password.txt
│   ├── n8n_encryption_key.txt
│   ├── n8n_admin_password.txt
│   ├── jwt_secret.txt
│   ├── webhook_password.txt
│   └── SECRETS_INFO.md          # 📋 Credentials summary
├── certs/                       # 🔒 SSL certificates (DO NOT COMMIT)
│   ├── ca.crt                   # CA certificate
│   ├── ca.key                   # CA private key
│   ├── server.crt               # Server certificate
│   ├── server.key               # Server private key
│   ├── fullchain.pem            # Certificate chain
│   └── CERTIFICATE_INFO.md      # 📋 Certificate details
├── backups/                     # 💾 Generated backups
│   └── n8n_backup_YYYYMMDD_HHMMSS.tar.gz
├── docker-compose.yml           # 🐳 Docker configuration
├── .env                         # ⚙️ Environment variables
└── .env.template               # 📝 Environment template
```

## ⚡ Bash Tips & Tricks

### Useful Aliases
```bash
# Add to ~/.bashrc or ~/.zshrc
alias n8n-status='./scripts/manage-n8n.sh status'
alias n8n-logs='./scripts/manage-n8n.sh logs --follow'
alias n8n-deploy='./scripts/deploy-n8n.sh --all'
alias n8n-backup='./scripts/manage-n8n.sh backup'

# Reload shell configuration
source ~/.bashrc  # or source ~/.zshrc
```

### Environment Variables
```bash
# Set for current session
export N8N_LOG_LEVEL=debug
export N8N_DOMAIN="n8n.mycompany.com"

# Use in scripts
./scripts/deploy-n8n.sh --all --domain "$N8N_DOMAIN"

# View n8n-related environment variables
env | grep N8N
```

### Tab Completion
```bash
# Most shells support tab completion for file paths
./scripts/deploy-n8n.sh --<TAB>

# Use history for command repetition
history | grep "scripts/"
!!  # Repeat last command
```

## 🔄 Migration from Windows PowerShell

If migrating from Windows PowerShell scripts:

1. **Secrets and certificates are compatible** - no regeneration needed
2. **Docker Compose configuration is identical**
3. **Environment variables work the same**
4. **Only scripts are different** (Bash vs PowerShell)

```bash
# Use existing secrets and certificates from Windows
# Just run the Linux deployment
./scripts/deploy-n8n.sh --deploy
```

## 🔐 Security Features

- **Automatic password generation** with OpenSSL random generation
- **File permissions** set to 600 for sensitive files
- **SSL certificates** with proper SAN (Subject Alternative Names)
- **Docker secrets** for secure credential management
- **No hardcoded passwords** in any configuration files

## 🆘 Support & Resources

### Script Help
```bash
# Get help for any script
./scripts/deploy-n8n.sh --help
./scripts/manage-n8n.sh --help
./scripts/generate-secrets.sh --help
./scripts/generate-certificates.sh --help
```

### Platform-Specific Resources
- **Linux**: [Docker Engine Installation](https://docs.docker.com/engine/install/)
- **macOS**: [Docker Desktop for Mac](https://docs.docker.com/desktop/mac/)
- **WSL**: [Docker Desktop WSL Integration](https://docs.docker.com/desktop/windows/wsl/)

### Common Log Locations
- **Container logs**: `docker compose logs [service]`
- **System logs**: `/var/log/` (Linux), `/usr/local/var/log/` (macOS)
- **Docker logs**: `journalctl -u docker` (systemd), `brew services` (macOS)

### Debugging Commands
```bash
# Check script syntax
bash -n scripts/deploy-n8n.sh

# Run scripts with debug output
bash -x scripts/deploy-n8n.sh --help

# Check generated files
find . -name "*.txt" -o -name "*.crt" -o -name "*.key" | xargs ls -la

# Monitor real-time logs
./scripts/manage-n8n.sh logs --follow &
# Press Ctrl+C to stop
```

---

**⚡ Pro Tip**: Create a local configuration file for your domain and email:

```bash
# Create ~/.n8n-config
echo 'export N8N_DOMAIN="n8n.mycompany.com"' >> ~/.n8n-config
echo 'export N8N_EMAIL="admin@mycompany.com"' >> ~/.n8n-config

# Source it before running scripts
source ~/.n8n-config
./scripts/deploy-n8n.sh --all --domain "$N8N_DOMAIN" --email "$N8N_EMAIL"

# Or add to your shell profile for permanent use
echo 'export N8N_DOMAIN="n8n.mycompany.com"' >> ~/.bashrc  # or ~/.zshrc
echo 'export N8N_EMAIL="admin@mycompany.com"' >> ~/.bashrc  # or ~/.zshrc
source ~/.bashrc  # reload shell configuration
``` 