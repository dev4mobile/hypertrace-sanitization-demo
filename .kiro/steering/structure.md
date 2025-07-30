# Project Structure

## Root Directory Layout

```
hypertrace-demo/
├── src/main/java/com/example/hypertracedemo/    # Main Java application
├── sanitization-config-service/                 # Full-stack sanitization service
├── scripts/                                     # Utility and management scripts
├── agents/                                      # Hypertrace agent storage
├── docker-compose.yml                           # Multi-service orchestration
├── Dockerfile                                   # Main app containerization
├── build.gradle.kts                            # Gradle build configuration
└── .kiro/steering/                              # AI assistant guidance rules
```

## Main Application Structure

**Java Package Organization**: `com.example.hypertracedemo`

```
src/main/java/com/example/hypertracedemo/
├── HypertraceApplication.java          # Spring Boot main class
├── controller/UserController.java      # REST API endpoints
├── model/User.java                     # JPA entity classes
├── repository/UserRepository.java      # Data access layer
└── service/UserService.java           # Business logic layer
```

**Resources Structure**:
```
src/main/resources/
├── application.yml                     # Main configuration
├── application-dev.yml                 # Development profile
├── application-docker.yml              # Docker profile
└── import.sql                         # Database initialization
```

## Sanitization Config Service Structure

**Frontend (React/TypeScript)**:
```
sanitization-config-service/
├── src/
│   ├── components/                     # React components
│   ├── services/                       # API service layer
│   ├── types/                         # TypeScript definitions
│   ├── utils/                         # Utility functions
│   ├── styles/                        # CSS/styling files
│   ├── App.tsx                        # Main React component
│   └── index.tsx                      # Application entry point
├── public/                            # Static assets
└── build/                             # Production build output
```

**Backend (Node.js/Express)**:
```
sanitization-config-service/server/
├── index.js                           # Express server entry
├── package.json                       # Node.js dependencies
└── Dockerfile                         # Backend containerization
```

## Scripts Directory

**Management Scripts**:
```
scripts/
├── download-agent.sh                  # Download Hypertrace agent
├── run-with-agent.sh                  # Run app with monitoring
├── test-api.sh                        # API testing utilities
├── kafka-topics.sh                    # Kafka topic management
├── kafka-test.sh                      # Kafka producer/consumer tests
└── start-monitoring-stack.sh          # Start complete monitoring stack
```

## Configuration Files

**Docker & Deployment**:
- `docker-compose.yml` - Multi-service orchestration with health checks
- `Dockerfile` - Multi-stage build for main application
- `hypertrace-config.yaml` - Hypertrace agent configuration

**Build Configuration**:
- `build.gradle.kts` - Gradle build with Kotlin DSL
- `settings.gradle.kts` - Gradle project settings

## Architecture Patterns

**Main Application**:
- **Layered Architecture**: Controller → Service → Repository → Entity
- **Spring Boot Conventions**: Auto-configuration, component scanning
- **RESTful API Design**: Standard HTTP methods and status codes

**Sanitization Service**:
- **Full-Stack Separation**: Independent frontend and backend services
- **API-First Design**: RESTful backend with React frontend consumer
- **Fallback Strategy**: Local storage when backend unavailable

**Data Flow**:
1. HTTP requests → Spring Boot controllers
2. Business logic in service layer
3. Data persistence via JPA repositories
4. Kafka events for async processing
5. Distributed tracing via Hypertrace agent

## Naming Conventions

**Java Classes**:
- Controllers: `*Controller.java`
- Services: `*Service.java`
- Repositories: `*Repository.java`
- Entities: Plain nouns (e.g., `User.java`)

**API Endpoints**:
- Base path: `/api/*`
- RESTful conventions: GET/POST/PUT/DELETE
- Resource-based URLs: `/api/users/{id}`

**Docker Services**:
- Kebab-case naming: `hypertrace-demo-app`
- Descriptive service names: `sanitization-backend`
- Network isolation: `hypertrace-network`

## Development Workflow

**Local Development**:
1. Start dependencies: `docker-compose up -d postgres kafka jaeger`
2. Run sanitization service: `./start-full-stack.sh`
3. Run main app: `./scripts/run-with-agent.sh`

**Testing**:
1. Unit tests: `./gradlew test`
2. API testing: `./scripts/test-api.sh`
3. Kafka testing: `./scripts/kafka-test.sh`

**Deployment**:
1. Full stack: `docker-compose up -d --build`
2. Individual services: `docker-compose up -d [service-name]`
3. Health monitoring: Check service health endpoints