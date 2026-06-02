# 🌴 Oil Palm Assistant (OPA)

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/readloud/opa)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.16+-blue.svg)](https://flutter.dev)
[![NestJS](https://img.shields.io/badge/NestJS-10.0+-red.svg)](https://nestjs.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

**Oil Palm Assistant** adalah aplikasi manajemen perkebunan kelapa sawit yang komprehensif, dirancang untuk mendigitalisasi operasional kebun dari lapangan hingga laporan manajemen.

![Dashboard Preview](https://github.com/readloud/opa/blob/main/mockup.jpeg))

## 📋 Daftar Isi

- [Fitur Utama](#fitur-utama)
- [Teknologi](#teknologi)
- [Arsitektur](#arsitektur)
- [Instalasi](#instalasi)
- [Konfigurasi](#konfigurasi)
- [Penggunaan](#penggunaan)
- [API Documentation](#api-documentation)
- [Testing](#testing)
- [Deployment](#deployment)
- [Kontribusi](#kontribusi)
- [Lisensi](#lisensi)

## 🚀 Fitur Utama

### Mobile App (Flutter)
- ✅ **Autentikasi** - Login dengan OTP (SMS/Email) + JWT
- ✅ **Dashboard** - KPI real-time, chart produksi, notifikasi
- ✅ **Peta Interaktif** - Mapbox dengan polygon blok, offline support
- ✅ **Manajemen Tugas** - Assign, tracking, reminder tugas lapangan
- ✅ **Pencatatan Lapangan** - Inspeksi, panen, pemupukan (offline-first)
- ✅ **Chat Real-time** - Komunikasi tim lapangan dengan WebSocket
- ✅ **Deteksi Hama AI** - Identifikasi hama dari foto dengan TensorFlow
- ✅ **Integrasi Drone** - Upload orthomosaic, NDVI analysis, 3D model
- ✅ **Laporan & Ekspor** - PDF, CSV, Excel dengan chart interaktif
- ✅ **Multi-bahasa** - Indonesia & English

### Backend (NestJS)
- ✅ **RESTful API** - Lengkap dengan dokumentasi Swagger
- ✅ **WebSocket Gateway** - Real-time chat & notifikasi
- ✅ **PostgreSQL + PostGIS** - Data spasial untuk peta
- ✅ **S3 Storage** - Penyimpanan gambar dan file drone
- ✅ **Machine Learning** - Pest detection, yield prediction
- ✅ **Weather Integration** - OpenWeatherMap API
- ✅ **Work Order Automation** - Generate task dari deteksi drone
- ✅ **Role-based Access** - Admin, Supervisor, Field Worker

### Admin Web (Opsional)
- ✅ **Multi-estate Dashboard** - Monitoring semua kebun
- ✅ **Analytics & Reporting** - Chart interaktif, export data
- ✅ **User Management** - Kelola akun dan role

## 🛠 Teknologi

### Frontend (Mobile)
| Teknologi | Versi | Kegunaan |
|-----------|-------|----------|
| Flutter | 3.16+ | Framework utama |
| Riverpod | 2.4+ | State management |
| SQLite | 2.3+ | Database offline |
| Mapbox | 1.4+ | Peta & geolocation |
| WebSocket | - | Chat real-time |
| TensorFlow Lite | - | Deteksi hama offline |

### Backend
| Teknologi | Versi | Kegunaan |
|-----------|-------|----------|
| NestJS | 10.0+ | Framework backend |
| PostgreSQL | 15+ | Database utama |
| PostGIS | 3.4+ | Data spasial |
| Prisma | 5.8+ | ORM |
| Redis | 7+ | Cache & session |
| Socket.io | 4+ | WebSocket |
| TensorFlow | 2.13+ | ML inference |

### DevOps
- **Docker** - Containerization
- **GitHub Actions** - CI/CD pipeline
- **AWS S3 / MinIO** - Object storage
- **PM2** - Process management

## 🏗 Arsitektur

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                       │
├───────────────┬───────────────┬─────────────────────────────┤
│  Offline      │  Real-time    │    Local DB (SQLite)        │
│  First        │  Sync         │    (Pending Queue)          │
└───────────────┴───────────────┴─────────────────────────────┘
                              │
                              │ HTTPS / WebSocket
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    NestJS Backend API                       │
├───────────────┬───────────────┬─────────────────────────────┤
│  Auth         │  REST API     │    WebSocket Gateway        │
│  JWT + OTP    │  Controllers  │    (Chat & Notif)           │
└───────────────┴───────────────┴─────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    PostgreSQL + PostGIS                     │
│  • Users • Estates • Blocks • Tasks • Harvests • Messages   │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Instalasi

### Prerequisites
- **Flutter**: 3.16 atau lebih baru
- **Node.js**: 18.x atau lebih baru
- **PostgreSQL**: 15+ dengan PostGIS
- **Docker** (opsional, untuk development)

### 1. Clone Repository

```bash
git clone https://github.com/readloud/opa.git
cd opa
```

### 2. Backend Setup

```bash
cd backend

# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Edit .env with your credentials
# - Database URL
# - JWT Secret
# - Twilio credentials (SMS OTP)
# - SMTP (Email OTP)
# - AWS S3 credentials

# Run database migrations
npx prisma generate
npx prisma migrate dev --name init

# Seed database (optional)
npx prisma db seed

# Start development server
npm run start:dev
```

### 3. Frontend Setup

```bash
cd frontend

# Install dependencies
flutter pub get

# Generate localization files
flutter gen-l10n

# Run the app
flutter run
```

### 4. Docker Setup (Alternative)

```bash
# Build and run all services
docker-compose up -d

# Services will be available at:
# - Backend API: http://localhost:3000
# - PostgreSQL: localhost:5432
# - MinIO Console: http://localhost:9001
# - Redis: localhost:6379
```

## ⚙️ Konfigurasi

### Environment Variables (.env)

```env
# Database
DATABASE_URL="postgresql://user:pass@localhost:5432/opa_db"

# JWT
JWT_SECRET="your-super-secret-key-min-32-chars"
JWT_EXPIRES_IN="7d"

# Twilio (SMS OTP)
TWILIO_ACCOUNT_SID="ACxxxxxxxxxxxxx"
TWILIO_AUTH_TOKEN="xxxxxxxxxxxxxxxx"
TWILIO_PHONE_NUMBER="+1234567890"

# Email (SMTP)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="noreply@opa.com"
SMTP_PASS="your-app-password"

# AWS S3
AWS_ACCESS_KEY_ID="AKIAxxxxxxxx"
AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxx"
AWS_S3_BUCKET="opa-storage"
AWS_REGION="ap-southeast-1"

# Mapbox
MAPBOX_ACCESS_TOKEN="pk.eyJ1Ijoi..."

# OpenWeather
OPENWEATHER_API_KEY="your-api-key"

# Firebase Cloud Messaging
FCM_PROJECT_ID="your-project-id"
FCM_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----"
FCM_CLIENT_EMAIL="firebase-adminsdk@..."

# ML Models
PEST_MODEL_PATH="./models/pest-detection"
SEGMENTATION_MODEL_PATH="./models/segmentation"
```

### Flutter Configuration

```dart
// lib/core/constants/api_endpoints.dart
class ApiEndpoints {
  static const String baseUrl = 'https://api.opa-app.com/v1';
  static const String wsUrl = 'wss://api.opa-app.com';
}

// Mapbox token (ios/Runner/Info.plist & android/app/src/main/AndroidManifest.xml)
<meta-data android:name="com.mapbox.token" android:value="YOUR_MAPBOX_TOKEN"/>
```

## 📱 Penggunaan

### User Roles

| Role | Akses |
|------|-------|
| **Admin** | Full access, kelola semua data, user management |
| **Supervisor** | Lihat laporan, verifikasi tugas, assign pekerja |
| **Field Worker** | Input data lapangan, lihat tugas sendiri |

### Aplikasi Flow

1. **Login** → Input nomor HP/Email → Terima OTP → Verifikasi
2. **Dashboard** → Lihat ringkasan produksi & tugas hari ini
3. **Peta Kebun** → Lihat blok, lokasi real-time, titik inspeksi
4. **Input Data** → Pencatatan panen/inspeksi/pemupukan
5. **Tugas** → Lihat & update status tugas
6. **Laporan** → Filter, preview, ekspor PDF/CSV/Excel

### Drone Integration Flow

1. **Plan Mission** → Tentukan area terbang dari peta
2. **Execute** → Terbang dengan DJI/autonomous drone
3. **Upload** → Upload gambar ke platform
4. **Process** → Orthomosaic, NDVI, 3D model generation
5. **Analyze** → AI pest detection, health scoring
6. **Act** → Work order otomatis untuk area bermasalah

## 📚 API Documentation

Setelah server berjalan, buka:

```
http://localhost:3000/api/docs
```

### Endpoints Utama

| Method | Endpoint | Deskripsi |
|--------|----------|-----------|
| POST | `/v1/auth/request-otp` | Request OTP |
| POST | `/v1/auth/verify-otp` | Verify OTP & login |
| GET | `/v1/harvests` | Get all harvests |
| POST | `/v1/harvests` | Create harvest |
| GET | `/v1/harvests/summary` | Production summary |
| GET | `/v1/blocks` | Get blocks by estate |
| GET | `/v1/tasks` | Get user tasks |
| POST | `/v1/inspections` | Create inspection |
| POST | `/v1/chat/messages` | Send message |
| GET | `/v1/drone/missions` | Get drone missions |
| POST | `/v1/drone/upload` | Upload drone imagery |
| POST | `/v1/ml/detect-pest` | Detect pest from image |

## 🧪 Testing

### Backend Tests

```bash
cd backend

# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Test coverage
npm run test:cov
```

### Frontend Tests

```bash
cd frontend

# Widget tests
flutter test

# Integration tests
flutter test integration_test

# Coverage
flutter test --coverage
```

### Load Testing

```bash
# Install k6
brew install k6  # macOS
# or download from https://k6.io

# Run load test
k6 run tests/load/harvest-load-test.js
```

## 🚀 Deployment

### Backend Deployment (Production)

```bash
# Build
npm run build

# Start with PM2
pm2 start dist/main.js --name opa-backend

# Or using Docker
docker build -t opa-backend .
docker run -p 3000:3000 --env-file .env opa-backend
```

### Flutter Deployment

```bash
# Android APK
flutter build apk --release --split-per-abi

# Android App Bundle
flutter build appbundle

# iOS (requires macOS)
flutter build ios --release

# Web (optional)
flutter build web --release
```

### CI/CD Pipeline (GitHub Actions)

```yaml
# .github/workflows/main.yml
name: CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter test
      - run: npm test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to Production
        run: echo "Deploying..."
```

## 🤝 Kontribusi

Kami sangat menyambut kontribusi! Silakan baca [CONTRIBUTING.md](CONTRIBUTING.md) untuk panduan lengkap.

### Cara Berkontribusi

1. **Fork** repository ini
2. **Clone** fork Anda: `git clone https://github.com/readloud/opa.git`
3. **Buat branch** fitur: `git checkout -b feature/amazing-feature`
4. **Commit** perubahan: `git commit -m 'Add amazing feature'`
5. **Push** ke branch: `git push origin feature/amazing-feature`
6. **Buka Pull Request**

### Development Guidelines

- Ikuti **Flutter style guide** (effective dart)
- Gunakan **conventional commits**:
  - `feat:` - Fitur baru
  - `fix:` - Bug fix
  - `docs:` - Dokumentasi
  - `style:` - Formatting
  - `refactor:` - Refactoring
  - `test:` - Testing
  - `chore:` - Maintenance
- Tulis **unit tests** untuk fitur baru
- Update **documentation** sesuai perubahan

## 📄 Lisensi

Distributed under the **MIT License**. See [LICENSE](LICENSE) for more information.

## 📧 Kontak

- **Project Lead**: [@readloud](https://github.com/readloud)
- **Email**: support@opa-app.com
- **Website**: https://opa-app.com
- **Issue Tracker**: https://github.com/readloud/opa/issues

## 🙏 Acknowledgements

- [Flutter Team](https://flutter.dev) - Framework mobile
- [NestJS Team](https://nestjs.com) - Backend framework
- [Mapbox](https://mapbox.com) - Peta & geolocation
- [TensorFlow](https://tensorflow.org) - Machine learning
- [OpenWeatherMap](https://openweathermap.org) - Weather data
- [DJI](https://dji.com) - Drone integration

---

**Made with ❤️ for Indonesian Palm Oil Industry**
