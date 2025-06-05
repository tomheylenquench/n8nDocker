# Manage-N8N.ps1
# PowerShell script for managing the n8n Docker deployment

param(
    [ValidateSet("status", "logs", "start", "stop", "restart", "scale", "backup", "restore", "update", "cleanup")]
    [string]$Action,
    [string]$Service = "",
    [int]$Workers = 2,
    [string]$BackupPath = ".\backups",
    [switch]$Follow
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

function Show-Status {
    Write-Step "Service Status"
    docker compose ps
    
    Write-Host "`n📊 Resource Usage:" -ForegroundColor Yellow
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}"
    
    Write-Host "`n🔍 Health Checks:" -ForegroundColor Yellow
    $services = @("postgres", "redis", "n8n")
    foreach ($service in $services) {
        $health = docker compose exec $service sh -c "echo 'Service is running'" 2>$null
        if ($health) {
            Write-Host "✅ $service is healthy" -ForegroundColor Green
        } else {
            Write-Host "❌ $service is not responding" -ForegroundColor Red
        }
    }
}

function Show-Logs {
    param([string]$ServiceName, [bool]$FollowLogs)
    
    if ($ServiceName) {
        Write-Step "Showing logs for $ServiceName"
        if ($FollowLogs) {
            docker compose logs -f $ServiceName
        } else {
            docker compose logs --tail=100 $ServiceName
        }
    } else {
        Write-Step "Showing logs for all services"
        if ($FollowLogs) {
            docker compose logs -f
        } else {
            docker compose logs --tail=50
        }
    }
}

function Start-Services {
    param([string]$ServiceName)
    
    if ($ServiceName) {
        Write-Step "Starting $ServiceName"
        docker compose start $ServiceName
    } else {
        Write-Step "Starting all services"
        docker compose start
    }
    
    Start-Sleep -Seconds 5
    Show-Status
}

function Stop-Services {
    param([string]$ServiceName)
    
    if ($ServiceName) {
        Write-Step "Stopping $ServiceName"
        docker compose stop $ServiceName
    } else {
        Write-Step "Stopping all services"
        docker compose stop
    }
}

function Restart-Services {
    param([string]$ServiceName)
    
    if ($ServiceName) {
        Write-Step "Restarting $ServiceName"
        docker compose restart $ServiceName
    } else {
        Write-Step "Restarting all services"
        docker compose restart
    }
    
    Start-Sleep -Seconds 10
    Show-Status
}

function Scale-Workers {
    param([int]$WorkerCount)
    
    Write-Step "Scaling workers to $WorkerCount instances"
    
    # Scale worker services
    docker compose up -d --scale n8n-worker-1=$WorkerCount --scale n8n-worker-2=0
    
    Start-Sleep -Seconds 10
    Show-Status
    
    Write-Info "Workers scaled to $WorkerCount instances"
}

function Backup-Data {
    param([string]$BackupLocation)
    
    Write-Step "Creating backup"
    
    # Create backup directory
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = Join-Path $BackupLocation "n8n-backup-$timestamp"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    Write-Info "Backup directory: $backupDir"
    
    # Backup database
    Write-Info "Backing up PostgreSQL database..."
    $dbPassword = Get-Content "secrets\postgres_password.txt" -Raw
    $env:PGPASSWORD = $dbPassword
    
    docker compose exec postgres pg_dump -U n8n -d n8n > "$backupDir\database.sql"
    
    # Backup n8n data
    Write-Info "Backing up n8n data..."
    docker compose exec n8n tar -czf /tmp/n8n-data.tar.gz -C /home/node/.n8n .
    docker cp (docker compose ps -q n8n):/tmp/n8n-data.tar.gz "$backupDir\n8n-data.tar.gz"
    
    # Backup secrets
    Write-Info "Backing up secrets..."
    Copy-Item -Path "secrets" -Destination "$backupDir\secrets" -Recurse
    
    # Backup certificates
    Write-Info "Backing up certificates..."
    Copy-Item -Path "certs" -Destination "$backupDir\certs" -Recurse
    
    # Create backup info
    $backupInfo = @"
# n8n Backup Information
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Version: $(docker compose exec n8n n8n --version 2>$null)

## Contents
- database.sql: PostgreSQL database dump
- n8n-data.tar.gz: n8n application data
- secrets/: All secret files
- certs/: SSL certificates

## Restore Instructions
1. Stop current deployment: docker compose down
2. Restore database: docker compose exec postgres psql -U n8n -d n8n < database.sql
3. Restore n8n data: docker cp n8n-data.tar.gz container:/tmp/ && docker compose exec n8n tar -xzf /tmp/n8n-data.tar.gz -C /home/node/.n8n
4. Copy secrets and certs back to project directory
5. Start deployment: docker compose up -d
"@
    
    $backupInfo | Out-File -FilePath "$backupDir\README.md" -Encoding UTF8
    
    Write-Host "✅ Backup completed: $backupDir" -ForegroundColor Green
}

