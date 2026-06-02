# OPA Troubleshooting Guide

## Table of Contents

1. [Common Issues & Solutions](#common-issues--solutions)
2. [Mobile App Issues](#mobile-app-issues)
3. [Backend Issues](#backend-issues)
4. [Database Issues](#database-issues)
5. [Sync Issues](#sync-issues)
6. [Map & Location Issues](#map--location-issues)
7. [Drone Integration Issues](#drone-integration-issues)
8. [Performance Issues](#performance-issues)
9. [Error Codes](#error-codes)
10. [Logging & Debugging](#logging--debugging)
11. [Support Escalation](#support-escalation)

---

## Common Issues & Solutions

### Issue: Can't Login

**Symptoms:**
- "Invalid credentials" error
- OTP not received
- Stuck at loading screen

**Solutions:**

1. **Check network connectivity**
   ```bash
   # From device
   ping api.opa-app.com
   traceroute api.opa-app.com
   ```

2. **Verify phone number format**
   - Indonesia: 08123456789 or +628123456789
   - International: +[country code][number]

3. **OTP not received**
   - Wait 60 seconds, request again
   - Check spam folder for email
   - Contact supervisor to verify registration

4. **Clear app cache**
   ```
   Settings → Apps → OPA → Clear Cache
   Settings → Apps → OPA → Clear Data
   ```

### Issue: App Crashes on Launch

**Symptoms:**
- App closes immediately after opening
- Black screen then crash

**Solutions:**

1. **Update app** to latest version
2. **Check device compatibility**
   - Android 8+ required
   - iOS 13+ required
3. **Free up storage space**
   - Minimum 500MB free
4. **Reinstall app**
   ```bash
   # Backup offline data first
   # Then uninstall and reinstall
   ```

### Issue: Data Not Syncing

**Symptoms:**
- "Pending sync" indicator shows
- Data missing on other devices
- Sync spinner spinning endlessly

**Solutions:**

1. **Check internet connection**
2. **Manual sync**
   - Pull down to refresh
   - Tap sync button in Settings
3. **Check storage space**
   - Need 100MB+ for sync queue
4. **Clear sync queue**
   ```
   Settings → Advanced → Clear Sync Queue
   ```

---

## Mobile App Issues

### Authentication Errors

| Error Code | Message | Solution |
|------------|---------|----------|
| AUTH001 | OTP expired | Request new code |
| AUTH002 | Invalid OTP | Enter correct 6-digit code |
| AUTH003 | Account locked | Contact admin (5 failed attempts) |
| AUTH004 | Session expired | Login again |
| AUTH005 | Device not registered | Contact supervisor |

### Offline Mode Issues

**Problem: Can't access offline map**

```bash
# Check offline map status
Settings → Offline Maps → Storage Used
# Re-download if corrupted
Settings → Offline Maps → Delete Region → Re-download
```

**Problem: Offline data loss**

```bash
# Recover from local backup
/data/data/com.opa.app/databases/opa.db.backup
# Manual recovery requires root access
```

### Camera Issues

**Problem: Can't take photos**

1. Check camera permissions
2. Free up storage space
3. Restart device
4. Use external camera app as workaround

**Problem: Photos not uploading**

```bash
# Check image size
# Compress if >10MB
adb shell
ls -la /storage/emulated/0/OPA/images/
```

---

## Backend Issues

### API Server Not Responding

**Checklist:**

```bash
# 1. Check service status
systemctl status opa-api
pm2 status

# 2. Check logs
tail -f /var/log/opa/error.log
journalctl -u opa-api -n 50

# 3. Check port listening
netstat -tlnp | grep 3000
ss -tlnp | grep 3000

# 4. Check resources
htop
free -h
df -h

# 5. Restart service
systemctl restart opa-api
pm2 restart all
```

### High Memory Usage

**Diagnosis:**

```bash
# Check Node.js memory
pm2 monit
node --max-old-space-size=5120

# Check for memory leaks
npm run profile-memory

# Analyze heap dump
node --inspect dist/main.js
# Open chrome://inspect in browser
```

**Solutions:**

```javascript
// Increase memory limit
node --max-old-space-size=8192 dist/main.js

// Enable garbage collection logging
node --trace-gc dist/main.js

// Optimize queries
// Add indexes, limit results, use pagination
```

### WebSocket Connection Issues

**Symptoms:**
- Chat not working
- Real-time updates not received
- Frequent disconnections

**Solutions:**

```nginx
# Nginx configuration for WebSocket
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;

# Increase connection limit
ulimit -n 65536
```

```javascript
// Socket.io configuration
const io = new Server(server, {
  pingTimeout: 60000,
  pingInterval: 25000,
  transports: ['websocket', 'polling'],
});
```

---

## Database Issues

### Connection Pool Exhaustion

**Symptoms:**
- "Too many connections" error
- Slow queries
- Timeout errors

**Diagnosis:**

```sql
-- Check current connections
SELECT COUNT(*) FROM pg_stat_activity;

-- Show active connections
SELECT pid, usename, application_name, state 
FROM pg_stat_activity 
WHERE state = 'active';

-- Kill idle connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' 
AND age(now(), state_change) > interval '30 minutes';
```

**Solutions:**

```sql
-- Increase max connections
ALTER SYSTEM SET max_connections = '500';
SELECT pg_reload_conf();

-- Add connection pooler (PgBouncer)
-- pgbouncer.ini
pool_mode = transaction
default_pool_size = 100
max_client_conn = 2000
```

### Slow Queries

**Identify slow queries:**

```sql
-- Enable slow query log
ALTER SYSTEM SET log_min_duration_statement = '1000';
SELECT pg_reload_conf();

-- Find slow queries
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT * FROM harvests 
WHERE harvest_date BETWEEN '2024-01-01' AND '2024-12-31';
```

**Optimization:**

```sql
-- Add missing indexes
CREATE INDEX CONCURRENTLY idx_harvests_date_block 
ON harvests(harvest_date, block_id);

-- Vacuum analyze
VACUUM ANALYZE harvests;
VACUUM ANALYZE inspections;

-- Partition large tables
CREATE TABLE harvests_2024 PARTITION OF harvests
FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
```

### Database Replication Lag

**Check lag:**

```sql
-- On replica
SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();

-- Calculate lag in bytes
SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) 
FROM pg_stat_replication;
```

**Solutions:**

```bash
# Increase replica resources
# Optimize replica settings
ALTER SYSTEM SET hot_standby_feedback = 'on';
ALTER SYSTEM SET max_standby_archive_delay = '30s';
ALTER SYSTEM SET max_standby_streaming_delay = '30s';
```

---

## Sync Issues

### Offline Sync Failures

**Debug sync queue:**

```sql
-- Check pending sync items
SELECT * FROM sync_queue 
WHERE status = 'pending' 
ORDER BY created_at;

-- Check failed items
SELECT * FROM sync_queue 
WHERE status = 'failed' 
AND retry_count < 5;

-- Clear stuck queue
DELETE FROM sync_queue 
WHERE status = 'processing' 
AND created_at < NOW() - INTERVAL '1 hour';
```

**Manual conflict resolution:**

```javascript
// Last-write-wins policy
const serverRecord = await prisma.harvest.findUnique({
  where: { id: localRecord.id }
});

if (localRecord.updatedAt > serverRecord.updatedAt) {
  // Local is newer, overwrite server
  await prisma.harvest.update({
    where: { id: localRecord.id },
    data: localRecord
  });
} else {
  // Server is newer, overwrite local
  await localDb.update('harvests', serverRecord);
}
```

### Conflict Resolution

**Types of conflicts:**

| Type | Resolution |
|------|------------|
| Same field edited | Last write wins |
| Different fields | Merge both |
| Delete vs edit | Delete wins |
| Offline create vs server create | Keep both (different IDs) |

**Manual merge UI in app:**

```dart
// Conflict resolver widget
ConflictResolver(
  localData: localHarvest,
  serverData: serverHarvest,
  onResolve: (merged) async {
    await syncService.resolveConflict(merged);
  },
);
```

---

## Map & Location Issues

### Map Not Loading

**Diagnosis:**

```bash
# Check Mapbox token
curl "https://api.mapbox.com/styles/v1/mapbox/streets-v12?access_token=YOUR_TOKEN"

# Check network connectivity
ping tiles.mapbox.com
```

**Solutions:**

```javascript
// Verify token in app
MapboxOptions.setAccessToken('YOUR_TOKEN');

// Download offline maps as fallback
OfflineManager.shared.downloadRegion(
  region: OfflineRegion(
    geometry: bounds,
    minZoom: 0,
    maxZoom: 18,
  ),
  completion: { region in
    print("Downloaded offline map")
  }
);
```

### GPS Not Working

**Android troubleshooting:**

```bash
# Check location settings
adb shell settings get secure location_mode

# Force high accuracy
adb shell settings put secure location_mode 3

# Clear AGPS data
adb shell pm clear com.google.android.gms
```

**iOS troubleshooting:**

```bash
# Check location permissions
# Settings → Privacy → Location Services → OPA → Always

# Reset location warnings
# Settings → General → Reset → Reset Location & Privacy
```

**Code fix:**

```dart
// Request permissions properly
Future<Position> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    await Geolocator.openLocationSettings();
    return Future.error('Location services disabled');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions denied');
    }
  }
  
  return await Geolocator.getCurrentPosition();
}
```

---

## Drone Integration Issues

### Upload Failures

**Symptoms:**
- "Upload failed" error
- Images stuck in queue
- Slow upload speed

**Solutions:**

```bash
# Check image format
file drone_image.jpg
# Should be JPEG or TIFF

# Compress large images
mogrify -resize 3840x2160 -quality 85 *.jpg

# Batch upload with retry
for i in *.jpg; do
  curl -X POST https://api.opa-app.com/drone/upload \
    -F "image=@$i" \
    --retry 3 \
    --retry-delay 2
done
```

### Orthomosaic Processing Failed

**Check processing logs:**

```bash
# On ODM server
docker logs odm-node
cat /var/log/odm/processing.log

# Common issues
# Not enough memory - increase RAM
docker run --memory=16g opendronemap/odm

# Not enough disk space
df -h /var/lib/docker

# Invalid images
exiftool *.jpg | grep "Image Size"
```

**Retry processing:**

```bash
# Reset mission status
UPDATE drone_missions SET status = 'UPLOADED' WHERE id = 'xxx';

# Manually trigger processing
curl -X POST https://api.opa-app.com/drone/missions/xxx/process
```

### NDVI Calculation Issues

**Diagnosis:**

```python
# Check band availability
import rasterio
with rasterio.open('orthomosaic.tif') as src:
    print(src.count)  # Should be 4 (RGB + NIR)
    print(src.meta)

# Fix missing NIR band
# NDVI = (NIR - Red) / (NIR + Red)
```

**Manual NDVI generation:**

```python
import numpy as np
from osgeo import gdal

def calculate_ndvi(red_band, nir_band):
    np.seterr(divide='ignore', invalid='ignore')
    ndvi = (nir_band.astype(float) - red_band.astype(float)) / (nir_band + red_band)
    ndvi = np.clip(ndvi, -1, 1)
    return ndvi
```

---

## Performance Issues

### Slow App Performance

**Mobile device profiling:**

```bash
# Flutter performance
flutter run --profile
flutter run --trace-startup

# Android profiling
adb shell dumpsys meminfo com.opa.app
adb shell top -n 1 -s cpu | grep opa

# iOS profiling
# Use Xcode Instruments
```

**Optimization tips:**

```dart
// Lazy loading for lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)

// Image caching
CachedNetworkImage(
  imageUrl: url,
  memCacheWidth: 500,
  memCacheHeight: 500,
)

// Database indexing
await db.execute('CREATE INDEX idx_harvests_date ON harvests(harvest_date)');

// Reduce rebuilds
Consumer(builder: (context, ref, child) {
  return Text(ref.watch(selectedProvider));
})
```

### Backend Performance

**Load testing:**

```bash
# Install k6
brew install k6

# Run load test
k6 run --vus 100 --duration 30s load-test.js
```

**Sample load test:**

```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 }, // Ramp up
    { duration: '5m', target: 100 }, // Stay at 100
    { duration: '2m', target: 0 },   // Ramp down
  ],
};

export default function () {
  const res = http.get('https://api.opa-app.com/harvests');
  check(res, { 'status is 200': (r) => r.status === 200 });
  sleep(1);
}
```

**Performance bottlenecks:**

```javascript
// Use connection pooling
const pool = new Pool({
  max: 20,
  idleTimeoutMillis: 30000,
});

// Add caching
const cachedHarvests = await redis.get(`harvests:${blockId}`);
if (cachedHarvests) {
  return JSON.parse(cachedHarvests);
}

// Optimize database queries
const harvests = await prisma.harvest.findMany({
  where: { blockId },
  select: { id: true, tonase: true }, // Only needed fields
  take: 100, // Limit results
});
```

---

## Error Codes

### Client Error Codes (4xx)

| Code | Meaning | Solution |
|------|---------|----------|
| 400 | Bad Request | Check request format |
| 401 | Unauthorized | Login again |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Check ID/resource exists |
| 409 | Conflict | Sync conflict, need manual resolution |
| 413 | Payload Too Large | Compress image/file |
| 422 | Unprocessable Entity | Validation failed |
| 429 | Too Many Requests | Reduce request rate |

### Server Error Codes (5xx)

| Code | Meaning | Solution |
|------|---------|----------|
| 500 | Internal Server Error | Check logs, restart service |
| 502 | Bad Gateway | Check Nginx/load balancer |
| 503 | Service Unavailable | Service down, check status |
| 504 | Gateway Timeout | Increase timeout or optimize query |

### Business Logic Errors

| Code | Message | Solution |
|------|---------|----------|
| BUS001 | Block not found | Verify block ID |
| BUS002 | Insufficient quota | Contact admin |
| BUS003 | Duplicate entry | Check for existing record |
| BUS004 | Date out of range | Use valid date range |
| BUS005 | Invalid coordinates | Check lat/lng format |
| BUS006 | No offline storage | Free up space |

---

## Logging & Debugging

### Enable Debug Logging

**Mobile app:**

```dart
// main.dart
void main() {
  if (kDebugMode) {
    Logger.level = Level.ALL;
    HttpOverrides.global = MyHttpOverrides();
  }
  runApp(OPAApp());
}

// View logs
flutter logs
adb logcat | grep -i opa
```

**Backend:**

```typescript
// logger.config.ts
export const loggerConfig = {
  level: process.env.LOG_LEVEL || 'info',
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
    new winston.transports.Console({ format: winston.format.simple() })
  ],
};

// Use in code
this.logger.debug(`Processing harvest ${harvestId}`);
this.logger.error(`Failed to sync: ${error.message}`, error.stack);
```

### Debugging Tools

**Mobile:**

```bash
# Flutter DevTools
flutter pub global run devtools

# Android Studio Profiler
# View → Tool Windows → Profiler

# Flutter inspector
# Widget tree visualization
```

**Backend:**

```bash
# Node.js inspector
node --inspect dist/main.js
# Open chrome://inspect

# API debugging with Postman
# Collection: https://www.postman.com/opa

# Database query logging
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

### Collecting Debug Information

**Mobile debug bundle:**

```dart
Future<void> exportDebugInfo() async {
  final db = await DatabaseHelper.instance.database;
  final tables = await db.query('sqlite_master');
  
  final debugInfo = {
    'app_version': await getVersion(),
    'device_info': await getDeviceInfo(),
    'db_size': await getDbSize(),
    'sync_queue': await db.query('sync_queue'),
    'logs': await getLogs(),
  };
  
  final file = await saveJsonToFile(debugInfo);
  await Share.shareFiles([file.path]);
}
```

**Backend debug endpoint:**

```typescript
@Get('debug/info')
@Roles('ADMIN')
async getDebugInfo() {
  return {
    version: process.env.npm_package_version,
    node_version: process.version,
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    db_connections: await this.getDbConnections(),
    redis_info: await this.getRedisInfo(),
    queue_size: await this.getQueueSize(),
  };
}
```

---

## Support Escalation

### Support Levels

| Level | Response Time | Contact |
|-------|---------------|---------|
| L1 (Basic) | 2 hours | Chat support |
| L2 (Technical) | 4 hours | Email support |
| L3 (Advanced) | 8 hours | Ticket system |
| L4 (Emergency) | 15 minutes | Phone + SMS |

### Creating Support Ticket

**Required information:**

```yaml
Ticket Template:
  - User ID: _____________
  - App Version: _____________
  - Device Model: _____________
  - OS Version: _____________
  - Issue Type: [Bug/Feature/Question]
  - Steps to Reproduce:
    1. 
    2. 
    3.
  - Expected Result:
  - Actual Result:
  - Screenshots/Video: [Attached]
  - Logs: [Attached]
  - Timestamp: _____________
```

### Escalation Matrix

| Severity | Definition | Action |
|----------|------------|--------|
| **S0** | System down, data loss | Page on-call engineer immediately |
| **S1** | Major feature broken | Respond within 1 hour |
| **S2** | Minor feature broken | Respond within 4 hours |
| **S3** | Cosmetic issue | Next release |
| **S4** | Question/Request | 24 hours |

### On-Call Runbook

```bash
#!/bin/bash
# emergency-response.sh

# 1. Acknowledge incident
curl -X POST https://api.opa-app.com/incidents/ack \
  -H "Authorization: Bearer $API_KEY"

# 2. Check primary systems
for service in api postgres redis; do
  systemctl status $service || \
    curl -X POST https://api.opa-app.com/incidents/log \
    -d "{\"service\":\"$service\",\"status\":\"failed\"}"
done

# 3. Restore from backup if needed
./scripts/restore-latest-backup.sh

# 4. Update status page
curl -X POST https://status.opa-app.com/update \
  -d "{\"status\":\"degraded\",\"message\":\"Investigating issue\"}"

# 5. Notify affected users
aws sns publish --topic-arn arn:aws:sns:... \
  --message "We're investigating performance issues. Updates soon."