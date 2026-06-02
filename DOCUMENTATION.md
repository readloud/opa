# 1. API DOCUMENTATION (Swagger/OpenAPI Spec)

## 1.1. Swagger Configuration

### `backend/src/main.ts` - Swagger Setup

```typescript
import { NestFactory } from '@nestjs/core';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Swagger Configuration
  const config = new DocumentBuilder()
    .setTitle('Oil Palm Assistant API')
    .setDescription(`
      ## API Documentation for OPA (Oil Palm Assistant)
      
      ### Authentication
      Most endpoints require JWT authentication. Include the token in the Authorization header:
      \`Authorization: Bearer <your_jwt_token>\`
      
      ### Roles & Permissions
      - **Admin**: Full access to all endpoints
      - **Supervisor**: Read all data, write to assigned estates
      - **Field Worker**: Read/write only their assigned blocks
      
      ### Rate Limiting
      - 1000 requests per hour for authenticated users
      - 100 requests per hour for unauthenticated
      
      ### Response Format
      All responses follow JSON:API format
    `)
    .setVersion('3.0.0')
    .setContact('Support', 'https://opa-app.com/support', 'support@opa-app.com')
    .setLicense('MIT', 'https://opensource.org/licenses/MIT')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        name: 'JWT',
        description: 'Enter JWT token',
        in: 'header',
      },
      'JWT-auth',
    )
    .addTag('Auth', 'Authentication endpoints (OTP login)')
    .addTag('Harvest', 'Harvest management endpoints')
    .addTag('Inspection', 'Tree inspection endpoints')
    .addTag('Fertilization', 'Fertilization management')
    .addTag('Tasks', 'Task management for field workers')
    .addTag('Drone', 'Drone mission and imagery management')
    .addTag('Chat', 'Real-time messaging endpoints')
    .addTag('Weather', 'Weather data and predictions')
    .addTag('Reports', 'Report generation endpoints')
    .addTag('Admin', 'Administrative endpoints')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
      docExpansion: 'none',
      filter: true,
      showRequestDuration: true,
    },
    customSiteTitle: 'OPA API Documentation',
    customCss: `
      .swagger-ui .topbar { background-color: #2E7D32; }
      .swagger-ui .topbar .download-url-wrapper .select-label select { border-color: #2E7D32; }
      .swagger-ui .info .title { color: #2E7D32; }
    `,
  });

  await app.listen(3000);
}
bootstrap();
```

## 1.2. OpenAPI Specification (openapi.yaml)

```yaml
openapi: 3.0.3
info:
  title: Oil Palm Assistant API
  description: |
    ## Overview
    The OPA API provides comprehensive endpoints for managing oil palm plantations.
    
    ### Key Features
    - **Offline-First Sync**: Support for offline data collection
    - **Real-time Updates**: WebSocket for instant notifications
    - **Drone Integration**: Upload and process drone imagery
    - **AI Detection**: Pest detection from images
    - **Weather Integration**: Real-time weather and forecasts
    
    ### Data Models
    - **Estate**: Plantation entity
    - **Block**: Subdivision of estate
    - **Tree**: Individual palm tree with QR code tracking
    - **Harvest**: Production records
    - **Inspection**: Tree health inspections
    - **WorkOrder**: Automated maintenance tasks
    
  version: 3.0.0
  contact:
    name: OPA Support
    url: https://opa-app.com/support
    email: support@opa-app.com
  license:
    name: MIT
    url: https://opensource.org/licenses/MIT

servers:
  - url: https://api.opa-app.com/v1
    description: Production server
  - url: https://staging-api.opa-app.com/v1
    description: Staging server
  - url: http://localhost:3000/v1
    description: Local development

