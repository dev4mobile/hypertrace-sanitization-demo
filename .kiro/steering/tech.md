# Technology Stack

## Build System & Tools

**Primary Build Tool**: Gradle with Kotlin DSL (`build.gradle.kts`)
**Java Version**: Java 17 (Amazon Corretto)
**Container Platform**: Docker with Docker Compose orchestration

## Main Application Stack

**Framework**: Spring Boot 3.3.0
**Language**: Java 17
**Database**: PostgreSQL (production), H2 (testing)
**Message Broker**: Apache Kafka (KRaft mode, no Zookeeper)
**Monitoring**: Hypertrace Java Agent + OpenTelemetry

### Key Dependencies
- Spring Boot Starter Web, Data JPA, Validation
- Spring Kafka for message processing
- OpenTelemetry API for manual tracing
- PostgreSQL driver

## Sanitization Config Service Stack

**Frontend**: React 19.1.0 with TypeScript 4.9.5
**Backend**: Node.js 22+ with Express 4.18.2
**Database**: PostgreSQL 15/16
**Styling**: Tailwind CSS with custom components

### Frontend Dependencies
- Lucide React (icons)
- React Hot Toast (notifications)
- TypeScript for type safety

### Backend Dependencies
- Express.js web framework
- pg (PostgreSQL client)
- fs-extra (file operations)
- CORS, Helmet (security)
- Joi (validation)

## Monitoring & Observability

**Distributed Tracing**: Jaeger (all-in-one)
**Agent**: Hypertrace Java Agent 1.3.25
**Protocol**: OpenTelemetry (OTLP)
**Optional**: Prometheus + Grafana stack

## Common Commands

### Main Application
```bash
# Build application
./gradlew build

# Run with Hypertrace agent
./scripts/run-with-agent.sh

# Run tests
./gradlew test

# Build Docker image
docker build -t hypertrace-sanitization-demo .
```

### Sanitization Service
```bash
# Install dependencies
npm install

# Start frontend development
npm start

# Build production
npm run build

# Start backend
./start-backend.sh

# Full stack development
./start-full-stack.sh
```

### Docker Operations
```bash
# Start all services
docker-compose up -d

# Start with build
docker-compose up -d --build

# View logs
docker-compose logs -f [service-name]

# Stop services
docker-compose down

# Clean volumes
docker-compose down -v
```

### Kafka Management
```bash
# Create topic
./scripts/kafka-topics.sh create user-events

# List topics
./scripts/kafka-topics.sh list

# Test producer/consumer
./scripts/kafka-test.sh test-messages user-events
```

## Environment Configuration

**Development**: Local services with H2/PostgreSQL
**Docker**: Containerized with service discovery
**Production**: Multi-container deployment with health checks

## Port Allocation

- **8080**: Main Spring Boot application
- **3000**: Sanitization frontend
- **3001**: Sanitization backend API
- **5432**: PostgreSQL (main)
- **55432**: PostgreSQL (sanitization)
- **9092**: Kafka broker
- **16686**: Jaeger UI
- **10020**: Dockerized Spring Boot app