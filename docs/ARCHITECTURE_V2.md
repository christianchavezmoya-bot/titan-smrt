# Titan Super Fitness App - Architecture v2.0

## 🧱 HIGH-LEVEL ARCHITECTURE OVERVIEW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              CLIENT LAYER                                    │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  Flutter App (Primary) + SwiftUI/iOS + Kotlin/Android (Native Modules) ││
│  │  - Offline-First SQLite/Realm                                           ││
│  │  - WASM for on-device ML                                                ││
│  │  - BLE + MQTT for IoT                                                   ││
│  └─────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              EDGE LAYER                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ API Gateway  │  │    CDN       │  │    WAF       │  │ Load Balancer│    │
│  │ (Kong/AWS)   │  │(CloudFront)  │  │  (Security)  │  │   (nginx)    │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
│  Protocols: GraphQL (primary), REST (webhooks), gRPC (inter-service)        │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MICROSERVICES LAYER                                  │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌──────────────┐ │
│  │  user-auth     │ │workout-content │ │tracking-telemetry│ │social-comm  │ │
│  │  (Go)          │ │(Java/Spring)   │ │(Go + Kafka)    │ │(Node.js)     │ │
│  │  PostgreSQL    │ │MongoDB + S3    │ │TimescaleDB     │ │Cassandra     │ │
│  └────────────────┘ └────────────────┘ └────────────────┘ └──────────────┘ │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌──────────────┐ │
│  │   commerce     │ │billing-sub     │ │   ai-coach     │ │  analytics   │ │
│  │  (Java/Spring) │ │(Python/FastAPI)│ │(Python/PyTorch)│ │(ClickHouse)  │ │
│  │  MySQL + Redis │ │PostgreSQL+Stripe│ │Triton+CoreML  │ │Airflow+dbt   │ │
│  └────────────────┘ └────────────────┘ └────────────────┘ └──────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA LAYER                                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ PostgreSQL   │ │ TimescaleDB  │ │   Redis      │ │Elasticsearch │       │
│  │ (Relational) │ │ (Time-Series)│ │  (Cache)     │ │  (Search)    │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │  MongoDB     │ │  Cassandra   │ │  ClickHouse  │ │   S3/OSS     │       │
│  │  (Document)  │ │(Social Feeds)│ │ (Analytics)  │ │  (Objects)   │       │
│  └──────────────┘ └──────────────┘ └──────────────┘ └──────────────┘       │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        EVENT STREAMING                                       │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │                    Apache Kafka (Event Broker)                        │   │
│  │  Topics: workout.started | telemetry.batch | social.post | payment   │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │              Flink / Kafka Streams (Real-time Processing)             │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📱 DETAILED UI/UX ARCHITECTURE

### 1. Navigation & Information Architecture

**Bottom Tab Navigation (5 core sections):**

| Tab | Purpose | Key Features |
|-----|---------|--------------|
| **Home** | Personalized dashboard | Daily goal, quick start, AI coach preview, progress rings |
| **Explore** | Community & Discovery | Feed, challenges, tutorials, leaderboards, live classes |
| **Workout** | Active session | Equipment pairing, real-time metrics, post-session summary |
| **Shop** | E-commerce | Subscriptions, equipment, apparel, AR try-on |
| **Me** | Profile & Settings | Stats, achievements, devices, nutrition, support |

### 2. Screen-Level Breakdown

| Screen | Key UI Components | State & Data Flow |
|--------|-------------------|-------------------|
| Home | Dynamic header, progress rings, AI coach card, recommended workouts, quick actions, daily streak | Local cache + GraphQL subscription; prefetches next workout metadata |
| Explore/Community | Infinite scroll feed, video cards, user posts, challenge banners, filters, comment sheets | Zustand store; cursor pagination; CDN-cached thumbnails; WebSocket real-time |
| Active Workout | Full-screen video, metric overlays (HR, calories, reps), pause/resume, voice cues, form feedback | State machine (Idle → Warmup → Active → Cooldown → Done); local telemetry queue |
| Workout Summary | Performance breakdown, PRs, shareable cards, recovery tips, upsell | Aggregated locally → POST to tracking → triggers social feed update |
| Shop/E-commerce | Product grid, filtering, AR preview, cart drawer, checkout flow | GraphQL + REST hybrid; payment SDK; Redis inventory cache |
| Me/Profile | Avatar, badges, subscription status, connected devices, nutrition log | OAuth2 sync; BLE/MQTT device pairing; encrypted sensitive data |