tags:
  - name: Auth
    description: Authentication and user management
  - name: Harvest
    description: Harvest recording and management
  - name: Inspection
    description: Tree inspection records
  - name: Fertilization
    description: Fertilization activities
  - name: Tasks
    description: Task assignment and tracking
  - name: Drone
    description: Drone mission management
  - name: Chat
    description: Real-time messaging
  - name: Weather
    description: Weather data and predictions
  - name: Reports
    description: Report generation
  - name: Admin
    description: Administrative functions

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
      description: JWT token obtained from /auth/verify-otp

  schemas:
    # ========== AUTH SCHEMAS ==========
    RequestOtpDto:
      type: object
      required:
        - identifier
      properties:
        identifier:
          type: string
          description: Email address or phone number (Indonesian format)
          example: "08123456789"
          pattern: '^(\+?62|0)[0-9]{9,13}$|^[^\s@]+@[^\s@]+\.[^\s@]+$'
    
    VerifyOtpDto:
      type: object
      required:
        - identifier
        - otpCode
      properties:
        identifier:
          type: string
          example: "08123456789"
        otpCode:
          type: string
          minLength: 6
          maxLength: 6
          pattern: '^[0-9]{6}$'
          example: "123456"
    
    AuthResponse:
      type: object
      properties:
        accessToken:
          type: string
          description: JWT token for API authentication
        user:
          $ref: '#/components/schemas/User'

    # ========== USER SCHEMAS ==========
    User:
      type: object
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
        email:
          type: string
          format: email
        phone:
          type: string
        role:
          type: string
          enum: [ADMIN, SUPERVISOR, FIELD_WORKER]
        estateId:
          type: string
          format: uuid
        blockId:
          type: string
          format: uuid
        createdAt:
          type: string
          format: date-time

    # ========== ESTATE SCHEMAS ==========
    Estate:
      type: object
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
          example: "PT Sawit Makmur Estate 1"
        location:
          type: string
          example: "Riau, Indonesia"
        totalArea:
          type: number
          format: float
          description: Area in hectares
          example: 1250.5
        geometry:
          type: object
          description: GeoJSON polygon of estate boundary
        createdAt:
          type: string
          format: date-time

    # ========== BLOCK SCHEMAS ==========
    Block:
      type: object
      properties:
        id:
          type: string
          format: uuid
        name:
          type: string
          example: "Blok A1"
        estateId:
          type: string
          format: uuid
        area:
          type: number
          format: float
          example: 25.5
        palmCount:
          type: integer
          example: 1250
        geometry:
          type: object
          description: GeoJSON polygon of block boundary
        createdAt:
          type: string
          format: date-time

    # ========== HARVEST SCHEMAS ==========
    CreateHarvestDto:
      type: object
      required:
        - blockId
        - tonase
        - harvestDate
      properties:
        blockId:
          type: string
          format: uuid
          description: ID of the block
        treeId:
          type: string
          format: uuid
          description: Optional specific tree ID
        tonase:
          type: number
          format: float
          minimum: 0
          example: 12.5
        harvestDate:
          type: string
          format: date
          example: "2024-01-15"
        photoUrl:
          type: string
          description: URL of harvest photo evidence
        notes:
          type: string
          maxLength: 500

    Harvest:
      type: object
      allOf:
        - $ref: '#/components/schemas/CreateHarvestDto'
        - type: object
          properties:
            id:
              type: string
              format: uuid
            createdBy:
              $ref: '#/components/schemas/User'
            createdAt:
              type: string
              format: date-time
            syncedAt:
              type: string
              format: date-time

    HarvestSummary:
      type: object
      properties:
        totalTonase:
          type: number
          format: float
        totalRecords:
          type: integer
        averagePerDay:
          type: number
          format: float
        dailyData:
          type: array
          items:
            type: object
            properties:
              date:
                type: string
                format: date
              value:
                type: number
        byBlock:
          type: array
          items:
            type: object
            properties:
              block:
                type: string
              value:
                type: number

    # ========== INSPECTION SCHEMAS ==========
    CreateInspectionDto:
      type: object
      required:
        - blockId
        - condition
      properties:
        blockId:
          type: string
          format: uuid
        treeId:
          type: string
          format: uuid
        condition:
          type: string
          enum: [HEALTHY, MILD_DAMAGE, SEVERE_DAMAGE, DEAD]
        notes:
          type: string
          maxLength: 500
        photoUrl:
          type: string
        latitude:
          type: number
          format: float
          minimum: -90
          maximum: 90
        longitude:
          type: number
          format: float
          minimum: -180
          maximum: 180

    Inspection:
      type: object
      allOf:
        - $ref: '#/components/schemas/CreateInspectionDto'
        - type: object
          properties:
            id:
              type: string
              format: uuid
            createdBy:
              $ref: '#/components/schemas/User'
            createdAt:
              type: string
              format: date-time

    # ========== TASK SCHEMAS ==========
    Task:
      type: object
      properties:
        id:
          type: string
          format: uuid
        title:
          type: string
        description:
          type: string
        type:
          type: string
          enum: [FERTILIZATION, PEST_CONTROL, INSPECTION, HARVEST, OTHER]
        blockId:
          type: string
          format: uuid
        assignedTo:
          $ref: '#/components/schemas/User'
        assignedBy:
          $ref: '#/components/schemas/User'
        dueDate:
          type: string
          format: date-time
        status:
          type: string
          enum: [PENDING, IN_PROGRESS, COMPLETED, CANCELLED]
        createdAt:
          type: string
          format: date-time

    # ========== DRONE SCHEMAS ==========
    DroneMission:
      type: object
      properties:
        id:
          type: string
          format: uuid
        estateId:
          type: string
          format: uuid
        flightDate:
          type: string
          format: date-time
        altitude:
          type: number
          format: float
        areaCovered:
          type: number
          format: float
        imageCount:
          type: integer
        orthomosaicUrl:
          type: string
        ndviUrl:
          type: string
        statistics:
          type: object
          properties:
            zones:
              type: object
            percentages:
              type: object
            overallHealthScore:
              type: number
        status:
          type: string
          enum: [PENDING, PROCESSING, PROCESSING_ORTHO, UPLOADED, COMPLETED, FAILED]

    PestDetectionResult:
      type: object
      properties:
        id:
          type: string
        detections:
          type: array
          items:
            type: object
            properties:
              pestName:
                type: string
              confidence:
                type: number
              severity:
                type: string
        recommendation:
          type: object
        confidence:
          type: number

    # ========== CHAT SCHEMAS ==========
    Message:
      type: object
      properties:
        id:
          type: string
          format: uuid
        chatId:
          type: string
          format: uuid
        senderId:
          type: string
          format: uuid
        content:
          type: string
        type:
          type: string
          enum: [TEXT, IMAGE, LOCATION, FILE]
        mediaUrl:
          type: string
        createdAt:
          type: string
          format: date-time

    # ========== WEATHER SCHEMAS ==========
    WeatherData:
      type: object
      properties:
        temperature:
          type: number
          format: float
        humidity:
          type: integer
        rainfall:
          type: number
          format: float
        windSpeed:
          type: number
          format: float
        condition:
          type: string
        timestamp:
          type: string
          format: date-time

    YieldPrediction:
      type: object
      properties:
        blockId:
          type: string
        blockName:
          type: string
        predictedYield:
          type: number
        confidence:
          type: number
        weatherImpact:
          type: number

    # ========== WORK ORDER SCHEMAS ==========
    WorkOrder:
      type: object
      properties:
        id:
          type: string
          format: uuid
        estateId:
          type: string
          format: uuid
        type:
          type: string
          enum: [PEST_CONTROL, FERTILIZATION, IRRIGATION, REPLANTING, INSPECTION]
        title:
          type: string
        description:
          type: string
        priority:
          type: string
          enum: [URGENT, HIGH, MEDIUM, LOW]
        status:
          type: string
          enum: [PENDING, APPROVED, IN_PROGRESS, COMPLETED, CANCELLED]
        estimatedCost:
          type: number
        dueDate:
          type: string
          format: date-time

    # ========== RESPONSE SCHEMAS ==========
    ApiResponse:
      type: object
      properties:
        success:
          type: boolean
        message:
          type: string
        data:
          type: object
        error:
          type: string
        timestamp:
          type: string
          format: date-time

    ErrorResponse:
      type: object
      properties:
        statusCode:
          type: integer
        message:
          type: string
        error:
          type: string
        timestamp:
          type: string
          format: date-time
        path:
          type: string

