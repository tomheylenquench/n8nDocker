# Securing n8n deployments with SSL/TLS and Docker

Securing n8n deployments requires a multi-layered approach covering SSL/TLS configuration, database encryption, inter-service communication, and comprehensive security hardening. The recommended approach is using a reverse proxy for SSL termination combined with Docker network isolation and proper secrets management. Critical findings include **limited Redis SSL support in queue mode** and the necessity of shared encryption keys across all n8n instances.

## SSL/TLS setup for main instance and workers

n8n supports two primary SSL/TLS configuration methods. The **reverse proxy approach** using Traefik or Nginx is strongly recommended for production deployments due to automatic certificate management and renewal capabilities. Direct SSL configuration is possible but requires manual certificate management.

For the main n8n instance, configure these environment variables:
```yaml
environment:
  - N8N_PROTOCOL=https
  - N8N_HOST=n8n.yourdomain.com
  - WEBHOOK_URL=https://n8n.yourdomain.com/
```

**Workers in queue mode do not require SSL configuration** as they communicate internally with Redis and PostgreSQL rather than external clients. Workers inherit the same encryption key as the main instance but handle no direct HTTPS traffic.

### Complete Docker Compose with Traefik SSL
```yaml
version: '3.8'

networks:
  web:
    external: true
  n8n-internal:

services:
  traefik:
    image: traefik:v3.0
    restart: unless-stopped
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${SSL_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt

  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    environment:
      - N8N_PROTOCOL=https
      - N8N_HOST=${N8N_HOST}
      - WEBHOOK_URL=https://${N8N_HOST}/
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=web"
      - "traefik.http.routers.n8n.rule=Host(`${N8N_HOST}`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
    networks:
      - web
      - n8n-internal
```

## Database and Redis SSL configuration challenges

PostgreSQL SSL support in n8n is comprehensive and production-ready, while **Redis SSL/TLS support for queue mode has significant limitations**. Multiple users report connection failures when attempting to use SSL-enabled Redis services like AWS ElastiCache or DigitalOcean Managed Redis.

### PostgreSQL SSL Configuration
```yaml
environment:
  - DB_POSTGRESDB_SSL_CA=/path/to/ca-certificate.pem
  - DB_POSTGRESDB_SSL_CERT=/path/to/client-certificate.pem
  - DB_POSTGRESDB_SSL_KEY=/path/to/client-key.pem
  - DB_POSTGRESDB_SSL_REJECT_UNAUTHORIZED=true
```

PostgreSQL supports multiple SSL modes including "require" for encrypted connections and certificate verification. Mount certificates as Docker volumes:
```yaml
volumes:
  - ./certs:/home/node/certs:ro
```

### Redis Security Workaround
Since n8n lacks proper Redis SSL support in queue mode, implement network-level security:
```yaml
services:
  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}
    networks:
      - n8n-internal  # Isolated network
```

No SSL-specific environment variables exist for queue mode Redis connections, forcing many users to disable SSL on managed Redis instances.

## Inter-service communication and Docker network security

n8n's queue mode architecture involves the main instance, workers, Redis, and PostgreSQL communicating through Docker networks. **Network isolation is critical** for security since Redis SSL isn't properly supported.

### Multi-tier Network Architecture
```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
  database:
    driver: bridge
    internal: true  # No external connectivity
```

This configuration separates external-facing services from internal databases. The main n8n instance connects to both frontend and backend networks, while PostgreSQL remains isolated in the database network.

### Secure Queue Mode Configuration
```yaml
x-shared: &shared
  image: n8nio/n8n:latest
  user: "1000:1000"  # Non-root user
  environment:
    - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    - EXECUTIONS_MODE=queue
    - QUEUE_BULL_REDIS_HOST=redis
    - QUEUE_HEALTH_CHECK_ACTIVE=true
  networks:
    - n8n-internal
  security_opt:
    - no-new-privileges:true

services:
  n8n-main:
    <<: *shared
    ports:
      - "127.0.0.1:5678:5678"  # Bind to localhost only
    
  n8n-worker:
    <<: *shared
    command: ["n8n", "worker"]
    deploy:
      replicas: 2
```

## Certificate management and automated renewal strategies

Automated certificate management through reverse proxies eliminates manual renewal requirements. **Traefik and Caddy provide built-in Let's Encrypt integration**, while Nginx requires Certbot configuration.

### Traefik Automatic Certificate Management
```yaml
command:
  - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
  - "--certificatesresolvers.letsencrypt.acme.email=admin@yourdomain.com"
  - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
```

For DNS-based validation (recommended for wildcard certificates):
```yaml
- "--certificatesresolvers.letsencrypt.acme.dnschallenge=true"
- "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=cloudflare"
```

### Custom Certificate Authority Support
n8n version 1.42.0+ supports custom CA certificates through volume mounting:
```yaml
volumes:
  - ./pki:/opt/custom-certificates:ro
```

Ensure proper permissions:
```bash
chmod 644 pki/*.pem
chown -R 1000:1000 pki/
```

## Authentication, secrets management, and hardening

