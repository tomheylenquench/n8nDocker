# Generate-Secrets.ps1
# PowerShell script to generate secure passwords and encryption keys for n8n deployment

param(
    [string]$SecretsPath = "..\secrets",
    [string]$Domain = "n8n.yourdomain.com"
)

# Ensure secrets directory exists
if (!(Test-Path $SecretsPath)) {
    New-Item -ItemType Directory -Path $SecretsPath -Force
}

Write-Host "🔐 Generating secure secrets for n8n deployment..." -ForegroundColor Green

# Function to generate secure random password
function Generate-SecurePassword {
    param([int]$Length = 32)
    
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = ""
    $random = New-Object System.Random
    
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $chars[$random.Next(0, $chars.Length)]
    }
    
    return $password
}

# Function to generate hex encryption key
function Generate-EncryptionKey {
    param([int]$Length = 32)
    
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::Create()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    
    return [System.BitConverter]::ToString($bytes) -replace '-', ''
}

# Generate all required secrets
$secrets = @{
    "postgres_password" = Generate-SecurePassword -Length 24
    "redis_password" = Generate-SecurePassword -Length 24
    "n8n_encryption_key" = Generate-EncryptionKey -Length 32
    "n8n_admin_password" = Generate-SecurePassword -Length 16
    "jwt_secret" = Generate-EncryptionKey -Length 32
}

# Save secrets to individual files
foreach ($secret in $secrets.GetEnumerator()) {
    $filePath = Join-Path $SecretsPath "$($secret.Key).txt"
    $secret.Value | Out-File -FilePath $filePath -Encoding UTF8 -NoNewline
    Write-Host "✅ Generated $($secret.Key): $filePath" -ForegroundColor Cyan
}

# Generate .env file with references to secret files
$envContent = @"
# n8n Secure Docker Deployment Configuration
# Generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

# Domain Configuration
N8N_HOST=$Domain
N8N_PROTOCOL=https
WEBHOOK_URL=https://$Domain/
SSL_EMAIL=admin@$($Domain.Split('.')[1..2] -join '.')

# Authentication
N8N_USER=admin
N8N_PASSWORD_FILE=/run/secrets/n8n_admin_password

# Database Configuration
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password

# Redis Configuration
REDIS_PASSWORD_FILE=/run/secrets/redis_password

# n8n Configuration
N8N_ENCRYPTION_KEY_FILE=/run/secrets/n8n_encryption_key

# Security Settings
N8N_SECURE_COOKIE=true
N8N_BASIC_AUTH_ACTIVE=true
N8N_USER_MANAGEMENT_DISABLED=false

# Queue Mode Configuration
EXECUTIONS_MODE=queue
QUEUE_HEALTH_CHECK_ACTIVE=true
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379

# Performance Settings
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_PRUNE_MAX_COUNT=10000
EXECUTIONS_TIMEOUT=3600
N8N_GRACEFUL_SHUTDOWN_TIMEOUT=30

# Logging
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=console

# Timezone
GENERIC_TIMEZONE=UTC
TZ=UTC
"@

$envPath = Join-Path (Split-Path $SecretsPath -Parent) ".env"
$envContent | Out-File -FilePath $envPath -Encoding UTF8
Write-Host "✅ Generated environment file: $envPath" -ForegroundColor Cyan

# Generate secrets summary
$summaryContent = @"
# n8n Deployment Secrets Summary
Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Admin Credentials
Username: admin
Password: $($secrets["n8n_admin_password"])

## Database Credentials
Database: n8n
Username: n8n
Password: $($secrets["postgres_password"])

## Redis Password
Password: $($secrets["redis_password"])

## Encryption Key
Key: $($secrets["n8n_encryption_key"])

## Important Notes
- Keep this file secure and do not commit to version control
- All passwords are also stored in individual files in the secrets/ directory
- The encryption key must remain consistent across all n8n instances
- Change default passwords after first login

## Next Steps
1. Run Generate-Certificates.ps1 to create SSL certificates
2. Review and customize docker-compose.yml
3. Deploy with: docker-compose up -d
"@

$summaryPath = Join-Path $SecretsPath "SECRETS_SUMMARY.md"
$summaryContent | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host "✅ Generated secrets summary: $summaryPath" -ForegroundColor Yellow

Write-Host "`n🎉 Secret generation complete!" -ForegroundColor Green
Write-Host "📋 Summary saved to: $summaryPath" -ForegroundColor Yellow
Write-Host "⚠️  Keep these secrets secure and do not commit to version control!" -ForegroundColor Red