# ========== API PATHS ==========
paths:
  # ========== AUTH ENDPOINTS ==========
  /auth/request-otp:
    post:
      tags:
        - Auth
      summary: Request OTP verification code
      description: Send OTP via SMS or email for authentication
      operationId: requestOtp
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/RequestOtpDto'
      responses:
        '200':
          description: OTP sent successfully
          content:
            application/json:
              schema:
                type: object
                properties:
                  message:
                    type: string
                    example: "OTP sent successfully"
        '400':
          description: Invalid identifier format
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
        '500':
          description: SMS/Email service error

  /auth/verify-otp:
    post:
      tags:
        - Auth
      summary: Verify OTP and login
      description: Verify the OTP code and receive JWT token
      operationId: verifyOtp
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/VerifyOtpDto'
      responses:
        '200':
          description: Authentication successful
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/AuthResponse'
        '401':
          description: Invalid OTP
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'

  # ========== HARVEST ENDPOINTS ==========
  /harvests:
    get:
      tags:
        - Harvest
      summary: Get all harvests
      description: Retrieve harvest records with optional filters
      security:
        - bearerAuth: []
      parameters:
        - name: startDate
          in: query
          schema:
            type: string
            format: date
          description: Filter by start date
        - name: endDate
          in: query
          schema:
            type: string
            format: date
          description: Filter by end date
        - name: blockId
          in: query
          schema:
            type: string
            format: uuid
          description: Filter by block ID
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
      responses:
        '200':
          description: List of harvests
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Harvest'
        '401':
          description: Unauthorized
        '403':
          description: Forbidden - insufficient permissions

    post:
      tags:
        - Harvest
      summary: Create harvest record
      description: Record a new harvest entry (works offline)
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateHarvestDto'
      responses:
        '201':
          description: Harvest created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Harvest'
        '400':
          description: Validation error
        '404':
          description: Block not found

  /harvests/summary:
    get:
      tags:
        - Harvest
      summary: Get harvest summary
      description: Get aggregated production statistics
      security:
        - bearerAuth: []
      parameters:
        - name: startDate
          in: query
          required: true
          schema:
            type: string
            format: date
        - name: endDate
          in: query
          required: true
          schema:
            type: string
            format: date
      responses:
        '200':
          description: Production summary
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HarvestSummary'

  # ========== INSPECTION ENDPOINTS ==========
  /inspections:
    post:
      tags:
        - Inspection
      summary: Create inspection record
      description: Record tree inspection results
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateInspectionDto'
      responses:
        '201':
          description: Inspection created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Inspection'

    get:
      tags:
        - Inspection
      summary: Get inspections
      description: Retrieve inspection records
      security:
        - bearerAuth: []
      parameters:
        - name: blockId
          in: query
          schema:
            type: string
            format: uuid
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
      responses:
        '200':
          description: List of inspections

  # ========== TASK ENDPOINTS ==========
  /tasks:
    get:
      tags:
        - Tasks
      summary: Get user tasks
      description: Retrieve tasks assigned to current user
      security:
        - bearerAuth: []
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [PENDING, IN_PROGRESS, COMPLETED]
        - name: dueDate
          in: query
          schema:
            type: string
            format: date
      responses:
        '200':
          description: List of tasks
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Task'

  /tasks/{id}/status:
    patch:
      tags:
        - Tasks
      summary: Update task status
      description: Mark task as complete or update status
      security:
        - bearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              properties:
                status:
                  type: string
                  enum: [PENDING, IN_PROGRESS, COMPLETED, CANCELLED]
                notes:
                  type: string
      responses:
        '200':
          description: Task updated

  # ========== DRONE ENDPOINTS ==========
  /drone/upload:
    post:
      tags:
        - Drone
      summary: Upload drone imagery
      description: Upload multiple images from drone mission
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                images:
                  type: array
                  items:
                    type: string
                    format: binary
                flightData:
                  type: string
                  format: json
      responses:
        '202':
          description: Images accepted for processing
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/DroneMission'

  /drone/missions:
    get:
      tags:
        - Drone
      summary: Get drone missions
      description: Retrieve all drone missions for estate
      security:
        - bearerAuth: []
      parameters:
        - name: limit
          in: query
          schema:
            type: integer
            default: 10
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
      responses:
        '200':
          description: List of missions
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/DroneMission'

  /drone/missions/{id}/report:
    get:
      tags:
        - Drone
      summary: Get mission report
      description: Get detailed analysis report from drone mission
      security:
        - bearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Mission report
          content:
            application/json:
              schema:
                type: object
                properties:
                  healthSummary:
                    type: object
                  recommendations:
                    type: array
                  pestDetections:
                    type: array

  # ========== ML PEST DETECTION ==========
  /ml/detect-pest:
    post:
      tags:
        - ML
      summary: Detect pest from image
      description: Upload image for AI-based pest detection
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                image:
                  type: string
                  format: binary
      responses:
        '200':
          description: Pest detection results
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PestDetectionResult'

  # ========== CHAT ENDPOINTS ==========
  /chat/my-chats:
    get:
      tags:
        - Chat
      summary: Get user's chats
      description: Retrieve all chat conversations for current user
      security:
        - bearerAuth: []
      responses:
        '200':
          description: List of chats
          content:
            application/json:
              schema:
                type: array
                items:
                  type: object
                  properties:
                    id:
                      type: string
                    name:
                      type: string
                    lastMessage:
                      type: string
                    unreadCount:
                      type: integer

  /chat/{chatId}/messages:
    get:
      tags:
        - Chat
      summary: Get chat messages
      description: Retrieve messages from specific chat
      security:
        - bearerAuth: []
      parameters:
        - name: chatId
          in: path
          required: true
          schema:
            type: string
            format: uuid
        - name: limit
          in: query
          schema:
            type: integer
            default: 50
        - name: offset
          in: query
          schema:
            type: integer
            default: 0
      responses:
        '200':
          description: List of messages
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Message'

  # ========== WEATHER ENDPOINTS ==========
  /weather/forecast:
    get:
      tags:
        - Weather
      summary: Get weather forecast
      description: Get 7-day weather forecast for estate
      security:
        - bearerAuth: []
      parameters:
        - name: lat
          in: query
          required: true
          schema:
            type: number
            format: float
        - name: lon
          in: query
          required: true
          schema:
            type: number
            format: float
      responses:
        '200':
          description: Weather forecast
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/WeatherData'

  /weather/predict-yield:
    get:
      tags:
        - Weather
      summary: Predict harvest yield
      description: Get AI-based yield predictions using weather data
      security:
        - bearerAuth: []
      parameters:
        - name: blockId
          in: query
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Yield predictions
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/YieldPrediction'

  # ========== REPORT ENDPOINTS ==========
  /reports/harvest:
    get:
      tags:
        - Reports
      summary: Export harvest report
      description: Generate and download harvest report
      security:
        - bearerAuth: []
      parameters:
        - name: startDate
          in: query
          required: true
          schema:
            type: string
            format: date
        - name: endDate
          in: query
          required: true
          schema:
            type: string
            format: date
        - name: format
          in: query
          schema:
            type: string
            enum: [pdf, csv, excel]
            default: pdf
      responses:
        '200':
          description: Report file
          content:
            application/pdf:
              schema:
                type: string
                format: binary
            text/csv:
              schema:
                type: string
            application/vnd.openxmlformats-officedocument.spreadsheetml.sheet:
              schema:
                type: string
                format: binary

  # ========== ADMIN ENDPOINTS ==========
  /admin/dashboard:
    get:
      tags:
        - Admin
      summary: Super admin dashboard
      description: Get multi-estate dashboard data (Admin only)
      security:
        - bearerAuth: []
      responses:
        '200':
          description: Dashboard data
          content:
            application/json:
              schema:
                type: object
                properties:
                  summary:
                    type: object
                  estates:
                    type: array
                  alerts:
                    type: array
                  topPerformers:
                    type: array
        '403':
          description: Admin role required

  /admin/estates/{id}:
    get:
      tags:
        - Admin
      summary: Get estate details
      description: Get detailed information about specific estate (Admin only)
      security:
        - bearerAuth: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Estate details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Estate'
