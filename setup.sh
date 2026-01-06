#!/bin/bash

# n8n Production Setup Script
# This script generates secure passwords and creates all config files

set -e

# Check for openssl dependency
if ! command -v openssl &> /dev/null; then
    echo ""
    echo "❌ Error: openssl is not installed!"
    echo ""
    echo "   openssl is required to generate secure passwords."
    echo "   Please install openssl first, then re-run this script."
    echo ""
    echo "   Install on Ubuntu/Debian:"
    echo "      sudo apt update && sudo apt install openssl"
    echo ""
    echo "   Install on CentOS/RHEL:"
    echo "      sudo yum install openssl"
    echo ""
    echo "   Install on macOS:"
    echo "      brew install openssl"
    echo ""
    exit 1
fi

echo "🚀 Setting up n8n production environment..."
echo ""

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠️  Configuration file .env already exists."
    read -p "Do you want to overwrite it? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Aborted."
        exit 1
    fi
    echo ""
fi

# ============================================================================
# Domain Configuration
# ============================================================================
echo "🌐 Domain Configuration"
echo ""
echo "   Examples:"
echo "   - n8n.example.com"
echo "   - n8n.mycompany.ir"
echo "   - localhost (for local testing)"
echo ""
read -p "   Enter your n8n domain: " N8N_DOMAIN

# If empty, use localhost
if [ -z "$N8N_DOMAIN" ]; then
    N8N_DOMAIN="localhost"
fi

# Determine protocol
if [ "$N8N_DOMAIN" = "localhost" ] || [ "$N8N_DOMAIN" = "127.0.0.1" ]; then
    N8N_PROTOCOL="http"
    echo "   ℹ️  Using HTTP for localhost"
else
    echo ""
    read -p "   Use HTTPS? (Y/n): " use_https
    if [ "$use_https" = "n" ] || [ "$use_https" = "N" ]; then
        N8N_PROTOCOL="http"
    else
        N8N_PROTOCOL="https"
    fi
fi

# Webhook domain configuration
echo ""

# Calculate default webhook domain suggestion
if [[ "$N8N_DOMAIN" == "localhost" ]]; then
    DEFAULT_WEBHOOK_DOMAIN="localhost"
elif [[ "$N8N_DOMAIN" == *.* ]]; then
    SUBDOMAIN="${N8N_DOMAIN%%.*}"
    REST_OF_DOMAIN="${N8N_DOMAIN#*.}"
    DEFAULT_WEBHOOK_DOMAIN="${SUBDOMAIN}-webhook.${REST_OF_DOMAIN}"
else
    DEFAULT_WEBHOOK_DOMAIN="${N8N_DOMAIN}-webhook"
fi

echo "   Webhook domain can be:"
echo "   1) Default domain Address (${DEFAULT_WEBHOOK_DOMAIN})"
echo "   2) Same as n8n domain (${N8N_DOMAIN})"
echo "   3) Different domain (e.g., webhook.${N8N_DOMAIN})"
echo ""

read -p "   Choose option [1-3] (default: 1): " webhook_option

# Default to option 1 if empty
if [ -z "$webhook_option" ]; then
    webhook_option="1"
fi

if [ "$webhook_option" = "1" ]; then
    WEBHOOK_DOMAIN="$DEFAULT_WEBHOOK_DOMAIN"
elif [ "$webhook_option" = "2" ]; then
    WEBHOOK_DOMAIN="$N8N_DOMAIN"
else
    # Option 3 or invalid input (treat as custom)
    read -p "   Enter webhook domain: " WEBHOOK_DOMAIN
    if [ -z "$WEBHOOK_DOMAIN" ]; then
        WEBHOOK_DOMAIN="$N8N_DOMAIN"
    fi
fi

# Build URLs
N8N_EDITOR_BASE_URL="${N8N_PROTOCOL}://${N8N_DOMAIN}"
WEBHOOK_URL="${N8N_PROTOCOL}://${WEBHOOK_DOMAIN}"

echo ""
echo "   ✅ URLs configured:"
echo "      Editor:  ${N8N_EDITOR_BASE_URL}"
echo "      Webhook: ${WEBHOOK_URL}"
echo ""

# ============================================================================
# Password Configuration
# ============================================================================
echo "🔐 Password Configuration"
echo "   1) Generate secure passwords automatically (recommended)"
echo "   2) Enter custom passwords manually"
echo ""
read -p "   Choose option [1/2]: " password_option