### 3. UI Component System

```
lib/
├── design_tokens/           # Style Dictionary
│   ├── colors.dart
│   ├── typography.dart
│   ├── spacing.dart
│   └── motion_curves.dart
├── components/
│   ├── atoms/               # Basic building blocks
│   │   ├── TitanButton.dart
│   │   ├── TitanIcon.dart
│   │   └── TitanText.dart
│   ├── molecules/           # Composed components
│   │   ├── ProgressRing.dart
│   │   ├── MetricTicker.dart
│   │   └── SwipeableCard.dart
│   ├── organisms/           # Complex sections
│   │   ├── WorkoutCard.dart
│   │   ├── AICoachPanel.dart
│   │   └── LeaderboardTable.dart
│   └── templates/           # Page layouts
│       ├── HomeTemplate.dart
│       └── WorkoutTemplate.dart
```

### 4. State Management Architecture

```dart
// Global State (Zustand-equivalent using Riverpod/Bloc)
// - Auth state
// - User preferences
// - Cart state
// - Feature flags

// Local State (State Machine for Workout)
enum WorkoutState { idle, warmup, active, cooldown, done }

class WorkoutStateMachine {
  WorkoutState state = WorkoutState.idle;
  LocalTelemetryQueue telemetryQueue;
  BluetoothSync bleSync;
  
  void transition(WorkoutEvent event) {
    // State transitions with side effects
  }
}
```

### 5. Performance Optimizations

- **List Virtualization:** Flutter ListView.builder with recycled cells
- **Image Loading:** CachedNetworkImage + progressive JPEG/WebP
- **Video:** Adaptive bitrate HLS with chunk prefetching
- **Background Sync:** Exponential backoff + conflict resolution
- **On-device ML:** TensorFlow Lite / CoreML for pose estimation

---

## ⚙️ DETAILED BACKEND ARCHITECTURE

### 1. Microservices Matrix

| Service | Responsibility | Tech Stack | Database |
|---------|---------------|------------|----------|
| user-auth | Registration, SSO, biometric, device pairing | Go, Keycloak | PostgreSQL |
| workout-content | Exercise library, video metadata, plans, DRM | Java/Spring | MongoDB, S3 |
| tracking-telemetry | GPS, HR, rep counting, IoT sync | Go, Kafka | TimescaleDB |
| social-community | Feeds, posts, comments, challenges | Node.js/NestJS | Cassandra |
| commerce | Catalog, cart, checkout, inventory | Java/Spring | MySQL, Redis |
| billing-subscription | Entitlements, trials, renewals | Python/FastAPI | PostgreSQL |
| ai-coach | Pose estimation, form feedback, LLM coaching | Python, PyTorch | Triton, S3 |
| analytics | Events, funnels, A/B, BI dashboards | Go, ClickHouse | ClickHouse |

### 2. API Gateway Configuration

```yaml
# Kong/inngres configuration
routes:
  - path: /api/v1/auth/*
    service: user-auth
  - path: /api/v1/workouts/*
    service: workout-content
  - path: /api/v1/telemetry/*
    service: tracking-telemetry
  - path: /api/v1/social/*
    service: social-community
  - path: /api/v1/shop/*
    service: commerce
  - path: /api/v1/billing/*
    service: billing-subscription
  - path: /api/v1/ai/*
    service: ai-coach
  - path: /api/v1/analytics/*
    service: analytics

plugins:
  - name: jwt
  - name: rate-limiting
    config:
      minute: 100
  - name: cors
  - name: request-transformer
```

### 3. GraphQL Schema Structure

```graphql
type Query {
  me: User!
  workout(id: ID!): Workout
  recommendedWorkouts(limit: Int): [Workout!]!
  leaderboard(challengeId: ID!): Leaderboard!
  searchExercises(query: String!, filter: ExerciseFilter): [Exercise!]!
}

type Mutation {
  startWorkout(input: StartWorkoutInput!): WorkoutSession!
  logTelemetry(input: TelemetryBatchInput!): TelemetryResult!
  completeWorkout(id: ID!): WorkoutSummary!
  updateProfile(input: ProfileInput!): User!
}

type Subscription {
  workoutMetrics(sessionId: ID!): WorkoutMetrics!
  leaderboardUpdates(challengeId: ID!): LeaderboardEntry!
  aiCoachFeedback(sessionId: ID!): AIFeedback!
}
```

