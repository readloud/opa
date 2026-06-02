# OPA Production Deployment Guide

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Infrastructure Setup](#infrastructure-setup)
4. [Backend Deployment](#backend-deployment)
5. [Database Setup](#database-setup)
6. [Storage Configuration](#storage-configuration)
7. [Mobile App Deployment](#mobile-app-deployment)
8. [Monitoring & Logging](#monitoring--logging)
9. [Backup & Recovery](#backup--recovery)
10. [Security Hardening](#security-hardening)
11. [Scaling Guide](#scaling-guide)
12. [Disaster Recovery](#disaster-recovery)

---

## Architecture Overview

### Production Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Cloudflare CDN                          │
│                     (DDoS Protection, SSL)                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Load Balancer (HAProxy)                    │
│                    (SSL Termination, Rate Limit)                │
└─────────┬───────────────────┬───────────────────┬───────────────┘
          │                   │                   │
          ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  API Server 1   │ │  API Server 2   │ │  API Server 3   │
│   (NestJS)      │ │   (NestJS)      │ │   (NestJS)      │
│   8GB/4vCPU     │ │   8GB/4vCPU     │ │   8GB/4vCPU     │
└─────────┬───────┘ └─────────┬───────┘ └─────────┬───────┘
          │                   │                   │
          └───────────────────┼───────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Redis Cluster                           │
│                    (Session, Cache, Queue)                      │
│                       16GB/2 nodes                              │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PostgreSQL Cluster                         │
│                   (Primary + Replica)                           │
│                      32GB/4vCPU each                            │
│                  + PostGIS extension                            │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        MinIO/S3 Storage                         │
│                   (Images, Drone Data, Backups)                 │
│                        100TB+ capacity                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Hardware Requirements

| Component | Development | Staging | Production |
|-----------|-------------|---------|------------|
| **API Server** | 2GB/1vCPU | 4GB/2vCPU | 8GB/4vCPU (min 3 nodes) |
| **Database** | 4GB/2vCPU | 8GB/4vCPU | 32GB/8vCPU + replica |
| **Redis** | 1GB | 4GB | 16GB clustered |
| **Storage** | 100GB | 500GB | 10TB+ S3 |

### Software Requirements

- **OS**: Ubuntu 22.04 LTS or Debian 12
- **Node.js**: 18.x or 20.x LTS
- **PostgreSQL**: 15+ with PostGIS 3.4+
- **Redis**: 7.0+
- **Nginx**: 1.24+ (reverse proxy)
- **Docker**: 24.0+ (optional)
- **Kubernetes**: 1.28+ (for large deployments)

### Network Requirements

- **Ports to open**:
  - 80/443 (HTTP/HTTPS)
  - 22 (SSH - restricted IPs)
  - 5432 (PostgreSQL - internal only)
  - 6379 (Redis - internal only)
  - 3000 (API - internal)

- **Bandwidth**: Minimum 100 Mbps
- **Static IP**: Required for production
- **SSL Certificate**: Let's Encrypt or commercial

---

## Infrastructure Setup

### Option 1: AWS Deployment (Recommended)

#### 1.1 VPC Setup

```bash
# Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=opa-prod}]'

# Create subnets (public & private)
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.1.0/24 --availability-zone ap-southeast-1a
aws ec2 create-subnet --vpc-id vpc-xxx --cidr-block 10.0.2.0/24 --availability-zone ap-southeast-1b

# Create internet gateway
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --internet-gateway-id igw-xxx --vpc-id vpc-xxx

# Configure route tables
aws ec2 create-route-table --vpc-id vpc-xxx
aws ec2 create-route --route-table-id rtb-xxx --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxx
```

#### 1.2 EC2 Instances (API Servers)

```bash
# Launch template
cat > user-data.sh << 'EOF'
#!/bin/bash
apt-get update
apt-get install -y nodejs npm nginx postgresql-client redis-tools

# Install PM2
npm install -g pm2

# Clone application
git clone https://github.com/your-org/opa-backend.git /opt/opa
cd /opt/opa
npm install --production

# Setup systemd service
cat > /etc/systemd/system/opa.service << 'SERVICE'
[Unit]
Description=OPA Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/opa
ExecStart=/usr/bin/node dist/main.js
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SERVICE

systemctl enable opa
systemctl start opa
EOF

# Launch instances
aws ec2 run-instances \
  --image-id ami-0c7217cde2ff95282 \
  --instance-type t3.large \
  --key-name opa-key \
  --security-group-ids sg-xxx \
  --subnet-id subnet-xxx \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=opa-api-1}]'
```

#### 1.3 RDS PostgreSQL (Managed Database)

```bash
# Create subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name opa-subnet-group \
  --subnet-ids subnet-xxx subnet-yyy \
  --db-subnet-group-description "OPA subnets"

# Create RDS instance
aws rds create-db-instance \
  --db-instance-identifier opa-db-prod \
  --db-instance-class db.r6g.large \
  --engine postgres \
  --engine-version 15.3 \
  --master-username opa_admin \
  --master-user-password SecurePassword123! \
  --allocated-storage 100 \
  --storage-type gp3 \
  --vpc-security-group-ids sg-xxx \
  --db-subnet-group-name opa-subnet-group \
  --backup-retention-period 30 \
  --backup-window "03:00-04:00" \
  --preferred-maintenance-window "sun:04:00-sun:05:00" \
  --multi-az \
  --storage-encrypted \
  --enable-performance-insights
```

#### 1.4 ElastiCache Redis

```bash
# Create Redis cluster
aws elasticache create-cache-cluster \
  --cache-cluster-id opa-redis-prod \
  --engine redis \
  --cache-node-type cache.r6g.large \
  --num-cache-nodes 2 \
  --security-group-ids sg-xxx \
  --cache-subnet-group-name opa-subnet-group \
  --port 6379 \
  --auto-minor-version-upgrade \
  --preferred-maintenance-window "sun:04:00-sun:05:00"
```

#### 1.5 S3 Storage

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket opa-storage-prod \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket opa-storage-prod \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket opa-storage-prod \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

# Configure lifecycle
cat > lifecycle.json << 'LIFECYCLE'
{
  "Rules": [
    {
      "Id": "MoveToGlacier",
      "Status": "Enabled",
      "Prefix": "drone/",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
LIFECYCLE

aws s3api put-bucket-lifecycle-configuration \
  --bucket opa-storage-prod \
  --lifecycle-configuration file://lifecycle.json
```

### Option 2: Docker Compose (Small Scale)

#### `docker-compose.prod.yml`

```yaml
version: '3.8'

services:
  postgres:
    image: postgis/postgis:15-3.4
    container_name: opa-postgres
    environment:
      POSTGRES_DB: opa_db
      POSTGRES_USER: opa_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    networks:
      - opa-network
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U opa_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: opa-redis
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    networks:
      - opa-network
    restart: always

  minio:
    image: minio/minio:latest
    container_name: opa-minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    networks:
      - opa-network
    restart: always

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.prod
    container_name: opa-backend
    environment:
      NODE_ENV: production
      DATABASE_URL: postgresql://opa_user:${DB_PASSWORD}@postgres:5432/opa_db
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379
      S3_ENDPOINT: http://minio:9000
      S3_BUCKET: opa-storage
    depends_on:
      - postgres
      - redis
      - minio
    networks:
      - opa-network
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: opa-nginx
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
      - ./certbot/www:/var/www/certbot
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - backend
    networks:
      - opa-network
    restart: always

  certbot:
    image: certbot/certbot
    container_name: opa-certbot
    volumes:
      - ./ssl:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

volumes:
  postgres_data:
  redis_data:
  minio_data:

networks:
  opa-network:
    driver: bridge
```

#### `backend/Dockerfile.prod`

```dockerfile
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY prisma ./prisma/
RUN npx prisma generate

COPY . .
RUN npm run build

FROM node:18-alpine

RUN apk add --no-cache curl

WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package*.json ./

EXPOSE 3000

CMD ["node", "dist/main.js"]
```

---

## Database Setup

### Initial Database Configuration

```sql
-- Create database
CREATE DATABASE opa_db;
CREATE DATABASE opa_db_replica;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create users
CREATE USER opa_app WITH PASSWORD 'strong_password';
CREATE USER opa_replica WITH PASSWORD 'replica_password';
CREATE USER opa_backup WITH PASSWORD 'backup_password';

-- Grant privileges
GRANT CONNECT ON DATABASE opa_db TO opa_app;
GRANT ALL PRIVILEGES ON DATABASE opa_db TO opa_app;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO opa_replica;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO opa_replica;
```

### Performance Tuning

```sql
-- postgresql.conf optimizations
ALTER SYSTEM SET shared_buffers = '8GB';
ALTER SYSTEM SET effective_cache_size = '24GB';
ALTER SYSTEM SET maintenance_work_mem = '2GB';
ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM SET max_connections = '500';
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET checkpoint_completion_target = '0.9';
ALTER SYSTEM SET random_page_cost = '1.1';
ALTER SYSTEM SET effective_io_concurrency = '200';

-- Create indexes for performance
CREATE INDEX CONCURRENTLY idx_harvests_date ON harvests(harvest_date);
CREATE INDEX CONCURRENTLY idx_harvests_block ON harvests(block_id);
CREATE INDEX CONCURRENTLY idx_inspections_created ON inspections(created_at);
CREATE INDEX CONCURRENTLY idx_blocks_geometry ON blocks USING GIST(geometry);
CREATE INDEX CONCURRENTLY idx_messages_chat ON messages(chat_id, created_at DESC);

-- Partition large tables (for estates >10,000 hectares)
CREATE TABLE harvests_2024 PARTITION OF harvests 
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

### Automated Backups

```bash
#!/bin/bash
# backup.sh - Daily database backup

#!/bin/bash
BACKUP_DIR="/backups/postgres"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="opa_db"
S3_BUCKET="s3://opa-backups"

# Create backup
pg_dump -h localhost -U opa_backup $DB_NAME | gzip > $BACKUP_DIR/opa_$DATE.sql.gz

# Upload to S3
aws s3 cp $BACKUP_DIR/opa_$DATE.sql.gz $S3_BUCKET/postgres/

# Keep last 30 days locally
find $BACKUP_DIR -type f -mtime +30 -delete

# Send notification
curl -X POST https://api.opa-app.com/webhooks/backup-status \
  -H "Content-Type: application/json" \
  -d "{\"status\":\"success\",\"file\":\"opa_$DATE.sql.gz\"}"
```

### Cron Job Setup

```bash
# Add to crontab
0 2 * * * /opt/scripts/backup.sh
0 */6 * * * /opt/scripts/cleanup_temp.sh
*/5 * * * * /opt/scripts/health_check.sh
```

---

## Backend Deployment

### Environment Configuration

```bash
# .env.production
# Database
DATABASE_URL="postgresql://opa_app:password@postgres.opa.internal:5432/opa_db"
DATABASE_REPLICA_URL="postgresql://opa_replica:password@postgres-replica.opa.internal:5432/opa_db"

# Redis
REDIS_URL="redis://:redis_password@redis.opa.internal:6379"
REDIS_CLUSTER="redis://redis-1:6379,redis://redis-2:6379"

# JWT
JWT_SECRET="$(openssl rand -base64 32)"
JWT_EXPIRES_IN="7d"

# API
API_PORT=3000
API_RATE_LIMIT=1000
API_CORS_ORIGIN="https://app.opa.com"

# Storage
S3_ENDPOINT="https://s3.opa.internal"
S3_BUCKET="opa-storage-prod"
AWS_ACCESS_KEY_ID="AKIA..."
AWS_SECRET_ACCESS_KEY="..."

# External Services
MAPBOX_TOKEN="pk.eyJ1Ijoi..."
OPENWEATHER_API_KEY="..."

# FCM
FCM_PROJECT_ID="opa-prod-123"
FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----..."

# Monitoring
SENTRY_DSN="https://xxx@sentry.io/xxx"
NEW_RELIC_LICENSE_KEY="..."

# Feature Flags
ENABLE_DRONE_AI=true
ENABLE_WEATHER_PREDICTION=true
ENABLE_REAL_TIME_CHAT=true
```

### PM2 Configuration

```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'opa-api',
    script: 'dist/main.js',
    instances: 'max',
    exec_mode: 'cluster',
    watch: false,
    max_memory_restart: '6G',
    env: {
      NODE_ENV: 'production',
    },
    error_file: '/var/log/opa/error.log',
    out_file: '/var/log/opa/out.log',
    log_file: '/var/log/opa/combined.log',
    time: true,
    kill_timeout: 5000,
    listen_timeout: 10000,
    instance_var: 'INSTANCE_ID',
    node_args: '--max-old-space-size=5120',
  }],
};
```

### Nginx Configuration

```nginx
# /etc/nginx/sites-available/opa-api
upstream opa_backend {
    least_conn;
    server 10.0.1.10:3000 max_fails=3 fail_timeout=30s;
    server 10.0.1.11:3000 max_fails=3 fail_timeout=30s;
    server 10.0.1.12:3000 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

server {
    listen 80;
    server_name api.opa-app.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name api.opa-app.com;

    ssl_certificate /etc/letsencrypt/live/api.opa-app.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.opa-app.com/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL:10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/s;
    limit_req zone=api burst=200 nodelay;

    client_max_body_size 100M;
    proxy_read_timeout 300s;
    proxy_connect_timeout 75s;

    location / {
        proxy_pass http://opa_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_buffering off;
    }

    location /health {
        proxy_pass http://opa_backend/health;
        access_log off;
    }

    location /metrics {
        proxy_pass http://opa_backend/metrics;
        allow 10.0.0.0/8;
        deny all;
    }
}
```

---

## Mobile App Deployment

### Android Play Store

#### 1. Build Release APK

```bash
# Generate keystore
keytool -genkey -v -keystore opa-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias opa-key

# Build release APK
flutter build apk --release --split-per-abi

# Build App Bundle (recommended)
flutter build appbundle --release
```

#### 2. `android/app/build.gradle` Configuration

```gradle
android {
    defaultConfig {
        applicationId "com.opa.app"
        minSdkVersion 21
        targetSdkVersion 33
        versionCode 30
        versionName "3.0.0"
    }

    signingConfigs {
        release {
            keyAlias 'opa-key'
            keyPassword System.getenv('KEYSTORE_PASSWORD')
            storeFile file('opa-keystore.jks')
            storePassword System.getenv('KEYSTORE_PASSWORD')
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

#### 3. Upload to Play Store

```bash
# Using Google Play Publisher API
gcloud auth activate-service-account --key-file=service-account.json
gcloud alpha firebase test android run \
  --app build/app/outputs/bundle/release/app-release.aab \
  --device model=Nexus6P,version=28

# Upload using Fastlane
fastlane supply --apk build/app/outputs/flutter-apk/app-release.apk \
  --track production \
  --release-status completed
```

### iOS App Store

#### 1. Build IPA

```bash
# Build for iOS
flutter build ios --release

# Archive using Xcode
cd ios
xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -sdk iphoneos \
  -configuration Release \
  archive -archivePath $PWD/build/Runner.xcarchive

# Export IPA
xcodebuild -exportArchive \
  -archivePath $PWD/build/Runner.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath $PWD/build
```

#### 2. `ExportOptions.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.opa.app</key>
        <string>match AppStore com.opa.app</string>
    </dict>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

---

## Monitoring & Logging

### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'opa-api'
    static_configs:
      - targets: ['api.opa-app.com:3000']
    metrics_path: '/metrics'

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']
```

### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "OPA Production Monitoring",
    "panels": [
      {
        "title": "API Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{endpoint}}"
          }
        ]
      },
      {
        "title": "Response Time (95th percentile)",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "{{endpoint}}"
          }
        ]
      },
      {
        "title": "Database Connections",
        "type": "singlestat",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])",
            "legendFormat": "5xx errors"
          }
        ]
      }
    ]
  }
}
```

### Alert Rules (Prometheus)

```yaml
# alerts.yml
groups:
  - name: opa_alerts
    interval: 30s
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }}% for past 5 minutes"

      - alert: APIHighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High API latency"
          description: "95th percentile latency is {{ $value }}s"

      - alert: DatabaseHighConnections
        expr: pg_stat_database_numbackends > 450
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "Database connection pool nearly full"

      - alert: LowDiskSpace
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space"
          description: "Only {{ $value }}% disk space remaining"
```

---

## Backup & Recovery

### Backup Strategy

| Type | Frequency | Retention | Location |
|------|-----------|-----------|----------|
| Full DB backup | Daily | 30 days | S3 + Local |
| WAL archive | Hourly | 7 days | S3 |
| Incremental | Every 6 hours | 14 days | S3 |
| Image backup | Daily | 90 days | S3 Glacier |
| Config backup | On change | Indefinite | Git |

### Automated Backup Script

```bash
#!/bin/bash
# full-backup.sh

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/full/$BACKUP_DATE"

mkdir -p $BACKUP_DIR

# Database backup
pg_dump -h localhost -U opa_backup -d opa_db \
  | gzip > $BACKUP_DIR/database.sql.gz

# Upload to S3
aws s3 cp $BACKUP_DIR/database.sql.gz \
  s3://opa-backups/database/full/$BACKUP_DATE.sql.gz \
  --storage-class STANDARD_IA

# Upload to backup region
aws s3 cp $BACKUP_DIR/database.sql.gz \
  s3://opa-backups-ap-southeast-2/database/full/$BACKUP_DATE.sql.gz \
  --storage-class STANDARD_IA

# Generate manifest
cat > $BACKUP_DIR/manifest.json << EOF
{
  "backup_date": "$BACKUP_DATE",
  "type": "full",
  "database_size": "$(du -h $BACKUP_DIR/database.sql.gz | cut -f1)",
  "wal_position": "$(psql -d opa_db -t -c 'SELECT pg_current_wal_lsn()')"
}
EOF

# Cleanup old backups
find /backups/full -type d -mtime +30 -exec rm -rf {} \;

# Send notification
curl -X POST https://api.opa-app.com/webhooks/backup-status \
  -H "Content-Type: application/json" \
  -d "{\"status\":\"success\",\"type\":\"full\",\"date\":\"$BACKUP_DATE\"}"
```

### Recovery Procedure

```bash
#!/bin/bash
# recovery.sh - Disaster recovery

# 1. Stop application
systemctl stop opa-api

# 2. Restore database
gunzip -c /backups/full/20240215_020000/database.sql.gz | \
  psql -h localhost -U opa_admin -d opa_db

# 3. Restore WAL (point-in-time recovery)
cat > recovery.conf << EOF
restore_command = 'aws s3 cp s3://opa-backups/wal/%f %p'
recovery_target_time = '2024-02-15 01:00:00'
EOF

# 4. Restore images from S3
aws s3 sync s3://opa-storage-prod/images /data/images
aws s3 sync s3://opa-storage-prod/drone /data/drone

# 5. Restart database
systemctl restart postgresql

# 6. Verify data
psql -d opa_db -c "SELECT COUNT(*) FROM harvests WHERE harvest_date > '2024-02-14'"

# 7. Start application
systemctl start opa-api

# 8. Verify health
curl -f https://api.opa-app.com/health
```

---

## Security Hardening

### System Security

```bash
# Firewall configuration (UFW)
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw enable

# Fail2ban configuration
cat > /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[opa-api]
enabled = true
port = http,https
filter = opa-api
logpath = /var/log/opa/error.log
maxretry = 10
bantime = 600
EOF

# SELinux
setenforce enforcing

# Kernel hardening
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_timestamps = 0
net.ipv6.conf.all.disable_ipv6 = 1
EOF
```

### Application Security

```typescript
// Security middleware in NestJS
app.use(helmet());
app.use(csurf());

app.use(
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: 'Too many requests',
  }),
);

// Input validation
@Post()
@UsePipes(new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
}))
async create(@Body() dto: CreateHarvestDto) {
  // ...
}

// SQL injection prevention
const harvests = await prisma.$queryRaw`
  SELECT * FROM harvests 
  WHERE block_id = ${blockId}
  AND harvest_date > ${startDate}
`;

// XSS prevention (sanitize user input)
import * as DOMPurify from 'dompurify';
const sanitizedHtml = DOMPurify.sanitize(userInput);
```

### Regular Security Audits

```bash
# Weekly vulnerability scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image opa-backend:latest

# Monthly dependency check
npm audit --production
safety check -r requirements.txt

# Quarterly penetration test
nikto -h https://api.opa-app.com
nmap -sV -sC -p- api.opa-app.com
```

---

## Scaling Guide

### Horizontal Scaling

```yaml
# Kubernetes deployment (HPA)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: opa-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: opa-api
  minReplicas: 3
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: 1000
```

### Database Scaling

```sql
-- Read replicas for queries
CREATE SUBSCRIPTION opa_replica_subscription
CONNECTION 'host=primary-db port=5432 user=replication password=...'
PUBLICATION opa_publication;

-- Table partitioning (for very large estates)
CREATE TABLE harvests_2024 PARTITION OF harvests
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

-- Connection pooling (PgBouncer)
-- pgbouncer.ini
[databases]
opa_db = host=localhost port=5432 dbname=opa_db

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
max_client_conn = 2000
default_pool_size = 50
```

### Redis Scaling

```bash
# Redis cluster setup
redis-cli --cluster create \
  10.0.1.10:6379 \
  10.0.1.11:6379 \
  10.0.1.12:6379 \
  --cluster-replicas 1

# Connection pooling configuration
redis:
  options:
    maxRetriesPerRequest: 3
    enableReadyCheck: true
    maxLoadingRetryTime: 10000
    retryStrategy: (times) => Math.min(times * 50, 2000)
```

---

## Disaster Recovery

### RTO/RPO Objectives

| Service | RTO | RPO |
|---------|-----|-----|
| API Servers | 15 min | N/A |
| Database | 30 min | 5 min |
| Storage | 1 hour | 15 min |
| DNS | 5 min | N/A |

### Disaster Recovery Runbook

```bash
#!/bin/bash
# disaster-recovery.sh

# 1. Detect failure
if ! curl -f https://api.opa-app.com/health; then
    echo "Primary region failed, initiating failover"
fi

# 2. Promote replica to primary
aws rds promote-read-replica \
  --db-instance-identifier opa-replica \
  --backup-retention-period 7

# 3. Update DNS
aws route53 change-resource-record-sets \
  --hosted-zone-id ZXXXXXXXXX \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "api.opa-app.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "failover-lb.opa.com",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'

# 4. Switch storage to backup region
aws s3 sync s3://opa-backups-ap-southeast-2/ s3://opa-storage/

# 5. Restore services
kubectl apply -f k8s/failover-config.yaml
```

### Regular DR Tests

```bash
# Monthly failover test
./scripts/dr-test.sh --mode=simulate

# Quarterly full DR test
./scripts/dr-test.sh --mode=full

# Annual chaos testing
chaos run --duration 1h --probability 0.1