#!/bin/bash

# n8n Production Setup Script
# This script copies example files and generates secure passwords

set -e

echo "🚀 Setting up n8n production environment..."

# Check if .env files already exist
if [ -f ".env" ] || [ -f ".env-main" ]; then
    echo "⚠️  Configuration files already exist."
    read -p "Do you want to overwrite them? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        exit 1
    fi
fi

# Generate secure passwords
echo "🔐 Generating secure passwords..."
DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
ENCRYPTION_KEY=$(openssl rand -hex 32)

echo "📁 Creating configuration files..."

# Create .env for docker-compose
cat > .env << EOF
# Docker Compose environment variables
# This file is read by docker-compose for variable substitution

# Redis password (used in compose.yaml)
REDIS_PASSWORD=${REDIS_PASSWORD}

# PostgreSQL user (used in healthcheck)
POSTGRES_USER=n8n_user
EOF

# Create .env-db
cat > .env-db << EOF
# -- PostgreSQL Database Configuration --
POSTGRES_HOST=postgres
POSTGRES_PORT=5432

POSTGRES_DB=n8n
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=${DB_PASSWORD}

# -- PgBouncer Configuration --

DATABASE_URL=postgres://n8n_user:${DB_PASSWORD}@postgres:5432/n8n

# Pooler settings
PGBOUNCER_LISTEN_PORT=6432
PGBOUNCER_LISTEN_ADDR=0.0.0.0
PGBOUNCER_AUTH_TYPE=md5
PGBOUNCER_AUTH_FILE=/etc/pgbouncer/userlist.txt
PGBOUNCER_MAX_CLIENT_CONN=1000
PGBOUNCER_POOL_MODE=transaction
PGBOUNCER_DEFAULT_POOL_SIZE=50
PGBOUNCER_MIN_POOL_SIZE=5
PGBOUNCER_RESERVE_POOL_SIZE=20
PGBOUNCER_RESERVE_POOL_TIMEOUT=5
EOF

# Create .env-redis
cat > .env-redis << EOF
# Redis Password
REDIS_PASSWORD=${REDIS_PASSWORD}
EOF

# Create .env-main
cat > .env-main << EOF
# ===== Node.js Environment =====
NODE_ENV=production

# ===== Database (via PgBouncer) =====
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=pgbouncer
DB_POSTGRESDB_PORT=6432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}

# ===== Queue Mode (Redis) =====
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
QUEUE_HEALTH_CHECK_ACTIVE=true

# ===== n8n URLs & Proxy =====
N8N_HOST=n8n.yourdomain.com
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://n8n.yourdomain.com
WEBHOOK_URL=https://n8n-webhook.yourdomain.com

# ===== Security =====
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_BLOCK_ENV_ACCESS_IN_NODE=true
N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true
N8N_SECURE_COOKIE=true

# ===== Task Runners (for Code nodes) =====
N8N_RUNNERS_ENABLED=true
N8N_RUNNERS_MODE=internal

# ===== Execution Settings =====
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168

# ===== Timezone =====
GENERIC_TIMEZONE=Asia/Tehran
TZ=Asia/Tehran
EOF

# Create .env-worker
cat > .env-worker << EOF
# ===== Node.js Environment =====
NODE_ENV=production

# ===== Database (via PgBouncer) =====
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=pgbouncer
DB_POSTGRESDB_PORT=6432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}

# ===== Queue Mode (Redis) =====
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}

# ===== Security =====
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}
N8N_BLOCK_ENV_ACCESS_IN_NODE=true

# ===== Task Runners (for Code nodes) =====
N8N_RUNNERS_ENABLED=true
N8N_RUNNERS_MODE=internal

# ===== Timezone =====
GENERIC_TIMEZONE=Asia/Tehran
TZ=Asia/Tehran
EOF

# Create pgbouncer.ini
cat > pgbouncer.ini << EOF
[databases]
# N8N database through PgBouncer
n8n = host=postgres port=5432 dbname=n8n user=n8n_user password=${DB_PASSWORD}

[pgbouncer]
# Listening configuration
listen_addr = 0.0.0.0
listen_port = 6432
unix_socket_dir = /tmp

# Authentication
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt

# Pool settings
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 50
min_pool_size = 5
reserve_pool_size = 20
reserve_pool_timeout = 5
EOF

# Create userlist.txt
cat > userlist.txt << EOF
"n8n_user" "${DB_PASSWORD}"
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Generated credentials (save these securely!):"
echo "   Database Password: ${DB_PASSWORD}"
echo "   Redis Password:    ${REDIS_PASSWORD}"
echo "   Encryption Key:    ${ENCRYPTION_KEY}"
echo ""
echo "⚠️  IMPORTANT: Update the domain settings in .env-main:"
echo "   - N8N_HOST"
echo "   - N8N_EDITOR_BASE_URL"
echo "   - WEBHOOK_URL"
echo ""
echo "🚀 To start the services, run:"
echo "   docker compose up -d"
