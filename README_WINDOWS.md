# Windows PowerShell Guide

Complete setup guide for n8n Docker deployment on Windows using PowerShell scripts.

## 📋 Prerequisites

✅ **Windows 10/11** with PowerShell 5.1+  
✅ **Docker Desktop for Windows** installed and running  
✅ **Docker Compose v2+** (included with Docker Desktop)  
✅ **4GB+ RAM** recommended  
✅ **Domain name** ready (or use localhost for testing)  

### Installing Prerequisites

1. **Docker Desktop**: Download from [docker.com](https://www.docker.com/products/docker-desktop)
2. **PowerShell**: Usually pre-installed, verify with `$PSVersionTable.PSVersion`

## 🚀 Quick Start

Get your secure n8n deployment running in 5 minutes!

### Step 1: One-Command Deployment

Open PowerShell as Administrator and run:

```powershell
# Navigate to the project directory
cd D:\source\repos\n8nDocker

# Complete setup and deployment
.\scripts\Deploy-N8N.ps1 -All -Domain "n8n.yourdomain.com"
```

**Replace `n8n.yourdomain.com` with your actual domain!**

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
3. **Password**: Check the deployment output or view `secrets\SECRETS_INFO.md`

**Tip**: The `secrets\SECRETS_INFO.md` file contains all your login credentials and connection details.

### Step 4: Trust the Certificate (Development)

For self-signed certificates:
1. Download `certs\ca.crt`
2. Double-click and install to "Trusted Root Certification Authorities"
3. Refresh your browser

## 📜 PowerShell Scripts Reference

### 1. **Deploy-N8N.ps1** - Master Deployment Script

```powershell
# Complete setup and deployment
.\scripts\Deploy-N8N.ps1 -All -Domain "n8n.yourdomain.com"

# Individual steps
.\scripts\Deploy-N8N.ps1 -GenerateSecrets -Domain "n8n.yourdomain.com"
.\scripts\Deploy-N8N.ps1 -GenerateCerts -Domain "n8n.yourdomain.com"
.\scripts\Deploy-N8N.ps1 -CreateNetworks
.\scripts\Deploy-N8N.ps1 -Deploy

# Help
Get-Help .\scripts\Deploy-N8N.ps1 -Detailed
```

**Parameters:**
- `-GenerateSecrets`: Generate passwords and encryption keys
- `-GenerateCerts`: Generate SSL certificates
- `-CreateNetworks`: Create Docker networks
- `-Deploy`: Deploy services only
- `-All`: Complete setup and deployment
- `-Domain`: Domain name (default: n8n.yourdomain.com)
- `-Email`: Email address (default: n8n@localdomain.com)

### 2. **Generate-Secrets.ps1** - Secure Password Generation

```powershell
# Basic usage
.\scripts\Generate-Secrets.ps1

# With custom domain
.\scripts\Generate-Secrets.ps1 -Domain "n8n.mycompany.com" -Email "admin@mycompany.com"

# Help
Get-Help .\scripts\Generate-Secrets.ps1
```

**Generated Secrets:**
- PostgreSQL password (24 characters)
- Redis password (24 characters)
- n8n encryption key (64 hex characters)
- n8n admin password (16 characters)
- JWT secret (64 hex characters)
- Webhook password (20 characters)

### 3. **Generate-Certificates.ps1** - SSL Certificate Generation

```powershell
# Basic usage
.\scripts\Generate-Certificates.ps1

# With custom domain and validity
.\scripts\Generate-Certificates.ps1 -Domain "n8n.mycompany.com" -ValidityDays 730

# Help
Get-Help .\scripts\Generate-Certificates.ps1
```

**Generated Certificates:**
- CA certificate and private key
- Server certificate and private key
- Full certificate chain
- Certificate information file

### 4. **Manage-N8N.ps1** - Service Management

```powershell
# Service control
.\scripts\Manage-N8N.ps1 -Action start
.\scripts\Manage-N8N.ps1 -Action stop
.\scripts\Manage-N8N.ps1 -Action restart
.\scripts\Manage-N8N.ps1 -Action status

# Logs
.\scripts\Manage-N8N.ps1 -Action logs
.\scripts\Manage-N8N.ps1 -Action logs -Service n8n
.\scripts\Manage-N8N.ps1 -Action logs -Follow

# Scaling
.\scripts\Manage-N8N.ps1 -Action scale -Workers 4

# Maintenance
.\scripts\Manage-N8N.ps1 -Action update
.\scripts\Manage-N8N.ps1 -Action backup
.\scripts\Manage-N8N.ps1 -Action backup -BackupPath "D:\Backups"

# Help
Get-Help .\scripts\Manage-N8N.ps1 -Detailed
```

## 🔧 Detailed Setup Process

### Step 1: Generate Secrets

```powershell
.\scripts\Generate-Secrets.ps1 -Domain "n8n.yourdomain.com"
```

This creates:
- Secure passwords for all services
- Encryption keys for n8n
- Environment configuration file (`.env`)
- Secrets summary file (`secrets\SECRETS_INFO.md`)

### Step 2: Generate SSL Certificates

```powershell
.\scripts\Generate-Certificates.ps1 -Domain "n8n.yourdomain.com"
```

This creates:
- Self-signed CA certificate
- Server certificate for your domain
- Certificate chain for Traefik
- Certificate information file (`certs\CERTIFICATE_INFO.md`)

### Step 3: Create Docker Networks

```powershell
.\scripts\Deploy-N8N.ps1 -CreateNetworks
```

Creates the `web` network for Traefik communication.

### Step 4: Deploy Services

```powershell
.\scripts\Deploy-N8N.ps1 -Deploy
```

Starts all services:
- Traefik (reverse proxy)
- PostgreSQL (database)
- Redis (message queue)
- n8n main instance
- n8n worker instances

## 🛠️ Management Operations

### Service Management

```powershell
# Check status
.\scripts\Manage-N8N.ps1 -Action status

# View logs
.\scripts\Manage-N8N.ps1 -Action logs -Follow

# Restart services
.\scripts\Manage-N8N.ps1 -Action restart

# Scale workers (tested up to 4+ workers)
.\scripts\Manage-N8N.ps1 -Action scale -Workers 4
```

### Backup & Recovery

```powershell
# Create backup
.\scripts\Manage-N8N.ps1 -Action backup

# Backup to specific location
.\scripts\Manage-N8N.ps1 -Action backup -BackupPath "D:\Backups"

# View backup contents
Get-ChildItem "backups\" | Sort-Object LastWriteTime -Descending
```

**Note**: The backup function successfully backs up the PostgreSQL database, secrets, and certificates.

### Updates

```powershell
# Update to latest n8n version
.\scripts\Manage-N8N.ps1 -Action update
```

### Monitoring

```powershell
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

## 🚨 Windows-Specific Troubleshooting

### Common Issues

#### "Docker not found"
```powershell
# Check if Docker Desktop is running
docker version

# If not found, restart Docker Desktop
# Or restart the Docker Desktop service
Restart-Service -Name "Docker Desktop Service" -Force
```

#### "PowerShell Execution Policy"
```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy to allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### "Network already exists"
```powershell
# Remove existing network
docker network rm web

# Re-run network creation
.\scripts\Deploy-N8N.ps1 -CreateNetworks
```

#### "Permission denied"
```powershell
# Run PowerShell as Administrator
# Right-click PowerShell -> "Run as Administrator"

# Check Docker Desktop is running
docker ps
```

#### "Certificate errors"
```powershell
# Install the CA certificate
# 1. Open certs\ca.crt
# 2. Click "Install Certificate"
# 3. Choose "Local Machine"
# 4. Select "Trusted Root Certification Authorities"

# Or use localhost for testing
# http://localhost:5678
```

#### "Workers keep restarting"
```powershell
# This is normal for the first 2-3 minutes
docker compose ps

# Check worker logs if it continues >5 minutes
docker compose logs n8n-worker-1

# Check Redis connectivity
docker compose logs redis
```

#### "Required file missing"
```powershell
# Ensure you're in the correct directory
Get-Location
# Should show: D:\source\repos\n8nDocker

# Check if secrets exist in current directory
Test-Path "secrets\postgres_password.txt"

# If false, regenerate secrets
.\scripts\Generate-Secrets.ps1 -Domain "your-domain.com"
```

### Performance Issues

#### High Memory Usage
```powershell
# Check Docker Desktop memory allocation
# Docker Desktop -> Settings -> Resources -> Advanced

# Scale workers instead of increasing concurrency
.\scripts\Manage-N8N.ps1 -Action scale -Workers 3

# Monitor resource usage
docker stats
```

#### Slow Startup
```powershell
# Check available disk space
Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, @{Name="FreeSpace(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}

# Check Docker Desktop resource allocation
# Increase memory if < 4GB allocated

# Disable Windows Defender real-time scanning for Docker directory (temporary)
```

### Windows-Specific Features

#### Windows Service Integration
```powershell
# Create Windows service for auto-start (optional)
# Note: Requires Docker Desktop to start automatically

# Check Docker Desktop startup settings
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object "Docker Desktop"
```

#### File Path Handling
```powershell
# Windows paths work in scripts
.\scripts\Generate-Certificates.ps1 -CertsPath "C:\MyProject\certs"

# Use forward slashes in .env files for Docker
# N8N_ADDITIONAL_TRUSTED_DOMAINS=example.com,localhost
```

#### Performance Monitoring
```powershell
# Windows Performance Monitor
# Add Docker-related counters for monitoring

# PowerShell resource monitoring
Get-Process | Where-Object {$_.ProcessName -like "*docker*"} | Select-Object ProcessName, WorkingSet, CPU
```

## 🔒 Windows Security Considerations

### Firewall Configuration
```powershell
# Check Windows Firewall status
Get-NetFirewallProfile | Select-Object Name, Enabled

# Docker Desktop typically handles firewall rules automatically
# For custom configurations, allow Docker Desktop through firewall
```

### Antivirus Exclusions
Add these directories to antivirus exclusions for better performance:
- Docker Desktop installation directory
- Project directory (`D:\source\repos\n8nDocker`)
- Docker volumes directory

### User Account Control (UAC)
- Run PowerShell as Administrator for initial setup
- Some Docker operations may require elevated privileges

## 📂 Windows File Structure

```
D:\source\repos\n8nDocker\
├── scripts\                     # PowerShell scripts
│   ├── Deploy-N8N.ps1           # 🚀 Main deployment
│   ├── Manage-N8N.ps1           # 🛠️ Management operations
│   ├── Generate-Secrets.ps1     # 🔐 Password generation
│   └── Generate-Certificates.ps1 # 🔒 SSL certificates
├── secrets\                     # 🔐 Generated secrets (DO NOT COMMIT)
│   ├── postgres_password.txt
│   ├── redis_password.txt
│   ├── n8n_encryption_key.txt
│   ├── n8n_admin_password.txt
│   ├── jwt_secret.txt
│   ├── webhook_password.txt
│   └── SECRETS_INFO.md          # 📋 Credentials summary
├── certs\                       # 🔒 SSL certificates (DO NOT COMMIT)
│   ├── ca.crt                   # CA certificate
│   ├── ca.key                   # CA private key
│   ├── server.crt               # Server certificate
│   ├── server.key               # Server private key
│   ├── fullchain.pem            # Certificate chain
│   └── CERTIFICATE_INFO.md      # 📋 Certificate details
├── docker-compose.yml           # 🐳 Docker configuration
├── .env                         # ⚙️ Environment variables
└── .env.template               # 📝 Environment template
```

## ⚡ PowerShell Tips & Tricks

### Useful Aliases
```powershell
# Create shortcuts for common commands
Set-Alias -Name n8n-status -Value ".\scripts\Manage-N8N.ps1 -Action status"
Set-Alias -Name n8n-logs -Value ".\scripts\Manage-N8N.ps1 -Action logs -Follow"
Set-Alias -Name n8n-deploy -Value ".\scripts\Deploy-N8N.ps1 -All"

# Use them
n8n-status
n8n-logs
```

### Script Parameters
```powershell
# All scripts support -WhatIf for testing (where applicable)
.\scripts\Deploy-N8N.ps1 -All -WhatIf

# Use -Verbose for detailed output
.\scripts\Generate-Secrets.ps1 -Verbose

# Tab completion works for parameters
.\scripts\Deploy-N8N.ps1 -<TAB>
```

### Environment Variables
```powershell
# View current environment
Get-ChildItem Env: | Where-Object {$_.Name -like "*N8N*"}

# Set temporary environment variables
$env:N8N_LOG_LEVEL = "debug"
```

## 🔄 Migration from Linux/WSL

If migrating from Linux or WSL:

1. **Secrets and certificates are compatible** - no regeneration needed
2. **Docker Compose configuration is identical**
3. **Environment variables work the same**
4. **Only scripts are different** (PowerShell vs Bash)

```powershell
# Use existing secrets and certificates
# Just run the Windows deployment
.\scripts\Deploy-N8N.ps1 -Deploy
```

## 🆘 Support & Resources

### PowerShell Help
```powershell
# Get help for any script
Get-Help .\scripts\Deploy-N8N.ps1 -Full
Get-Help .\scripts\Manage-N8N.ps1 -Examples

# Show available parameters
Get-Help .\scripts\Generate-Secrets.ps1 -Parameter *
```

### Windows-Specific Resources
- [Docker Desktop for Windows Documentation](https://docs.docker.com/desktop/windows/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Windows Container Networking](https://docs.microsoft.com/en-us/virtualization/windowscontainers/container-networking/architecture)

### Common Logs Locations
- **Docker Desktop logs**: `%APPDATA%\Docker\log`
- **Container logs**: Available via `docker compose logs`
- **PowerShell transcripts**: Can be enabled with `Start-Transcript`

---

**⚡ Pro Tip**: Save your domain and email in PowerShell variables for easier reuse:

```powershell
$MyDomain = "n8n.mycompany.com"
$MyEmail = "admin@mycompany.com"

.\scripts\Deploy-N8N.ps1 -All -Domain $MyDomain -Email $MyEmail
``` 