function Update-Services {
    Write-Step "Updating n8n services"
    
    # Pull latest images
    Write-Info "Pulling latest images..."
    docker compose pull
    
    # Recreate services with new images
    Write-Info "Recreating services..."
    docker compose up -d --force-recreate
    
    Start-Sleep -Seconds 15
    Show-Status
    
    Write-Info "Update completed"
}

function Cleanup-System {
    Write-Step "Cleaning up Docker system"
    
    Write-Warning "This will remove unused Docker images, containers, and networks"
    $confirm = Read-Host "Continue? (y/N)"
    
    if ($confirm -eq "y" -or $confirm -eq "Y") {
        # Remove unused containers
        Write-Info "Removing unused containers..."
        docker container prune -f
        
        # Remove unused images
        Write-Info "Removing unused images..."
        docker image prune -f
        
        # Remove unused networks
        Write-Info "Removing unused networks..."
        docker network prune -f
        
        # Remove unused volumes (be careful!)
        Write-Warning "Removing unused volumes..."
        docker volume prune -f
        
        Write-Host "✅ Cleanup completed" -ForegroundColor Green
    } else {
        Write-Info "Cleanup cancelled"
    }
}

# Main script logic
Write-Host "🔧 n8n Management Script" -ForegroundColor Blue
Write-Host "========================" -ForegroundColor Blue

# Change to project directory
$projectRoot = Split-Path $PSScriptRoot -Parent
Set-Location $projectRoot

# Check if deployment exists
if (-not (Test-Path "docker-compose.yml")) {
    Write-Error "docker-compose.yml not found. Run Deploy-N8N.ps1 first."
    exit 1
}

switch ($Action) {
    "status" {
        Show-Status
    }
    "logs" {
        Show-Logs -ServiceName $Service -FollowLogs $Follow
    }
    "start" {
        Start-Services -ServiceName $Service
    }
    "stop" {
        Stop-Services -ServiceName $Service
    }
    "restart" {
        Restart-Services -ServiceName $Service
    }
    "scale" {
        Scale-Workers -WorkerCount $Workers
    }
    "backup" {
        Backup-Data -BackupLocation $BackupPath
    }
    "update" {
        Update-Services
    }
    "cleanup" {
        Cleanup-System
    }
    default {
        Write-Host "`nUsage:" -ForegroundColor Yellow
        Write-Host "  .\Manage-N8N.ps1 -Action status                    # Show service status" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action logs [-Service <name>]    # Show logs" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action logs -Follow              # Follow logs" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action start [-Service <name>]   # Start services" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action stop [-Service <name>]    # Stop services" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action restart [-Service <name>] # Restart services" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action scale -Workers <count>    # Scale worker instances" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action backup                    # Create backup" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action update                    # Update to latest images" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action cleanup                   # Clean up Docker system" -ForegroundColor Gray
        Write-Host "`nExamples:" -ForegroundColor Yellow
        Write-Host "  .\Manage-N8N.ps1 -Action logs -Service n8n -Follow" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action scale -Workers 4" -ForegroundColor Gray
        Write-Host "  .\Manage-N8N.ps1 -Action backup -BackupPath D:\Backups" -ForegroundColor Gray
    }
}