if [ "$password_option" = "2" ]; then
    echo ""
    echo "   Enter your passwords:"
    
    # Database password
    while true; do
        read -sp "   Database Password (min 8 chars): " DB_PASSWORD
        echo ""
        if [ ${#DB_PASSWORD} -ge 8 ]; then
            break
        else
            echo "   ❌ Password too short. Please enter at least 8 characters."
        fi
    done
    
    # Redis password
    while true; do
        read -sp "   Redis Password (min 8 chars): " REDIS_PASSWORD
        echo ""
        if [ ${#REDIS_PASSWORD} -ge 8 ]; then
            break
        else
            echo "   ❌ Password too short. Please enter at least 8 characters."
        fi
    done
    
    # Encryption key
    echo ""
    read -p "   Generate encryption key automatically? (Y/n): " gen_enc
    if [ "$gen_enc" = "n" ] || [ "$gen_enc" = "N" ]; then
        while true; do
            read -sp "   Encryption Key (min 32 chars): " ENCRYPTION_KEY
            echo ""
            if [ ${#ENCRYPTION_KEY} -ge 32 ]; then
                break
            else
                echo "   ❌ Key too short. Please enter at least 32 characters."
            fi
        done
    else
        ENCRYPTION_KEY=$(openssl rand -hex 32)
        echo "   ✅ Encryption key generated automatically"
    fi
else
    echo ""
    echo "   🔐 Generating secure passwords..."
    DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
    REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)
    ENCRYPTION_KEY=$(openssl rand -hex 32)
fi

echo ""
echo "📁 Creating configuration files..."

# Check if pgbouncer.ini or userlist.txt are directories (common mistake)
if [ -d "pgbouncer.ini" ]; then
    echo ""
    echo "❌ Error: 'pgbouncer.ini' exists as a directory!"
    echo "   Please remove it first: rm -rf pgbouncer.ini"
    echo ""
    exit 1
fi

if [ -d "userlist.txt" ]; then
    echo ""
    echo "❌ Error: 'userlist.txt' exists as a directory!"
    echo "   Please remove it first: rm -rf userlist.txt"
    echo ""
    exit 1
fi

# Create .env
cat > .env << EOF
# ==============================================================================
#                         n8n Production Environment
# ==============================================================================
# Generated by setup.sh on $(date)

# ==============================================================================
#                              CREDENTIALS
# ==============================================================================

# Database
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=n8n

# Redis
REDIS_PASSWORD=${REDIS_PASSWORD}

# n8n Encryption (MUST be unique and kept secret)
N8N_ENCRYPTION_KEY=${ENCRYPTION_KEY}

# ==============================================================================
#                              DATABASE
# ==============================================================================
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
DATABASE_URL=postgres://n8n_user:${DB_PASSWORD}@postgres:5432/n8n

# n8n Database Connection (via PgBouncer)
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=pgbouncer
DB_POSTGRESDB_PORT=6432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=n8n_user
DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}

# ==============================================================================
#                              PGBOUNCER
# ==============================================================================
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

# ==============================================================================
#                              REDIS / QUEUE
# ==============================================================================
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
QUEUE_HEALTH_CHECK_ACTIVE=true

# ==============================================================================
#                              N8N SETTINGS
# ==============================================================================
NODE_ENV=production

# URLs
N8N_HOST=${N8N_DOMAIN}
N8N_PORT=5678
N8N_PROTOCOL=${N8N_PROTOCOL}
N8N_EDITOR_BASE_URL=${N8N_EDITOR_BASE_URL}
WEBHOOK_URL=${WEBHOOK_URL}

# Security (n8n 2.0 defaults)
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_BLOCK_ENV_ACCESS_IN_NODE=true
N8N_DISABLE_PRODUCTION_MAIN_PROCESS=true
N8N_SECURE_COOKIE=true
N8N_SKIP_AUTH_ON_OAUTH_CALLBACK=false

# Proxy / Security
N8N_PROXY_HOPS=1

# Scaling
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true

# Task Runners (for Code nodes - n8n 2.0)
N8N_RUNNERS_ENABLED=true
N8N_RUNNERS_MODE=internal

# Execution Settings
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168

# Timezone
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

# Set correct permissions for PgBouncer files (required for Docker container)
chmod 644 pgbouncer.ini userlist.txt

echo ""
echo "✅ Setup complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Configuration Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   🌐 URLs:"
echo "      n8n Editor:  ${N8N_EDITOR_BASE_URL}"
echo "      Webhooks:    ${WEBHOOK_URL}"
echo ""
echo "   🔐 Credentials (save these securely!):"
echo "      Database Password: ${DB_PASSWORD}"
echo "      Redis Password:    ${REDIS_PASSWORD}"
echo "      Encryption Key:    ${ENCRYPTION_KEY}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🚀 To start the services, run:"
echo "   docker compose up -d"
echo ""
if [ "$N8N_PROTOCOL" = "https" ]; then
echo "⚠️  Remember to set up a reverse proxy (Nginx/Traefik) with SSL!"
fi