n8n provides multiple authentication methods from basic auth to enterprise SSO. **User management with role-based access control** offers granular permissions for teams.

### Authentication Configuration
```yaml
environment:
  - N8N_BASIC_AUTH_ACTIVE=true
  - N8N_BASIC_AUTH_USER=${N8N_USER}
  - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
  - N8N_SECURE_COOKIE=true
```

For production deployments, enable user management and configure MFA:
```yaml
- N8N_USER_MANAGEMENT_DISABLED=false
```

### Docker Secrets Implementation
```yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt
  encryption_key:
    file: ./secrets/encryption_key.txt

services:
  n8n:
    environment:
      - DB_POSTGRESDB_PASSWORD_FILE=/run/secrets/db_password
      - N8N_ENCRYPTION_KEY_FILE=/run/secrets/encryption_key
    secrets:
      - db_password
      - encryption_key
```

### Security Headers via Reverse Proxy
n8n relies on reverse proxies for security headers. Configure Nginx with:
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'";
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
```

## Production-ready Docker Compose configuration

This comprehensive configuration implements all security best practices for n8n queue mode deployment:

```yaml
version: '3.8'

volumes:
  db_storage:
  n8n_storage:
  redis_storage:
  letsencrypt:

networks:
  web:
    external: true
  backend:
    driver: bridge
  database:
    driver: bridge
    internal: true

secrets:
  db_password:
    file: ./secrets/db_password.txt
  encryption_key:
    file: ./secrets/encryption_key.txt

x-shared: &shared
  restart: always
  image: n8nio/n8n:latest
  user: "1000:1000"
  security_opt:
    - no-new-privileges:true
  environment:
    - DB_TYPE=postgresdb
    - DB_POSTGRESDB_HOST=postgres
    - DB_POSTGRESDB_PORT=5432
    - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
    - DB_POSTGRESDB_USER=${POSTGRES_USER}
    - DB_POSTGRESDB_PASSWORD_FILE=/run/secrets/db_password
    - DB_POSTGRESDB_SSL_CA=/home/node/certs/ca.pem
    - N8N_ENCRYPTION_KEY_FILE=/run/secrets/encryption_key
    - EXECUTIONS_MODE=queue
    - QUEUE_BULL_REDIS_HOST=redis
    - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
    - QUEUE_HEALTH_CHECK_ACTIVE=true
    - N8N_PROTOCOL=https
    - N8N_HOST=${N8N_HOST}
    - WEBHOOK_URL=https://${N8N_HOST}/
  volumes:
    - n8n_storage:/home/node/.n8n
    - ./certs:/home/node/certs:ro
  networks:
    - backend
  secrets:
    - db_password
    - encryption_key
  depends_on:
    postgres:
      condition: service_healthy
    redis:
      condition: service_healthy

services:
  traefik:
    image: traefik:v3.0
    restart: unless-stopped
    command:
      - "--api=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt:/letsencrypt
    networks:
      - web

  postgres:
    image: postgres:16
    restart: unless-stopped
    user: "999:999"
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
    volumes:
      - db_storage:/var/lib/postgresql/data
      - ./postgres-ssl:/var/lib/postgresql/ssl:ro
    command: >
      postgres
      -c ssl=on
      -c ssl_cert_file=/var/lib/postgresql/ssl/server.crt
      -c ssl_key_file=/var/lib/postgresql/ssl/server.key
    networks:
      - database
    secrets:
      - db_password
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    networks:
      - backend
    volumes:
      - redis_storage:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5

  n8n:
    <<: *shared
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=web"
      - "traefik.http.routers.n8n.rule=Host(`${N8N_HOST}`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
    networks:
      - web
      - backend
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}

  n8n-worker:
    <<: *shared
    command: ["n8n", "worker"]
    deploy:
      replicas: 2
```

### Environment file (.env)
```bash
# Domain Configuration
N8N_HOST=n8n.yourdomain.com
ACME_EMAIL=admin@yourdomain.com
SSL_EMAIL=admin@yourdomain.com

# Authentication
N8N_USER=admin
N8N_PASSWORD=secure_admin_password

# Database Configuration  
POSTGRES_DB=n8n
POSTGRES_USER=n8n
REDIS_PASSWORD=secure_redis_password

# n8n Configuration
# Generate with: openssl rand -hex 16
N8N_ENCRYPTION_KEY=your-32-character-encryption-key
```

## Critical security considerations and limitations

**Redis SSL limitation remains the most significant security gap** in n8n's queue mode architecture. Organizations requiring end-to-end encryption must rely on network-level security through Docker network isolation, VPCs, and firewall rules until native SSL support improves.

Additional security measures include:
- Running containers as non-root users (UID 1000)
- Implementing resource limits to prevent DoS
- Regular security updates for all container images
- Monitoring `/healthz` endpoints for service health
- Configuring webhook authentication for external integrations
- Using external secrets providers (HashiCorp Vault, AWS Secrets Manager) for production deployments

This configuration provides defense-in-depth security suitable for production n8n deployments while acknowledging current architectural limitations.