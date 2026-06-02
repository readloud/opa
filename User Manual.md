# Oil Palm Assistant User Manual

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Login & Authentication](#login--authentication)
4. [Dashboard Overview](#dashboard-overview)
5. [Managing Harvest Records](#managing-harvest-records)
6. [Tree Inspections](#tree-inspections)
7. [Fertilization Management](#fertilization-management)
8. [Task Management](#task-management)
9. [Drone Mission Management](#drone-mission-management)
10. [Chat & Communication](#chat--communication)
11. [Weather & Predictions](#weather--predictions)
12. [Reports & Analytics](#reports--analytics)
13. [Offline Mode](#offline-mode)
14. [Troubleshooting](#troubleshooting)
15. [FAQs](#faqs)

---

## Introduction

### What is Oil Palm Assistant?

Oil Palm Assistant (OPA) is a comprehensive mobile application designed specifically for oil palm plantation management. It helps digitize field operations, track production, monitor tree health, and generate insightful reports.

### Key Benefits

- **Offline-First**: Continue working without internet connection
- **Real-time Sync**: Automatic synchronization when online
- **AI-Powered**: Pest detection and yield prediction
- **Drone Integration**: Aerial monitoring and analysis
- **Team Collaboration**: Real-time chat and task assignment

### System Requirements

| Platform | Minimum Requirements |
|----------|---------------------|
| **Android** | Android 8.0 (API 26), 3GB RAM |
| **iOS** | iOS 13.0, iPhone 8 or newer |
| **Storage** | 500MB free space (caches increase with drone data) |
| **Internet** | Required for initial setup and sync |

---

## Getting Started

### Installation

#### Android
1. Open **Google Play Store**
2. Search for **"Oil Palm Assistant"**
3. Tap **Install**
4. Open the app after installation

#### iOS
1. Open **App Store**
2. Search for **"Oil Palm Assistant"**
3. Tap **Get** → **Install**
4. Open the app

### First Launch

When you open the app for the first time:

1. **Permissions Request**:
   - **Location**: Required for maps and field recording
   - **Camera**: For taking photos of trees and harvest
   - **Storage**: For saving offline data
   - **Notifications**: For task reminders

2. **Language Selection**:
   - Choose **Bahasa Indonesia** or **English**

3. **Initial Sync**:
   - The app will download estate data (requires internet)

---

## Login & Authentication

### Login Process

![Login Screen](images/login.png)

1. Enter your **registered phone number** or **email**
2. Tap **"Kirim OTP"**
3. Check your SMS or email for 6-digit code
4. Enter the OTP code
5. You're automatically logged in

### Important Notes

- OTP expires in **5 minutes**
- You can request a new code after 60 seconds
- Each login session lasts **7 days**
- For security, logout when using shared devices

### First Time Login

If you're a new user:
- The system automatically creates your account
- Your supervisor will assign your estate/block
- You'll receive a welcome notification

### Logout

1. Go to **Profile** tab
2. Scroll down to **"Logout"**
3. Confirm logout

---

## Dashboard Overview

### Main Dashboard

![Dashboard](images/dashboard.png)

#### Key Metrics Cards

| Metric | Description |
|--------|-------------|
| **Total Produksi** | Today's harvest in tons |
| **Rata-rata Harian** | Average production for selected period |
| **Inspeksi** | Number of inspections this month |
| **Tugas Selesai** | Completed tasks percentage |

#### Charts

1. **Produksi Harian**: Bar chart showing daily production
2. **Kondisi Pohon**: Pie chart of tree health status
3. **Tren Produksi**: Line chart of monthly trends

#### Quick Actions

- **+ Tambah Inspeksi**: Start new tree inspection
- **+ Tambah Panen**: Record harvest data
- **View All Tasks**: See assigned tasks

### Real-time Stats

The top section shows:
- **Today's Production**: Live updates as data entered
- **Today's Tasks**: Pending tasks due today
- **Pending Tasks**: Overdue tasks requiring attention

---

## Managing Harvest Records

### Recording a Harvest

1. Tap **"Tambah Panen"** on dashboard
2. Select **Block** from dropdown
3. Enter **Tonase** (weight in tons)
4. Select **Harvest Date** (default: today)
5. **Take Photo** (optional but recommended)
6. Add **Notes** (optional)
7. Tap **"Simpan"**

### Harvest Form Fields

| Field | Required | Description |
|-------|----------|-------------|
| Blok | Yes | Select plantation block |
| Tonase | Yes | Weight in metric tons (1 ton = 1000kg) |
| Tanggal | Yes | Harvest date |
| Foto | No | Photo evidence of harvest |
| Catatan | No | Additional notes |

### Viewing Harvest History

1. Go to **Reports** tab
2. Select **"Panen"** as report type
3. Choose date range
4. Tap **"Lihat"**

### Editing a Harvest Record

1. Go to **Harvest List**
2. Tap on record to edit
3. Modify fields
4. Tap **"Update"**

**Note**: Only supervisor/admin can edit records

---

## Tree Inspections

### Starting an Inspection

1. Tap **"Tambah Inspeksi"** on dashboard
2. Select **Block**
3. Enter **Tree ID** (if scanning QR code)
4. Select **Condition**:
   - 🟢 Sehat (Healthy)
   - 🟠 Rusak Ringan (Mild Damage)
   - 🔴 Rusak Berat (Severe Damage)
   - ⚫ Mati (Dead)
5. **Take Photo** of affected area
6. Add **Notes**
7. Tap **"Simpan"**

### QR Code Scanning

1. Tap **QR Scanner** icon
2. Point camera at tree QR code
3. Tree information auto-fills
4. Complete inspection form
5. Submit

### Pest Detection AI

When you take a photo:
1. AI analyzes the image
2. Detects pest type (if any)
3. Shows confidence percentage
4. Provides treatment recommendations

![Pest Detection](images/pest-detection.png)

### Inspection History

1. Go to **Block Details** on map
2. Scroll to **"Riwayat Inspeksi"**
3. See all inspections for that block

---

## Fertilization Management

### Recording Fertilization

1. Go to **Fertilization** tab
2. Tap **"Tambah Pemupukan"**
3. Select **Block**
4. Choose **Fertilizer Type**:
   - Urea
   - SP-36
   - KCl
   - NPK
   - Organic
5. Enter **Quantity** (kg/ha)
6. Select **Application Date**
7. Add **Notes**
8. Tap **"Simpan"**

### Viewing Fertilization Schedule

1. Go to **Fertilization** tab
2. See upcoming schedule in calendar view
3. Red markers indicate overdue applications
4. Green markers indicate completed

### Fertilizer Calculator

The app helps calculate required fertilizer:
1. Enter block area (hectares)
2. Select fertilizer type
3. Enter recommended dosage
4. App calculates total needed

---

## Task Management

### Viewing Tasks

1. Go to **Tasks** tab
2. Filter by:
   - **All Tasks**
   - **Pending**
   - **Completed**
   - **Overdue**

### Task Details

Each task shows:
- Title and description
- Assigned block/location
- Due date and time
- Priority (Urgent/High/Medium/Low)
- Status

### Updating Task Status

1. Tap on task
2. Select new status:
   - **Pending** (not started)
   - **In Progress** (working on it)
   - **Completed** (finished)
   - **Cancelled** (won't be done)
3. Add completion notes
4. Tap **"Update"**

### Creating Tasks (Supervisor/Admin)

1. Go to **Tasks** tab
2. Tap **"+"** button
3. Fill in task details
4. Assign to user
5. Set due date
6. Tap **"Create"**

---

## Drone Mission Management

### Overview

Drone missions provide aerial monitoring:
- Orthomosaic maps (stitched images)
- NDVI vegetation health maps
- 3D terrain models
- Pest detection at scale

### Starting a Drone Mission

1. Go to **Drone** tab
2. Tap **"Misi Baru"**
3. Select flight area on map
4. Set flight parameters:
   - Altitude (50-120m)
   - Speed (5-10 m/s)
   - Overlap (70-80%)
5. Choose **Thermal Mode** (if available)
6. Tap **"Start Mission"**

### Uploading Drone Images

After flight:
1. Connect drone to device
2. Tap **"Upload Images"**
3. Select images from gallery/SD card
4. Add flight metadata
5. Tap **"Upload"**

### Viewing Mission Results

1. Go to **Drone Missions** list
2. Tap on completed mission
3. View:
   - Orthomosaic map
   - NDVI health map
   - Pest detection overlay
   - Health statistics

### Understanding NDVI Map

| Color | Meaning |
|-------|---------|
| 🟢 Dark Green | Very healthy vegetation |
| 🟢 Light Green | Healthy vegetation |
| 🟡 Yellow | Moderate stress |
| 🟠 Orange | Severe stress |
| 🔴 Red | Dead/unhealthy |

### AI Pest Detection from Drone

The system automatically:
1. Analyzes orthomosaic
2. Detects pest hotspots
3. Calculates affected area
4. Generates work orders

---

## Chat & Communication

### Accessing Chat

1. Tap **Chat** icon in bottom navigation
2. See list of conversations:
   - Direct messages
   - Group chats (by block/estate)
   - Supervisor broadcast

### Sending Messages

1. Open a chat
2. Type message in text field
3. Tap **send** icon
4. **Rich Features**:
   - 📷 Send photos
   - 📍 Share location
   - 📎 Attach files
   - 👍 React to messages

### Group Chats

- **Block Groups**: All workers in same block
- **Estate Groups**: All estate personnel
- **Emergency Group**: Critical alerts only

### Sharing Location

1. Tap **attach** icon
2. Select **"Bagikan Lokasi"**
3. Confirm sharing
4. Recipients can open in map

---

## Weather & Predictions

### Current Weather

1. Go to **Weather** tab
2. See real-time conditions:
   - Temperature
   - Humidity
   - Wind speed
   - Rainfall
   - Forecast

### 7-Day Forecast

- Daily temperature (min/max)
- Rain probability
- Wind conditions
- Recommendations for fieldwork

### Yield Predictions

AI predicts harvest yield based on:
- Historical production data
- Weather forecast
- Tree health status
- Fertilization schedule

### Weather Alerts

Automatic alerts for:
- Heavy rain (>50mm)
- Extreme heat (>35°C)
- Strong winds (>30 km/h)
- Drought conditions

### Optimal Work Times

The app suggests best times for:
- Fertilization (based on rain forecast)
- Harvesting (dry conditions)
- Pest control (wind speed)
- Drone flights (clear sky, low wind)

---

## Reports & Analytics

### Generating Reports

1. Go to **Reports** tab
2. Select report type:
   - **Panen** (Harvest)
   - **Inspeksi** (Inspection)
   - **Pemupukan** (Fertilization)
   - **Lengkap** (Complete)
3. Choose date range
4. Select format:
   - **PDF** (professional report)
   - **CSV** (spreadsheet data)
   - **Excel** (formatted)

### Report Contents

**Harvest Report** includes:
- Total production (tons)
- Daily breakdown
- Per-block summary
- Production trends chart
- Comparison with previous period

**Inspection Report** includes:
- Total inspections
- Condition distribution
- Pest detection summary
- Treatment recommendations

### Exporting Reports

1. After generating report
2. Tap **"Ekspor"**
3. Choose save location
4. Report downloads to device
5. Can be shared via email/WhatsApp

### Scheduling Reports

Supervisors can schedule:
- Weekly summaries (every Monday)
- Monthly reports (1st of month)
- Quarterly analytics
- Automatic email delivery

---

## Offline Mode

### How Offline Works

- All data saved to **local database**
- Continue working without internet
- Changes queued for sync
- Automatic sync when online

### Offline Capabilities

| Feature | Offline Support |
|---------|-----------------|
| View maps | ✅ (cached) |
| Record harvest | ✅ |
| Tree inspections | ✅ |
| Take photos | ✅ (stored locally) |
| Chat | ❌ (needs connection) |
| Weather | ❌ |
| Drone upload | ❌ |

### Syncing Data

**Automatic Sync**:
- When internet reconnects
- Background sync every hour
- After recording 10+ items

**Manual Sync**:
1. Pull down to refresh
2. Tap **Sync** button
3. See sync progress
4. Conflict resolution shown

### Conflict Resolution

If same data edited offline and online:
- **Last-write-wins** policy
- Both versions kept in history
- Supervisor notified of conflict
- Manual resolution if needed

### Offline Map Caching

1. Go to **Map** tab
2. Zoom to desired area
3. Tap **"Download Offline"**
4. Select area size
5. Wait for download
6. Map usable without internet