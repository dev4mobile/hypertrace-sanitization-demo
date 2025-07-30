# Product Overview

## Hypertrace Java Agent Spring Boot Demo

A comprehensive demonstration project showcasing distributed tracing and monitoring capabilities using Hypertrace Java Agent with Spring Boot applications.

### Core Components

**Main Application (Java/Spring Boot)**
- Demonstrates distributed tracing with OpenTelemetry and Hypertrace
- Includes REST API for user management with CRUD operations
- Kafka integration for message processing and event streaming
- PostgreSQL database integration for data persistence

**Sanitization Config Service (Node.js/React)**
- Full-stack data sanitization rules management system
- React-based frontend management interface with TypeScript
- Node.js backend API service with PostgreSQL database
- Supports various sanitization algorithms (mask, hash, encrypt, replace, remove)
- Intelligent fallback mechanism between backend and local storage

### Key Features

- **Distributed Tracing**: End-to-end request tracing across services and message queues
- **Application Monitoring**: Performance metrics collection and visualization
- **Data Sanitization**: Configurable rules for sensitive data protection
- **Containerized Deployment**: Docker Compose orchestration for all services
- **Monitoring Stack**: Jaeger for tracing, with optional Prometheus/Grafana integration

### Target Use Cases

- Enterprise applications requiring data privacy protection
- Microservices architecture with distributed tracing needs
- Development and testing environments with data sanitization requirements
- Compliance with data protection regulations (GDPR, CCPA)