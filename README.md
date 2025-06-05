# Secure n8n Docker Deployment

A comprehensive, production-ready n8n deployment with queue mode, SSL/TLS security, and enterprise-grade features.

## 🚀 Features

- **Queue Mode**: Horizontal scaling with multiple worker instances
- **SSL/TLS Security**: End-to-end encryption with Traefik reverse proxy
- **Database Security**: PostgreSQL with SSL and authentication
- **Redis Security**: Password-protected message broker
- **Secrets Management**: Docker secrets for sensitive data
- **Network Isolation**: Multi-tier network architecture
- **Automated Setup**: PowerShell scripts for complete deployment
- **Monitoring**: Health checks and logging
- **Backup & Recovery**: Automated backup scripts

## 📋 Prerequisites

- Windows 10/11 with PowerShell 5.1+
- Docker Desktop for Windows
- Docker Compose v2+
- 4GB+ RAM recommended
- Domain name (for SSL certificates)

## 🏗️ Architecture

```
Internet → Traefik (SSL) → n8n Main Instance → PostgreSQL
                        ↓
                    Redis Queue ← n8n Workers
```

### Components

| Service | Purpose | Network | SSL |
|---------|---------|---------|-----|
| Traefik | Reverse proxy & SSL termination | web | ✅ |
| n8n Main | UI, API, workflow management | web, backend | ✅ |
| n8n Workers | Workflow execution | backend | ✅ |
| PostgreSQL | Database with SSL | database | ✅ |
| Redis | Message queue | backend | 🔐 |

## 🚀 Quick Start

### 1. Clone and Setup

```powershell
# Navigate to your project directory
cd D:\source\repos\n8nDocker

# Run complete setup (generates secrets, certificates, and deploys)
.\scripts\Deploy-N8N.ps1 -All -Domain "n8n.yourdomain.com"
```

### 2. Access n8n

- URL: `https://n8n.yourdomain.com`
- Username: `admin`
- Password: Check `secrets\SECRETS_SUMMARY.md`

## 📁 Directory Structure

```
D:\source\repos\n8nDocker\
├── docker-compose.yml          # Main deployment configuration
├── .env                        # Environment variables
├── .env.template              # Environment template
├── README.md                  # This file
├── scripts\                   # PowerShell automation scripts
│   ├── Deploy-N8N.ps1         # Main deployment script
│   ├── Manage-N8N.ps1         # Management operations
│   ├── Generate-Secrets.ps1   # Password and key generation
│   └── Generate-Certificates.ps1 # SSL certificate generation
├── secrets\                   # Generated secrets (DO NOT COMMIT)
│   ├── postgres_password.txt
│   ├── redis_password.txt
│   ├── n8n_encryption_key.txt
│   ├── n8n_admin_password.txt
│   └── SECRETS_SUMMARY.md
├── certs\                     # SSL certificates (DO NOT COMMIT)
│   ├── ca.crt
│   ├── ca.key
│   ├── server.crt
│   ├── server.key
│   └── fullchain.pem
└── config\                    # Additional configuration files
    ├── nginx.conf             # Alternative reverse proxy
    ├── postgres-init.sql      # Database initialization
    └── redis.conf             # Redis configuration
```

## 🔧 Detailed Setup

### Step 1: Generate Secrets

```powershell
.\scripts\Generate-Secrets.ps1 -Domain "n8n.yourdomain.com"
```

This creates:
- Secure passwords for all services
- Encryption keys for n8n
- Environment configuration file

### Step 2: Generate SSL Certificates

```powershell
.\scripts\Generate-Certificates.ps1 -Domain "n8n.yourdomain.com"
```

This creates:
- Self-signed CA certificate
- Server certificate for your domain
- Certificate chain for Traefik

### Step 3: Create Docker Networks

```powershell
.\scripts\Deploy-N8N.ps1 -CreateNetworks
```

### Step 4: Deploy Services

```powershell
.\scripts\Deploy-N8N.ps1 -Deploy
```

## 🔐 Security Features

### Network Security
- **Multi-tier networks**: Separation of web, backend, and database layers
- **Internal networks**: Database isolated from external access
- **No-new-privileges**: Containers run with security restrictions

### Authentication & Authorization
- **Docker secrets**: Sensitive data stored securely
- **PostgreSQL SSL**: Encrypted database connections
- **Redis authentication**: Password-protected message broker
- **Basic auth**: n8n protected with username/password

### SSL/TLS Configuration
- **Traefik SSL termination**: Automatic certificate management
- **Security headers**: HSTS, CSP, and other security headers
- **TLS 1.2/1.3**: Modern encryption protocols only