---

## 🔄 DATA FLOW EXAMPLE (Workout Session)

```
1. User taps Start
   └─→ App loads session state machine
   └─→ Prefetches video chunks from CDN
   
2. Sensors/GPS/Bluetooth stream data
   └─→ Local SQLite queue
   └─→ WASM metric engine (on-device processing)
   
3. Every 15 seconds:
   └─→ Batch telemetry → HTTPS POST to tracking-telemetry
   └─→ Kafka topic: telemetry.batch
   └─→ TimescaleDB storage
   
4. AI Service consumes stream
   └─→ Pushes form corrections via WebSocket
   └─→ UI overlay updates
   
5. On Finish:
   └─→ App aggregates summary
   └─→ Uploads to tracking service
   └─→ Triggers workout.completed event
   
6. Event Cascade:
   └─→ Social feed update
   └─→ Streak check
   └─→ Analytics pipeline
   └─→ Recommendation refresh
   └─→ Notification dispatch
   
7. Background sync:
   └─→ Conflict resolution
   └─→ Cache update
   └─→ Prefetch next session
```

---

## 🛡️ SECURITY & COMPLIANCE

### Security Measures
- **Zero-trust network:** mTLS for all inter-service communication
- **Secret management:** HashiCorp Vault with automatic rotation
- **PII encryption:** AES-256 at rest, TLS 1.3 in transit
- **Audit logging:** All sensitive operations logged with tamper-proof storage

### Compliance Framework
- **GDPR (EU):** Right to erasure, data portability, consent management
- **PIPL (China):** Real-name auth, cross-border transfer restrictions
- **COPPA (Youth):** Age verification, parental consent
- **HIPAA (Health):** PHI handling for health data

---

## 🧰 2026 TECH STACK

| Layer | Technologies |
|-------|-------------|
| **Client** | Flutter 3.22+, SwiftUI, Jetpack Compose, WebAssembly, Hermes |
| **Backend** | Go 1.22, Java 21, Node.js 20+, Python 3.12, GraphQL, gRPC |
| **Data** | PostgreSQL 16, MongoDB 7, TimescaleDB, Redis 7, ClickHouse |
| **AI/ML** | PyTorch 2.3, Triton, CoreML, ONNX, LLM (Mistral/Llama) |
| **Cloud** | AWS (Global), Alibaba Cloud (China), K8s, Terraform, GitOps |
| **Observability** | OpenTelemetry, Prometheus, Grafana, ELK, PagerDuty |
| **Event Streaming** | Apache Kafka, Flink, Redis Pub/Sub |

---

## 📁 PROJECT STRUCTURE

```
titan-smrt/
├── flutter_app/                    # Mobile client
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── design_tokens/
│   │   ├── components/
│   │   │   ├── atoms/
│   │   │   ├── molecules/
│   │   │   ├── organisms/
│   │   │   └── templates/
│   │   ├── screens/
│   │   │   ├── home/
│   │   │   ├── explore/
│   │   │   ├── workout/
│   │   │   ├── shop/
│   │   │   └── profile/
│   │   ├── services/
│   │   ├── stores/
│   │   └── utils/
│   └── native_modules/
│       ├── ios/                    # Swift native modules
│       └── android/                # Kotlin native modules
│
├── services/
│   ├── user-auth/                  # Go service
│   ├── workout-content/            # Java/Spring service
│   ├── tracking-telemetry/         # Go service
│   ├── social-community/           # Node.js service
│   ├── commerce/                   # Java/Spring service
│   ├── billing-subscription/       # Python/FastAPI service
│   ├── ai-coach/                   # Python/PyTorch service
│   └── analytics/                  # Go/ClickHouse service
│
├── infrastructure/
│   ├── kubernetes/
│   ├── terraform/
│   └── docker-compose/
│
├── event-streaming/
│   └── kafka/
│
└── docs/
    ├── ARCHITECTURE_V2.md
    ├── API_CONTRACTS.md
    └── DEPLOYMENT.md