```

---

# 2. USER MANUAL FOR END USERS

## 2.1. Getting Started Guide

```markdown
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

---

## Troubleshooting

### Common Issues

#### Can't Login
- Check internet connection
- Verify phone number/email
- Wait 60 seconds before retry
- Contact supervisor if persists

#### App Crashes
- Update to latest version
- Clear app cache (Settings → Apps → OPA → Clear Cache)
- Restart device
- Reinstall if needed

#### Sync Failed
- Check storage space (need 500MB+)
- Ensure stable internet
- Manual sync from Settings
- Contact support with error log

#### Map Not Loading
- Check internet (for online mode)
- Download offline maps first
- Update Mapbox token
- Reinstall map data

#### Photos Not Uploading
- Check file size (<10MB recommended)
- Compress large images
- Retry upload from queue
- Clear image cache

### Error Messages

| Error | Solution |
|-------|----------|
| "OTP Expired" | Request new code |
| "Invalid Token" | Logout and login again |
| "Storage Full" | Clear cache, delete old data |
| "Network Error" | Check internet, retry later |
| "Permission Denied" | Grant permissions in settings |

### Getting Help

1. **In-App Support**:
   - Settings → Help Center
   - Live chat (business hours)
   - Submit ticket

2. **Email Support**: support@opa-app.com
3. **Phone Support**: +62 21 1234 5678
4. **Knowledge Base**: https://support.opa-app.com