### Container Security
- **Non-root users**: All containers run as unprivileged users
- **Read-only filesystems**: Where possible
- **Resource limits**: Memory and CPU constraints
- **Health checks**: Automatic service monitoring

## 🛠️ Management

### Service Management

```powershell
# Check status
.\scripts\Manage-N8N.ps1 -Action status

# View logs
.\scripts\Manage-N8N.ps1 -Action logs -Follow

# Restart services
.\scripts\Manage-N8N.ps1 -Action restart

# Scale workers
.\scripts\Manage-N8N.ps1 -Action scale -Workers 4
```

### Backup & Recovery

```powershell
# Create backup
.\scripts\Manage-N8N.ps1 -Action backup

# Backup to specific location
.\scripts\Manage-N8N.ps1 -Action backup -BackupPath "D:\Backups"
```

### Updates

```powershell
# Update to latest n8n version
.\scripts\Manage-N8N.ps1 -Action update
```

## 📊 Monitoring

### Health Checks
- PostgreSQL: Database connectivity
- Redis: Message broker status
- n8n: Application health endpoints

### Logging
```powershell
# All services
docker compose logs -f

# Specific service
docker compose logs -f n8n

# Worker logs
docker compose logs -f n8n-worker-1
```

### Metrics
```powershell
# Resource usage
docker stats

# Service status
docker compose ps
```

## 🔧 Configuration

### Environment Variables

Key variables in `.env`:

```bash
# Domain
N8N_HOST=n8n.yourdomain.com
WEBHOOK_URL=https://n8n.yourdomain.com/

# Security
N8N_SECURE_COOKIE=true
N8N_BASIC_AUTH_ACTIVE=true

# Queue Mode
EXECUTIONS_MODE=queue
QUEUE_HEALTH_CHECK_ACTIVE=true

# Performance
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_TIMEOUT=3600
```

### Scaling Workers

Adjust worker count based on workload:

```powershell
# Scale to 4 workers
.\scripts\Manage-N8N.ps1 -Action scale -Workers 4

# Or edit docker-compose.yml and restart
docker compose up -d --scale n8n-worker-1=4
```

### SSL Certificate Management

For production, replace self-signed certificates:

1. Obtain certificates from a trusted CA
2. Replace files in `certs/` directory
3. Restart Traefik: `docker compose restart traefik`

## 🚨 Troubleshooting

### Common Issues

#### Services won't start
```powershell
# Check logs
.\scripts\Manage-N8N.ps1 -Action logs

# Check Docker networks
docker network ls

# Recreate networks
docker network rm web
.\scripts\Deploy-N8N.ps1 -CreateNetworks
```

#### SSL Certificate Issues
```powershell
# Regenerate certificates
.\scripts\Generate-Certificates.ps1 -Domain "your-domain.com"

# Check certificate validity
openssl x509 -in certs\server.crt -text -noout
```

#### Database Connection Issues
```powershell
# Check PostgreSQL logs
docker compose logs postgres

# Test database connection
docker compose exec postgres psql -U n8n -d n8n -c "SELECT version();"
```

#### Redis Connection Issues
```powershell
# Check Redis logs
docker compose logs redis

# Test Redis connection
docker compose exec redis redis-cli ping
```

### Performance Tuning

#### Memory Issues
- Increase Docker Desktop memory allocation
- Adjust worker concurrency in docker-compose.yml
- Scale workers instead of increasing concurrency

#### Database Performance
- Monitor PostgreSQL logs for slow queries
- Adjust PostgreSQL configuration in docker-compose.yml
- Consider connection pooling for high-load scenarios

## 🔒 Security Best Practices

### Production Checklist

- [ ] Replace self-signed certificates with CA-issued certificates
- [ ] Change default passwords
- [ ] Enable 2FA in n8n
- [ ] Configure firewall rules
- [ ] Set up log monitoring
- [ ] Implement backup strategy
- [ ] Review and update regularly

### Secrets Management

- Never commit secrets to version control
- Use external secret management for production
- Rotate passwords regularly
- Monitor access logs

### Network Security

- Use VPN for administrative access
- Implement IP whitelisting
- Monitor network traffic
- Regular security audits

## 📚 Additional Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)

## 🤝 Support

For issues and questions:

1. Check the troubleshooting section
2. Review Docker and n8n logs
3. Consult the official n8n documentation
4. Check the n8n community forum

## 📄 License

This deployment configuration is provided as-is under the MIT License. n8n itself is licensed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).

---

**⚠️ Important**: This setup includes self-signed certificates suitable for development and testing. For production use, obtain certificates from a trusted Certificate Authority or use Let's Encrypt.