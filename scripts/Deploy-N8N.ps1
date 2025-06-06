# Deploy-N8N.ps1
# PowerShell script to deploy the secure n8n Docker environment

param(
    [switch]$GenerateSecrets,
    [switch]$GenerateCerts,
    [switch]$CreateNetworks,
    [switch]$Deploy,
    [switch]$All,
    [string]$Domain = "n8n.yourdomain.com",
    [string]$Email = "n8n@localdomain.com"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "`n🚀 $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-DockerRunning {
    try {
        docker version | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-DockerComposeAvailable {
    try {
        docker compose version | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Main deployment logic
Write-Host "🐳 n8n Secure Docker Deployment Script" -ForegroundColor Blue
Write-Host "=======================================" -ForegroundColor Blue

# Check prerequisites
Write-Step "Checking prerequisites..."

if (-not (Test-DockerRunning)) {
    Write-Error "Docker is not running. Please start Docker Desktop and try again."
    exit 1
}

if (-not (Test-DockerComposeAvailable)) {
    Write-Error "Docker Compose is not available. Please install Docker Compose and try again."
    exit 1
}

Write-Info "Docker and Docker Compose are available ✅"

# Change to project directory
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot
Write-Info "Working directory: $projectRoot"

# Generate secrets if requested or if All is specified
if ($GenerateSecrets -or $All) {
    Write-Step "Generating secrets..."
    & "$PSScriptRoot\Generate-Secrets.ps1" -Domain $Domain -Email $Email
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to generate secrets"
        exit 1
    }
}

# Generate certificates if requested or if All is specified
if ($GenerateCerts -or $All) {
    Write-Step "Generating SSL certificates..."
    & "$PSScriptRoot\Generate-Certificates.ps1" -Domain $Domain
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to generate certificates"
        exit 1
    }
}

# Create Docker networks if requested or if All is specified
if ($CreateNetworks -or $All) {
    Write-Step "Creating Docker networks..."
    
    # Check if web network exists
    $webNetwork = docker network ls --filter name=web --format "{{.Name}}" | Where-Object { $_ -eq "web" }
    if (-not $webNetwork) {
        Write-Info "Creating 'web' network..."
        docker network create web
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create 'web' network"
            exit 1
        }
    } else {
        Write-Info "'web' network already exists ✅"
    }
}

# Check if .env file exists
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.template") {
        Write-Warning ".env file not found. Copying from template..."
        Copy-Item ".env.template" ".env"
        Write-Warning "Please edit .env file with your domain and settings before deploying!"
        
        if (-not $Deploy -and -not $All) {
            Write-Info "Deployment skipped. Edit .env file and run with -Deploy flag."
            exit 0
        }
    } else {
        Write-Error ".env file not found and no template available"
        exit 1
    }
}

# Validate required files
Write-Step "Validating required files..."

$requiredFiles = @(
    "docker-compose.yml",
    ".env",
    "secrets\postgres_password.txt",
    "secrets\redis_password.txt",
    "secrets\n8n_encryption_key.txt",
    "secrets\n8n_admin_password.txt"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Error "Required file missing: $file"
        Write-Info "Run with -All flag to generate all required files"
        exit 1
    }
}

Write-Info "All required files present ✅"

# Deploy if requested or if All is specified
if ($Deploy -or $All) {
    Write-Step "Deploying n8n environment..."
    
    # Load environment variables from .env file
    Write-Info "Loading environment variables from .env file..."
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match "^([^#][^=]*?)=(.*)$") {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                [Environment]::SetEnvironmentVariable($key, $value, "Process")
                Write-Verbose "Set $key"
            }
        }
        Write-Info "Environment variables loaded ✅"
    }
    
    # Pull latest images
    Write-Info "Pulling latest Docker images..."
    docker compose pull
    
    # Start services
    Write-Info "Starting services..."
    docker compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n🎉 Deployment successful!" -ForegroundColor Green
        
        # Wait for services to be ready
        Write-Info "Waiting for services to be ready..."
        Start-Sleep -Seconds 30
        
        # Check service status
        Write-Step "Checking service status..."
        docker compose ps
        
        # Display access information
        Write-Host "`n📋 Access Information:" -ForegroundColor Yellow
        Write-Host "🌐 n8n URL: https://$Domain" -ForegroundColor Cyan
        Write-Host "👤 Username: admin" -ForegroundColor Cyan
        
        if (Test-Path "secrets\n8n_admin_password.txt") {
            $password = Get-Content "secrets\n8n_admin_password.txt" -Raw
            Write-Host "🔑 Password: $password" -ForegroundColor Cyan
        }
        
        Write-Host "`n📊 Monitoring Commands:" -ForegroundColor Yellow
        Write-Host "docker compose logs -f" -ForegroundColor Gray
        Write-Host "docker compose ps" -ForegroundColor Gray
        Write-Host "docker stats" -ForegroundColor Gray
        
        Write-Host "`n🔧 Management Commands:" -ForegroundColor Yellow
        Write-Host "docker compose stop" -ForegroundColor Gray
        Write-Host "docker compose start" -ForegroundColor Gray
        Write-Host "docker compose restart" -ForegroundColor Gray
        Write-Host "docker compose down" -ForegroundColor Gray
        
    } else {
        Write-Error "Deployment failed"
        Write-Info "Check logs with: docker compose logs"
        exit 1
    }
}

if (-not $GenerateSecrets -and -not $GenerateCerts -and -not $CreateNetworks -and -not $Deploy -and -not $All) {
    Write-Host "`nUsage:" -ForegroundColor Yellow
    Write-Host "  .\Deploy-N8N.ps1 -All                    # Complete setup and deployment" -ForegroundColor Gray
    Write-Host "  .\Deploy-N8N.ps1 -GenerateSecrets        # Generate passwords and keys" -ForegroundColor Gray
    Write-Host "  .\Deploy-N8N.ps1 -GenerateCerts          # Generate SSL certificates" -ForegroundColor Gray
    Write-Host "  .\Deploy-N8N.ps1 -CreateNetworks         # Create Docker networks" -ForegroundColor Gray
    Write-Host "  .\Deploy-N8N.ps1 -Deploy                 # Deploy services only" -ForegroundColor Gray
    Write-Host "`nParameters:" -ForegroundColor Yellow
    Write-Host "  -Domain <domain>                         # Specify domain (default: n8n.yourdomain.com)" -ForegroundColor Gray
}