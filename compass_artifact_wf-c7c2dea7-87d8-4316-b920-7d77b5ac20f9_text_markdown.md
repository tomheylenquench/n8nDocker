# Comprehensive Guide to Scalable n8n Docker Deployment

## Queue mode enables horizontal scaling with free licensing

Based on extensive research of the official n8n documentation, n8n's queue mode provides enterprise-grade scalability without licensing costs. This architecture separates workflow execution from the main instance, enabling horizontal scaling through multiple worker processes. The queue mode and multi-worker setup remain completely free under n8n's Sustainable Use License, making it an attractive solution for production deployments.

## System Architecture Overview

The scalable n8n deployment consists of five key components working together:

**Main n8n instance** handles the user interface, API endpoints, webhook reception, and trigger management. It coordinates workflow execution but doesn't execute workflows itself in queue mode. **Worker instances** execute the actual workflows, picking up jobs from the queue as they become available. **PostgreSQL database** stores workflows, credentials, execution history, and configuration data shared across all instances. **Redis** acts as the message broker, maintaining the job queue and enabling communication between main and worker instances. **Optional webhook processors** can handle high-volume webhook traffic with external load balancing.

## Complete Docker Compose Configuration

Here's a production-ready docker-compose.yml that implements all components for a scalable n8n deployment:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    restart: unless-stopped
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${DB_POSTGRESDB_PASSWORD}
      - POSTGRES_DB=n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U n8n -d n8n']
      interval: 5s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - redis_data:/data
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 5s
      timeout: 3s
      retries: 5

  n8n-main:
    image: n8nio/n8n
    restart: unless-stopped
    environment:
      # Core configuration
      - N8N_HOST=${SUBDOMAIN}.${DOMAIN_NAME}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${SUBDOMAIN}.${DOMAIN_NAME}/
      
      # Queue mode configuration
      - EXECUTIONS_MODE=queue
      - QUEUE_HEALTH_CHECK_ACTIVE=true
      
      # Database configuration
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
      
      # Redis configuration
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_DB=0
      
      # Security
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      
      # Performance
      - EXECUTIONS_DATA_PRUNE=true
      - EXECUTIONS_DATA_PRUNE_MAX_COUNT=10000
    ports:
      - "5678:5678"
    volumes:
      - n8n_data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  n8n-worker-1:
    image: n8nio/n8n
    restart: unless-stopped
    command: worker --concurrency=10
    environment:
      # Same environment as main, minus UI-specific variables
      - NODE_ENV=production
      - EXECUTIONS_MODE=queue
      - QUEUE_HEALTH_CHECK_ACTIVE=true
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_DB=0
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  n8n-worker-2:
    image: n8nio/n8n
    restart: unless-stopped
    command: worker --concurrency=10
    environment:
      # Identical to worker-1
      - NODE_ENV=production
      - EXECUTIONS_MODE=queue
      - QUEUE_HEALTH_CHECK_ACTIVE=true
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD}
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_DB=0
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

volumes:
  postgres_data:
  redis_data:
  n8n_data:
```

## Essential Environment Variables

Create a `.env` file with these critical configuration values:

```bash
# Domain configuration
DOMAIN_NAME=yourdomain.com
SUBDOMAIN=n8n

# Database credentials
DB_POSTGRESDB_PASSWORD=your_secure_password_here

# Security - Generate a 32+ character encryption key
N8N_ENCRYPTION_KEY=your_32_character_encryption_key_here

# Optional Redis authentication
QUEUE_BULL_REDIS_PASSWORD=redis_password_if_needed

