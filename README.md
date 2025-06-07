# Secure n8n Docker Deployment

[![Deployment Status](https://img.shields.io/badge/status-verified%20working-green)](https://github.com/tomheylenquench/n8nDocker) [![Version](https://img.shields.io/badge/n8n-1.95.3-blue)](https://github.com/n8n-io/n8n) [![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE) [![Read Only](https://img.shields.io/badge/repository-read--only-red)](https://github.com/tomheylenquench/n8nDocker)

> **📢 NOTICE**: This is a **read-only repository**. It provides a complete, production-ready n8n deployment solution. For support, please refer to the documentation. Issues and pull requests are disabled.

A comprehensive, production-ready n8n deployment with queue mode, SSL/TLS security, and enterprise-grade features. Compatible with Windows, Linux, macOS, and WSL environments.

## 🚀 Features

- **Queue Mode**: Horizontal scaling with multiple worker instances
- **SSL/TLS Security**: End-to-end encryption with Traefik reverse proxy
- **Database Security**: PostgreSQL with SSL encryption and authentication
- **Redis Security**: Password-protected message broker
- **Secrets Management**: Docker secrets for sensitive data
- **Network Isolation**: Multi-tier network architecture
- **Cross-Platform**: Native scripts for Windows (PowerShell) and Linux/macOS/WSL (Bash)
- **Automated Setup**: One-command deployment scripts
- **Monitoring**: Health checks and comprehensive logging
- **Backup & Recovery**: Automated backup and restore functionality

## ✅ Verified Features

The following features have been tested and confirmed working across platforms:

- ✅ **Complete Deployment**: One-command deployment script works flawlessly
- ✅ **Cross-Platform Support**: PowerShell and Bash scripts with identical functionality
- ✅ **Service Health Monitoring**: All health checks pass (postgres, redis, n8n)
- ✅ **Log Management**: Service-specific and aggregate log viewing
- ✅ **Dynamic Scaling**: Successfully tested scaling from 2 to 3+ workers
- ✅ **Backup System**: Database, secrets, and certificates backup confirmed
- ✅ **Resource Monitoring**: CPU and memory usage tracking
- ✅ **SSL Configuration**: Traefik reverse proxy with SSL termination
- ✅ **Queue Processing**: Redis message broker with worker coordination
- ✅ **Network Isolation**: Multi-tier network security architecture
- ✅ **WSL Integration**: Seamless operation in Windows Subsystem for Linux

## 🖥️ Platform Support

This deployment supports multiple platforms with native scripts:

### 📘 [Windows Guide](README_WINDOWS.md)
- PowerShell scripts for Windows 10/11
- Docker Desktop integration
- Windows-specific setup and troubleshooting

### 🐧 [Linux/macOS/WSL Guide](README_LINUX_MACOS.md)
- Bash scripts for Linux, macOS, and WSL
- Cross-platform compatibility
- Unix-specific setup and troubleshooting

**Both script sets provide identical functionality and can be used interchangeably on the same project!**

## 🏗️ Architecture

```
Internet → Traefik (SSL) → n8n Main Instance → PostgreSQL
                        ↓
                    Redis Queue ← n8n Workers
```

### Components

| Service | Purpose | Network | SSL | Scaling |
|---------|---------|---------|-----|---------|
| Traefik | Reverse proxy & SSL termination | web | ✅ | Single |
| n8n Main | UI, API, workflow management | web, backend | ✅ | Single |
| n8n Workers | Workflow execution | backend | ✅ | Multiple |
| PostgreSQL | Database with SSL encryption | database | ✅ | Single |
| Redis | Message queue | backend | 🔐 | Single |

### Network Architecture

- **Web Network**: Public-facing services (Traefik, n8n main)
- **Backend Network**: Internal services communication
- **Database Network**: Isolated database access
- **No Direct Database Access**: Database only accessible via backend network

## 📁 Project Structure

```
├── README.md                    # This file - platform-agnostic guide
├── README_WINDOWS.md            # Windows/PowerShell specific guide
├── README_LINUX_MACOS.md        # Linux/macOS/WSL specific guide
├── docker-compose.yml           # Main deployment configuration
├── .env                         # Environment variables (generated)
├── .env.template               # Environment template
├── scripts/
│   ├── PowerShell Scripts (Windows)
│   │   ├── Deploy-N8N.ps1         # Main deployment script
│   │   ├── Manage-N8N.ps1         # Management operations
│   │   ├── Generate-Secrets.ps1   # Password and key generation
│   │   └── Generate-Certificates.ps1 # SSL certificate generation
│   └── Bash Scripts (Linux/macOS/WSL)
│       ├── deploy-n8n.sh          # Main deployment script
│       ├── manage-n8n.sh          # Management operations
│       ├── generate-secrets.sh    # Password and key generation
│       └── generate-certificates.sh # SSL certificate generation
├── secrets/                     # Generated secrets (DO NOT COMMIT)
│   ├── postgres_password.txt
│   ├── redis_password.txt
│   ├── n8n_encryption_key.txt
│   ├── n8n_admin_password.txt
│   ├── jwt_secret.txt
│   ├── webhook_password.txt
│   └── SECRETS_INFO.md
└── certs/                       # SSL certificates (DO NOT COMMIT)
    ├── ca.crt
    ├── ca.key
    ├── server.crt
    ├── server.key
    ├── fullchain.pem
    └── CERTIFICATE_INFO.md
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
- **Admin authentication**: n8n protected with secure credentials

### SSL/TLS Configuration
- **Traefik SSL termination**: Automatic certificate management
- **Security headers**: HSTS, CSP, and other security headers
- **TLS 1.2/1.3**: Modern encryption protocols only
- **Self-signed certificates**: For development (CA certificates for production)

### Container Security
- **Non-root users**: All containers run as unprivileged users
- **Read-only filesystems**: Where possible
- **Resource limits**: Memory and CPU constraints
- **Health checks**: Automatic service monitoring

## 🔧 Configuration

### Key Environment Variables

```bash
# Domain and Security
N8N_HOST=n8n.yourdomain.com
N8N_SECURE_COOKIE=true
N8N_BASIC_AUTH_ACTIVE=true

# Queue Mode Configuration
EXECUTIONS_MODE=queue
QUEUE_HEALTH_CHECK_ACTIVE=true

# Performance Tuning
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_TIMEOUT=3600

# SSL/TLS
N8N_PROTOCOL=https
N8N_PORT=443
```

### Scaling Configuration

The deployment supports horizontal scaling of worker instances:

- **Default**: 2 worker instances
- **Tested**: Up to 4+ workers
- **Configuration**: Adjust in docker-compose.yml or use management scripts

## 📊 Monitoring & Observability

### Health Checks
- PostgreSQL: Database connectivity and performance
- Redis: Message broker status and queue health
- n8n: Application health endpoints
- Traefik: Proxy and SSL certificate status

### Logging Strategy
- **Centralized logging**: All services log to Docker
- **Service-specific logs**: Individual service debugging
- **Structured logging**: JSON format for parsing
- **Log rotation**: Automatic cleanup of old logs

### Metrics & Monitoring
- Container resource usage (CPU, memory, network)
- Service availability and response times
- Queue depth and processing rates
- Database connection pool status

## 🚨 Common Issues & Solutions

### Deployment Issues
- **"Required file missing"**: Ensure running from project root directory
- **"Docker not found"**: Install Docker and ensure it's running
- **"Network already exists"**: Remove existing network and recreate

### Runtime Issues
- **Workers restarting**: Normal during first 2-3 minutes of deployment
- **SSL certificate errors**: Trust the CA certificate or use production certificates
- **Redis connection drops**: Temporary during startup, should auto-recover

### Performance Issues
- **High memory usage**: Scale workers instead of increasing per-worker concurrency
- **Slow response**: Check database performance and connection pooling
- **Queue backlog**: Scale up worker instances

## 🔄 Migration & Upgrades

### Version Updates
- Use management scripts to update to latest n8n versions
- Backup before any major version upgrades
- Test upgrades in development environment first

### Migration Between Platforms
- Scripts are interchangeable between Windows and Linux/macOS
- Secrets and certificates are platform-independent
- Docker configuration remains identical

## 🛡️ Production Readiness

### Security Checklist
- [ ] Replace self-signed certificates with CA-issued certificates
- [ ] Change default passwords and enable 2FA
- [ ] Configure firewall rules and network access controls
- [ ] Set up monitoring and alerting
- [ ] Implement backup and disaster recovery procedures
- [ ] Regular security updates and patch management

### Performance Optimization
- [ ] Configure resource limits based on workload
- [ ] Set up database performance monitoring
- [ ] Implement caching strategies
- [ ] Configure log aggregation and analysis
- [ ] Set up automated scaling policies

## 📚 Resources

- [n8n Official Documentation](https://docs.n8n.io/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [PostgreSQL Security Guide](https://www.postgresql.org/docs/current/security.html)

## 🤝 Support

For platform-specific issues, consult the appropriate guide:
- **Windows**: See [README_WINDOWS.md](README_WINDOWS.md)
- **Linux/macOS/WSL**: See [README_LINUX_MACOS.md](README_LINUX_MACOS.md)

For general questions:
1. Check the troubleshooting sections in platform guides
2. Review Docker and n8n logs using management scripts
3. Consult the official n8n documentation
4. Check the n8n community forum

## 📄 License

This deployment configuration is provided as-is under the MIT License. n8n itself is licensed under the [Sustainable Use License](https://github.com/n8n-io/n8n/blob/master/LICENSE.md).

---

**⚠️ Important**: This setup includes self-signed certificates suitable for development and testing. For production use, obtain certificates from a trusted Certificate Authority or use Let's Encrypt.