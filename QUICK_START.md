# 🚀 Quick Start Guide

Get your secure n8n deployment running in 5 minutes!

## Prerequisites Check

✅ Docker Desktop installed and running  
✅ PowerShell 5.1+ available  
✅ 4GB+ RAM available  
✅ Domain name ready (or use localhost for testing)  

## Step 1: One-Command Deployment

Open PowerShell as Administrator and run:

```powershell
# Navigate to the project directory
cd D:\source\repos\n8nDocker

# Complete setup and deployment
.\scripts\Deploy-N8N.ps1 -All -Domain "n8n.yourdomain.com"
```

**Replace `n8n.yourdomain.com` with your actual domain!**

## Step 2: Wait for Services

The script will:
- ✅ Generate secure passwords and encryption keys
- ✅ Create SSL certificates
- ✅ Set up Docker networks
- ✅ Deploy all services

Wait for the "🎉 Deployment successful!" message.

## Step 3: Access n8n

1. **URL**: `https://n8n.yourdomain.com`
2. **Username**: `admin`
3. **Password**: Check the output or `secrets\SECRETS_SUMMARY.md`

## Step 4: Trust the Certificate (Development)

For self-signed certificates:
1. Download `certs\ca.crt`
2. Double-click and install to "Trusted Root Certification Authorities"
3. Refresh your browser

## 🎯 What You Get

- **Secure n8n** with SSL/TLS encryption
- **Queue mode** with 2 worker instances
- **PostgreSQL** database with SSL
- **Redis** message broker
- **Traefik** reverse proxy
- **Automated backups** capability

## 🔧 Quick Commands

```powershell
# Check status
.\scripts\Manage-N8N.ps1 -Action status

# View logs
.\scripts\Manage-N8N.ps1 -Action logs -Follow

# Scale workers
.\scripts\Manage-N8N.ps1 -Action scale -Workers 4

# Create backup
.\scripts\Manage-N8N.ps1 -Action backup

# Stop everything
docker compose down

# Start everything
docker compose up -d
```

## 🚨 Troubleshooting

### "Docker not found"
- Install Docker Desktop
- Restart PowerShell after installation

### "Network already exists"
- Run: `docker network rm web`
- Re-run the deployment script

### "Permission denied"
- Run PowerShell as Administrator
- Check Docker Desktop is running

### "Certificate errors"
- Install the CA certificate from `certs\ca.crt`
- Or use `http://localhost:5678` for testing

## 🔒 Security Notes

- **Change passwords** after first login
- **Use real certificates** for production
- **Keep secrets secure** - never commit to git
- **Regular updates** with `.\scripts\Manage-N8N.ps1 -Action update`

## 📚 Next Steps

1. **Read the full README.md** for detailed configuration
2. **Set up your first workflow** in n8n
3. **Configure webhooks** for external integrations
4. **Set up monitoring** and alerting
5. **Plan your backup strategy**

---

**Need help?** Check the full README.md or the troubleshooting section!