---

## FAQs

### General

**Q: Is the app free?**  
A: Yes for field workers. Estate owners pay subscription based on size.

**Q: Can I use offline?**  
A: Yes, most features work offline. Sync when online.

**Q: How secure is my data?**  
A: End-to-end encryption, stored in Indonesia, GDPR compliant.

**Q: Multiple languages?**  
A: Bahasa Indonesia and English supported.

### Technical

**Q: Battery usage?**  
A: ~10-15% per hour with GPS. Use power saving mode.

**Q: Storage requirements?**  
A: 500MB base + drone imagery cache (configurable).

**Q: Supported devices?**  
A: Android 8+, iOS 13+, 3GB RAM minimum.

**Q: Updates frequency?**  
A: Monthly feature updates, weekly bug fixes.

### Field Operations

**Q: How to record harvest weight?**  
A: Enter in metric tons (1 ton = 1000 kg = ~150 FFB fruits).

**Q: What if tree has no QR code?**  
A: Enter manually or scan block QR code.

**Q: Can multiple workers use same device?**  
A: Yes, just logout/login with different accounts.

**Q: How accurate is pest detection?**  
A: 85-95% accuracy for common pests. Always verify.

### Drone Operations

**Q: Which drones are compatible?**  
A: DJI Phantom 4, Mavic 2/3, Autel Evo II.

**Q: How large area per mission?**  
A: Up to 100 hectares per battery (30 min flight).

**Q: Processing time for orthomosaic?**  
A: 30-60 minutes for 100 images.

**Q: Legal requirements?**  
A: Drone license required for >250g. Follow local regulations.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0.0 | Jan 2024 | AI pest detection, drone integration, offline maps |
| 2.5.0 | Oct 2023 | Real-time chat, weather integration |
| 2.0.0 | Jun 2023 | Offline-first architecture |
| 1.0.0 | Jan 2023 | Initial release |