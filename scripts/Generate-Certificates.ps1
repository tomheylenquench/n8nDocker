# Generate-Certificates.ps1
# PowerShell script to generate self-signed SSL certificates for n8n deployment

param(
    [string]$CertsPath = "certs",
    [string]$Domain = "n8n.yourdomain.com",
    [int]$ValidityDays = 365
)

# Ensure certs directory exists
if (!(Test-Path $CertsPath)) {
    New-Item -ItemType Directory -Path $CertsPath -Force
}

Write-Host "🔒 Generating SSL certificates for n8n deployment..." -ForegroundColor Green

# Check if OpenSSL is available
$opensslPath = Get-Command openssl -ErrorAction SilentlyContinue
if (-not $opensslPath) {
    Write-Host "⚠️  OpenSSL not found in PATH. Attempting to use PowerShell PKI module..." -ForegroundColor Yellow
    
    # Use PowerShell PKI module for certificate generation
    try {
        # Generate CA certificate
        Write-Host "📜 Generating Certificate Authority (CA)..." -ForegroundColor Cyan
        
        $caParams = @{
            Subject = "CN=n8n-CA,O=n8n-deployment,C=US"
            KeyAlgorithm = "RSA"
            KeyLength = 4096
            HashAlgorithm = "SHA256"
            NotAfter = (Get-Date).AddDays($ValidityDays)
            CertStoreLocation = "Cert:\CurrentUser\My"
            KeyUsage = "CertSign", "CRLSign", "DigitalSignature"
            Type = "Custom"
        }
        
        $caCert = New-SelfSignedCertificate @caParams
        
        # Export CA certificate
        $caPath = Join-Path $CertsPath "ca.crt"
        Export-Certificate -Cert $caCert -FilePath $caPath -Type CERT | Out-Null
        
        # Export CA private key (requires manual export)
        Write-Host "⚠️  CA private key must be exported manually from certificate store" -ForegroundColor Yellow
        
        # Generate server certificate signed by CA
        Write-Host "🌐 Generating server certificate for $Domain..." -ForegroundColor Cyan
        
        $serverParams = @{
            Subject = "CN=$Domain,O=n8n-deployment,C=US"
            KeyAlgorithm = "RSA"
            KeyLength = 2048
            HashAlgorithm = "SHA256"
            NotAfter = (Get-Date).AddDays($ValidityDays)
            CertStoreLocation = "Cert:\CurrentUser\My"
            Signer = $caCert
            DnsName = $Domain, "localhost", "127.0.0.1"
            KeyUsage = "DigitalSignature", "KeyEncipherment"
            Type = "SSLServerAuthentication"
        }
        
        $serverCert = New-SelfSignedCertificate @serverParams
        
        # Export server certificate
        $certPath = Join-Path $CertsPath "server.crt"
        Export-Certificate -Cert $serverCert -FilePath $certPath -Type CERT | Out-Null
        
        Write-Host "✅ Certificates generated using PowerShell PKI" -ForegroundColor Green
        Write-Host "📁 CA Certificate: $caPath" -ForegroundColor Cyan
        Write-Host "📁 Server Certificate: $certPath" -ForegroundColor Cyan
        Write-Host "⚠️  Private keys are in Windows Certificate Store - export manually if needed" -ForegroundColor Yellow
        
    } catch {
        Write-Host "❌ Failed to generate certificates with PowerShell PKI: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Please install OpenSSL or use an external certificate authority" -ForegroundColor Yellow
        return
    }
} else {
    # Use OpenSSL for certificate generation
    Write-Host "🔧 Using OpenSSL for certificate generation..." -ForegroundColor Cyan
    
    # Generate CA private key
    Write-Host "🔑 Generating CA private key..." -ForegroundColor Cyan
    $caKeyPath = Join-Path $CertsPath "ca.key"
    & openssl genrsa -out $caKeyPath 4096
    
    # Generate CA certificate
    Write-Host "📜 Generating CA certificate..." -ForegroundColor Cyan
    $caPath = Join-Path $CertsPath "ca.crt"
    & openssl req -new -x509 -days $ValidityDays -key $caKeyPath -out $caPath -subj "/C=US/O=n8n-deployment/CN=n8n-CA"
    
    # Generate server private key
    Write-Host "🔑 Generating server private key..." -ForegroundColor Cyan
    $serverKeyPath = Join-Path $CertsPath "server.key"
    & openssl genrsa -out $serverKeyPath 2048
    
    # Generate server certificate signing request
    Write-Host "📝 Generating certificate signing request..." -ForegroundColor Cyan
    $csrPath = Join-Path $CertsPath "server.csr"
    & openssl req -new -key $serverKeyPath -out $csrPath -subj "/C=US/O=n8n-deployment/CN=$Domain"
    
    # Create certificate extensions file
    $extPath = Join-Path $CertsPath "server.ext"
    $extContent = @"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $Domain
DNS.2 = localhost
IP.1 = 127.0.0.1
"@
    $extContent | Out-File -FilePath $extPath -Encoding ASCII
    
    # Generate server certificate signed by CA
    Write-Host "🌐 Generating server certificate..." -ForegroundColor Cyan
    $certPath = Join-Path $CertsPath "server.crt"
    & openssl x509 -req -in $csrPath -CA $caPath -CAkey $caKeyPath -CAcreateserial -out $certPath -days $ValidityDays -extensions v3_req -extfile $extPath
    
    # Generate combined certificate chain
    Write-Host "🔗 Creating certificate chain..." -ForegroundColor Cyan
    $chainPath = Join-Path $CertsPath "fullchain.pem"
    Get-Content $certPath, $caPath | Out-File -FilePath $chainPath -Encoding ASCII
    
    # Set appropriate permissions (Windows)
    Write-Host "🔒 Setting certificate permissions..." -ForegroundColor Cyan
    icacls $serverKeyPath /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null
    
    # Clean up temporary files
    Remove-Item $csrPath -ErrorAction SilentlyContinue
    Remove-Item $extPath -ErrorAction SilentlyContinue
    
    Write-Host "✅ SSL certificates generated successfully!" -ForegroundColor Green
    Write-Host "📁 CA Certificate: $caPath" -ForegroundColor Cyan
    Write-Host "📁 CA Private Key: $caKeyPath" -ForegroundColor Cyan
    Write-Host "📁 Server Certificate: $certPath" -ForegroundColor Cyan
    Write-Host "📁 Server Private Key: $serverKeyPath" -ForegroundColor Cyan
    Write-Host "📁 Certificate Chain: $chainPath" -ForegroundColor Cyan
}

# Generate certificate information file
$certInfoContent = @"
# SSL Certificate Information
Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Certificate Details
Domain: $Domain
Validity: $ValidityDays days
Algorithm: RSA
Key Length: 2048 bits (server), 4096 bits (CA)

## Files Generated
- ca.crt: Certificate Authority certificate
- ca.key: Certificate Authority private key
- server.crt: Server certificate for $Domain
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
To avoid browser warnings, add ca.crt to your system's trusted root certificates:
1. Double-click ca.crt
2. Click "Install Certificate"
3. Choose "Local Machine" and "Trusted Root Certification Authorities"
"@

$certInfoPath = Join-Path $CertsPath "CERTIFICATE_INFO.md"
$certInfoContent | Out-File -FilePath $certInfoPath -Encoding UTF8

Write-Host "📋 Certificate information saved to: $certInfoPath" -ForegroundColor Yellow
Write-Host "`n🎉 Certificate generation complete!" -ForegroundColor Green
Write-Host "⚠️  For production use, replace with certificates from a trusted CA" -ForegroundColor Red