# Performance tuning
EXECUTIONS_TIMEOUT=3600  # 1 hour timeout
N8N_GRACEFUL_SHUTDOWN_TIMEOUT=30
```

## PostgreSQL Database Setup

PostgreSQL is **mandatory** for queue mode - SQLite is not supported for distributed deployments. The database stores workflows, credentials, execution history, and coordinates between all instances.

**Connection configuration** uses standard PostgreSQL environment variables. All instances must connect to the same database. The database user requires full permissions on all tables as n8n handles schema migrations automatically.

**Migration from SQLite** requires exporting workflows and credentials using n8n's CLI tools, then importing them into the PostgreSQL instance. Always backup your data before migration and ensure the encryption key remains consistent.

**Performance optimization** for PostgreSQL includes setting appropriate connection pool sizes, enabling SSL for security, and using SSD storage. For high-volume deployments, consider a dedicated PostgreSQL server with connection pooling via PgBouncer.

## Redis Configuration for Queue Management

Redis serves as the message broker, maintaining the job queue and enabling communication between components. It requires minimal configuration but is critical for queue mode operation.

**Basic Redis setup** uses the standard Redis Docker image with data persistence enabled. Health checks ensure Redis is ready before n8n instances start. For production, consider Redis persistence settings and memory policies based on your workload.

**Connection settings** include host, port, database number, and optional authentication. All instances must connect to the same Redis instance. For high availability, Redis Sentinel or Redis Cluster configurations are supported through additional environment variables.

## Worker Configuration and Scaling

Workers execute workflows pulled from the Redis queue. Each worker is a complete n8n instance running in worker mode, capable of handling multiple concurrent executions.

**Concurrency settings** control how many workflows each worker processes simultaneously. The default is 10, but production deployments should use at least 5 to prevent database connection pool exhaustion. Higher concurrency allows fewer workers to handle more load.

**Scaling strategy** involves starting with 2-3 workers and monitoring queue depth and execution times. Add workers incrementally based on workload. Each worker consumes approximately 100MB RAM at idle, with requirements increasing based on workflow complexity.

**Health monitoring** is enabled through the `/healthz` endpoint on each worker. This allows container orchestrators to detect unhealthy workers and restart them automatically. The `/healthz/readiness` endpoint additionally checks database and Redis connectivity.

## Production Best Practices

**Infrastructure architecture** should separate database and Redis to dedicated servers for heavy workloads. Use container orchestration platforms like Kubernetes for dynamic scaling. Implement proper backup strategies for both the database and the `/home/node/.n8n` directory containing encryption keys.

**Security configuration** requires consistent encryption keys across all instances. Enable SSL/TLS for all connections, including database and Redis. Use environment variable files with restricted permissions for sensitive data. Consider implementing network isolation between components.

**Monitoring and logging** should track worker performance, queue depth, and execution times. Configure appropriate log levels and implement log aggregation. Use the built-in metrics endpoint for Prometheus integration. Set up alerts for queue buildup or worker failures.

## Performance Optimization Settings

**Memory allocation** is more critical than CPU for n8n performance. Workers handle I/O-intensive operations efficiently, making memory the primary constraint. Allocate at least 1.5GB per worker for complex workflows involving data transformation.

**Execution timeouts** prevent runaway workflows from consuming resources indefinitely. Set global timeouts via `EXECUTIONS_TIMEOUT` or configure per-workflow limits. Workers implement hard kills at 20% of the timeout duration to ensure cleanup.

**Data retention** policies help manage database growth. Enable automatic pruning with `EXECUTIONS_DATA_PRUNE=true` and set appropriate retention limits. The default keeps 10,000 executions, but adjust based on your audit requirements.

## Additional Production Components

**Load balancing** becomes necessary when using webhook processors. Deploy multiple n8n instances configured for webhook processing behind a load balancer. Exclude the main instance from the load balancer pool to prevent UI access issues.

**Binary data handling** in queue mode requires special consideration. The filesystem mode is not supported, so use the default in-memory mode or configure S3-compatible external storage for large binary data.

**Backup solutions** should cover the PostgreSQL database, Redis data, and the n8n data directory. Implement automated backups with regular testing of restore procedures. Consider point-in-time recovery for the database.

## Licensing and Cost Implications

**Queue mode is completely free** under n8n's Sustainable Use License. There are no restrictions on the number of workers or scaling capabilities. Companies can use n8n internally without licensing costs, including all queue mode features.

**Enterprise features** like multi-main setup for high availability require paid licenses. However, the core scaling capabilities through queue mode and multiple workers remain free. The community edition provides production-ready scalability without licensing fees.

**Permitted uses** include internal business automation, commercial consulting services using n8n, and deployment within your organization. Restrictions apply only to hosting n8n as a service for others or white-labeling the product.

## Deployment Instructions

1. **Prepare environment**: Create a deployment directory and add the docker-compose.yml and .env files with your configuration.

2. **Generate encryption key**: Create a secure 32+ character string for N8N_ENCRYPTION_KEY. This must remain constant across all deployments.

3. **Start services**: Run `docker-compose up -d` to start all services. Monitor logs with `docker-compose logs -f` during initial startup.

4. **Verify health**: Check that all services are healthy using `docker-compose ps`. Access the n8n UI at your configured URL.

5. **Scale workers**: Add more worker instances by duplicating the worker service definitions in docker-compose.yml with unique names.

6. **Monitor performance**: Use the Settings > Workers view in n8n to monitor worker performance and adjust scaling as needed.

This configuration provides a robust, scalable n8n deployment capable of handling enterprise workloads while remaining free under the community license. The architecture supports horizontal scaling through additional workers and provides the foundation for high-availability deployments with optional enterprise features.