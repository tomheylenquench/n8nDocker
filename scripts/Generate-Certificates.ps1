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
        
        # Export CA certificate in PEM format
        $caPath = Join-Path $CertsPath "ca.crt"
        $caCertBytes = $caCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        $caCertBase64 = [Convert]::ToBase64String($caCertBytes)
        $caCertPem = "-----BEGIN CERTIFICATE-----`n"
        for ($i = 0; $i -lt $caCertBase64.Length; $i += 64) {
            $caCertPem += $caCertBase64.Substring($i, [Math]::Min(64, $caCertBase64.Length - $i)) + "`n"
        }
        $caCertPem += "-----END CERTIFICATE-----"
        $caCertPem | Out-File -FilePath $caPath -Encoding ASCII
        
        # Export CA private key using PowerShell
        Write-Host "🔑 Exporting CA private key..." -ForegroundColor Cyan
        $caKeyPath = Join-Path $CertsPath "ca.key"
        $caKeyPassword = ConvertTo-SecureString -String "temp" -Force -AsPlainText
        Export-PfxCertificate -Cert $caCert -FilePath "$CertsPath\ca.pfx" -Password $caKeyPassword | Out-Null
        
        # Convert PFX to PEM format for CA key
        if (Get-Command openssl -ErrorAction SilentlyContinue) {
            & openssl pkcs12 -in "$CertsPath\ca.pfx" -nocerts -out $caKeyPath -nodes -passin pass:temp
            & openssl rsa -in $caKeyPath -out $caKeyPath
        } else {
            # Enhanced diagnostics for PowerShell PKI key export
            Write-Host "🔍 Analyzing CA certificate private key properties..." -ForegroundColor Yellow
            Write-Host "📋 CA Certificate details:" -ForegroundColor Cyan
            Write-Host "   - Thumbprint: $($caCert.Thumbprint)" -ForegroundColor Gray
            Write-Host "   - Subject: $($caCert.Subject)" -ForegroundColor Gray
            Write-Host "   - HasPrivateKey: $($caCert.HasPrivateKey)" -ForegroundColor Gray
            
            try {
                # Get the private key and analyze its type
                $privateKey = $caCert.PrivateKey
                Write-Host "   - PrivateKey Type: $($privateKey.GetType().FullName)" -ForegroundColor Gray
                Write-Host "   - Key Size: $($privateKey.KeySize)" -ForegroundColor Gray
                
                                 # Handle different RSA key types properly
                 if ($privateKey -is [System.Security.Cryptography.RSACng]) {
                     Write-Host "🔧 Detected RSACng key, exporting directly..." -ForegroundColor Cyan
                     $keyBytes = $privateKey.ExportRSAPrivateKey()
                     $keyBase64 = [Convert]::ToBase64String($keyBytes)
                     
                     # Format as PEM
                     $caKeyPem = "-----BEGIN RSA PRIVATE KEY-----`n"
                     for ($i = 0; $i -lt $keyBase64.Length; $i += 64) {
                         $caKeyPem += $keyBase64.Substring($i, [Math]::Min(64, $keyBase64.Length - $i)) + "`n"
                     }
                     $caKeyPem += "-----END RSA PRIVATE KEY-----"
                     $caKeyPem | Out-File -FilePath $caKeyPath -Encoding ASCII
                     
                     Write-Host "✅ Successfully exported RSACng private key directly" -ForegroundColor Green
                     
                 } elseif ($privateKey -is [System.Security.Cryptography.RSACryptoServiceProvider]) {
                     Write-Host "🔧 Detected RSACryptoServiceProvider key, exporting..." -ForegroundColor Cyan
                     $keyBytes = $privateKey.ExportRSAPrivateKey()
                     $keyBase64 = [Convert]::ToBase64String($keyBytes)
                     
                     # Format as PEM
                     $caKeyPem = "-----BEGIN RSA PRIVATE KEY-----`n"
                     for ($i = 0; $i -lt $keyBase64.Length; $i += 64) {
                         $caKeyPem += $keyBase64.Substring($i, [Math]::Min(64, $keyBase64.Length - $i)) + "`n"
                     }
                     $caKeyPem += "-----END RSA PRIVATE KEY-----"
                     $caKeyPem | Out-File -FilePath $caKeyPath -Encoding ASCII
                     
                     Write-Host "✅ Successfully exported RSACryptoServiceProvider private key" -ForegroundColor Green
                     
                 } else {
                     throw "Unsupported private key type: $($privateKey.GetType().FullName)"
                 }
                
            } catch {
                Write-Host "❌ Failed to export CA private key: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "🔍 Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
                Write-Host "🔍 Stack Trace:" -ForegroundColor Gray
                Write-Host $_.Exception.StackTrace -ForegroundColor DarkGray
                throw
            }
        }
        
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
        
        # Export server certificate in PEM format
        $certPath = Join-Path $CertsPath "server.crt"
        $serverCertBytes = $serverCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        $serverCertBase64 = [Convert]::ToBase64String($serverCertBytes)
        $serverCertPem = "-----BEGIN CERTIFICATE-----`n"
        for ($i = 0; $i -lt $serverCertBase64.Length; $i += 64) {
            $serverCertPem += $serverCertBase64.Substring($i, [Math]::Min(64, $serverCertBase64.Length - $i)) + "`n"
        }
        $serverCertPem += "-----END CERTIFICATE-----"
        $serverCertPem | Out-File -FilePath $certPath -Encoding ASCII
        
        # Export server private key
        Write-Host "🔑 Exporting server private key..." -ForegroundColor Cyan
        $serverKeyPath = Join-Path $CertsPath "server.key"
        $serverKeyPassword = ConvertTo-SecureString -String "temp" -Force -AsPlainText
        Export-PfxCertificate -Cert $serverCert -FilePath "$CertsPath\server.pfx" -Password $serverKeyPassword | Out-Null
        
        # Convert server PFX to PEM format
        if (Get-Command openssl -ErrorAction SilentlyContinue) {
            & openssl pkcs12 -in "$CertsPath\server.pfx" -nocerts -out $serverKeyPath -nodes -passin pass:temp
            & openssl rsa -in $serverKeyPath -out $serverKeyPath
        } else {
            # Enhanced diagnostics for server key export
            Write-Host "🔍 Analyzing server certificate private key properties..." -ForegroundColor Yellow
            Write-Host "📋 Server Certificate details:" -ForegroundColor Cyan
            Write-Host "   - Thumbprint: $($serverCert.Thumbprint)" -ForegroundColor Gray
            Write-Host "   - Subject: $($serverCert.Subject)" -ForegroundColor Gray
            Write-Host "   - HasPrivateKey: $($serverCert.HasPrivateKey)" -ForegroundColor Gray
            
            try {
                # Get the private key and analyze its type
                $privateKey = $serverCert.PrivateKey
                Write-Host "   - PrivateKey Type: $($privateKey.GetType().FullName)" -ForegroundColor Gray
                Write-Host "   - Key Size: $($privateKey.KeySize)" -ForegroundColor Gray
                
                                 # Handle different RSA key types properly
                 if ($privateKey -is [System.Security.Cryptography.RSACng]) {
                     Write-Host "🔧 Detected RSACng key, exporting directly..." -ForegroundColor Cyan
                     $keyBytes = $privateKey.ExportRSAPrivateKey()
                     $keyBase64 = [Convert]::ToBase64String($keyBytes)
                     
                     # Format as PEM
                     $serverKeyPem = "-----BEGIN RSA PRIVATE KEY-----`n"
                     for ($i = 0; $i -lt $keyBase64.Length; $i += 64) {
                         $serverKeyPem += $keyBase64.Substring($i, [Math]::Min(64, $keyBase64.Length - $i)) + "`n"
                     }
                     $serverKeyPem += "-----END RSA PRIVATE KEY-----"
                     $serverKeyPem | Out-File -FilePath $serverKeyPath -Encoding ASCII
                     
                     Write-Host "✅ Successfully exported RSACng server private key directly" -ForegroundColor Green
                     
                 } elseif ($privateKey -is [System.Security.Cryptography.RSACryptoServiceProvider]) {
                     Write-Host "🔧 Detected RSACryptoServiceProvider key, exporting..." -ForegroundColor Cyan
                     $keyBytes = $privateKey.ExportRSAPrivateKey()
                     $keyBase64 = [Convert]::ToBase64String($keyBytes)
                     
                     # Format as PEM
                     $serverKeyPem = "-----BEGIN RSA PRIVATE KEY-----`n"
                     for ($i = 0; $i -lt $keyBase64.Length; $i += 64) {
                         $serverKeyPem += $keyBase64.Substring($i, [Math]::Min(64, $keyBase64.Length - $i)) + "`n"
                     }
                     $serverKeyPem += "-----END RSA PRIVATE KEY-----"
                     $serverKeyPem | Out-File -FilePath $serverKeyPath -Encoding ASCII
                     
                     Write-Host "✅ Successfully exported RSACryptoServiceProvider server private key" -ForegroundColor Green
                     
                 } else {
                     throw "Unsupported private key type: $($privateKey.GetType().FullName)"
                 }
                
            } catch {
                Write-Host "❌ Failed to export server private key: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "🔍 Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Gray
                Write-Host "🔍 Stack Trace:" -ForegroundColor Gray
                Write-Host $_.Exception.StackTrace -ForegroundColor DarkGray
                throw
            }
        }
        
        # Generate combined certificate chain
        Write-Host "🔗 Creating certificate chain..." -ForegroundColor Cyan
        $chainPath = Join-Path $CertsPath "fullchain.pem"
        Get-Content $certPath, $caPath | Out-File -FilePath $chainPath -Encoding ASCII
        
        # Clean up temporary PFX files
        Remove-Item "$CertsPath\ca.pfx" -ErrorAction SilentlyContinue
        Remove-Item "$CertsPath\server.pfx" -ErrorAction SilentlyContinue
        
        # Clean up certificates from store to avoid clutter
        Remove-Item "Cert:\CurrentUser\My\$($caCert.Thumbprint)" -ErrorAction SilentlyContinue
        Remove-Item "Cert:\CurrentUser\My\$($serverCert.Thumbprint)" -ErrorAction SilentlyContinue
        
        Write-Host "✅ Certificates generated using PowerShell PKI with key export" -ForegroundColor Green
        Write-Host "📁 CA Certificate: $caPath" -ForegroundColor Cyan
        Write-Host "📁 CA Private Key: $caKeyPath" -ForegroundColor Cyan
        Write-Host "📁 Server Certificate: $certPath" -ForegroundColor Cyan
        Write-Host "📁 Server Private Key: $serverKeyPath" -ForegroundColor Cyan
        Write-Host "📁 Certificate Chain: $chainPath" -ForegroundColor Cyan
        
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