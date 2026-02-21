# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with code in this repository.

## Project Overview

This is a FastAPI-based web application that provides a search interface for n8n workflow automation files. The application serves as a documentation and search platform for 4,000+ n8n workflows organized by integration type (190+ categories).

## Common Development Commands

### Starting the Server
```bash

# Default (port 8000, localhost only)
python run.py

# Development mode with auto-reload
python run.py --dev

# Custom host/port
python run.py --host 0.0.0.0 --port 3000

# Force database reindexing
python run.py --reindex

# Skip workflow indexing (useful for CI/testing)
python run.py --skip-index

# Production mode with gunicorn
gunicorn -w 4 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000 api_server:app
```

### Testing
```bash

# Install dependencies
pip install -r requirements.txt

# Run workflow validation tests
python test_workflows.py

# Run API tests (server must be running)
./test_api.sh

# Run security tests
./test_security.sh

# Lint code
flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics
```

### Docker Operations
```bash

# Build image
docker build -t n8n-workflows .

# Run container
docker run -p 8000:8000 n8n-workflows

# Run with Docker Compose
docker compose -f docker-compose.yml up

# Development with Compose
docker compose -f docker-compose.yml -f docker-compose.dev.yml up

# Production with Compose
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Health check
curl http://localhost:8000/api/stats
```

### Database Management
```bash

# Force reindex workflows
python run.py --reindex

# Backup database
cp database/workflows.db database/workflows.db.backup

# Trigger reindex via API (when server is running)
curl -X POST http://localhost:8000/api/reindex
```

## Architecture

### Backend Structure
- **api_server.py**: FastAPI application serving REST API endpoints, handles CORS, rate limiting, and serves static files
- **workflow_db.py**: SQLite database manager with FTS5 full-text search integration. Manages workflow indexing, search queries, and metadata extraction
- **run.py**: Server launcher with CLI argument parsing, dependency checking, and initialization

### Database Schema
The SQLite database (`database/workflows.db`) contains:
- `workflows` table: Stores workflow metadata (name, description, trigger_type, complexity, node_count, integrations, tags)
- `workflows_fts` table: FTS5 virtual table for full-text search across name, description, integrations, and tags
- Indexes on trigger_type, complexity, active status, node_count, and filename for fast filtering
- Triggers to keep FTS table synchronized with main table

### Frontend Structure
- **static/index.html**: Main web interface with search, filtering, and workflow display
- **static/mobile-app.html** and **static/mobile-interface.html**: Mobile-optimized interfaces
- **docs/**: GitHub Pages site for public documentation (deployed to zie619.github.io/n8n-workflows)

### Workflow Files
- **workflows/**: Directory containing 4,000+ n8n workflow JSON files
- Organized into 190+ subdirectories by integration type (e.g., Activecampaign, Airtable, Asana, etc.)
- Each workflow JSON contains: name, nodes array, connections object, settings, staticData, tags, and timestamps
- Workflows are indexed into SQLite on first run or when `--reindex` is used

### Source Modules (src/)
The `src/` directory contains additional feature modules:
- **ai_assistant.py**: AI-powered workflow analysis and recommendations
- **integration_hub.py**: Integration management and API endpoints
- **enhanced_api.py**: Extended API features
- **analytics_engine.py**: Analytics and reporting
- **community_features.py**: Community-driven features
- **performance_monitor.py**: Performance tracking and monitoring
- **user_management.py**: User authentication and management
- **database.js** and **server.js**: Legacy Node.js files (likely unused)

### Scripts Directory
- **deploy.sh**: Comprehensive deployment script supporting Docker Compose, Kubernetes, and Helm
- **backup.sh**: Database and configuration backup utilities
- **health-check.sh**: Application health monitoring
- **generate_search_index.py**: Generate search indices
- **update_github_pages.py**: Deploy documentation to GitHub Pages
- **update_readme_stats.py**: Update README statistics

## API Endpoints

The FastAPI server provides the following endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Web interface (serves static/index.html) |
| `/api/stats` | GET | Repository statistics (workflow counts, etc.) |
| `/api/workflows` | GET | Search workflows with filters (search, category, complexity, trigger_type, page, per_page) |
| `/api/workflows/{id}` | GET | Get specific workflow JSON by ID |
| `/api/categories` | GET | List all workflow categories |
| `/api/integrations` | GET | List all integrations |
| `/api/export` | GET | Export workflows (optional format filter) |
| `/api/reindex` | POST | Trigger workflow reindexing |
| `/docs` | GET | Interactive API documentation (Swagger UI) |

## Environment Variables

- `WORKFLOW_DB_PATH`: Path to SQLite database (default: `workflows.db` or `database/workflows.db`)
- `ENVIRONMENT`: Deployment environment (development/production)
- `LOG_LEVEL`: Logging level (default: info)
- `HOST`: Bind host (default: 127.0.0.1)
- `PORT`: Bind port (default: 8000)
- `CI`: Set to "true" to skip indexing in CI mode

## Workflow Analysis

When analyzing workflow JSON files:
1. Each workflow is stored in `workflows/[category]/[filename].json`
2. Key fields: `name`, `nodes` (array of node objects), `connections` (defines node connections)
3. Common node types: Trigger nodes (webhook, cron, manual), Integration nodes (HTTP Request, API integrations), Logic nodes (IF, Switch, Merge), Data nodes (Function, Set, Transform)
4. Workflows may contain credentials in webhook URLs or API configurations (credentials typically stored separately in n8n)
5. Node connections define the execution flow and data flow between nodes

## Development Notes

- The application uses SQLite with FTS5 for sub-100ms search performance
- Docker builds support both linux/amd64 and linux/arm64 platforms
- Security features include path traversal protection, input validation, CORS protection, rate limiting, and non-root container user
- The database is indexed on startup unless `--skip-index` is used or CI environment is detected
- Rate limiting is implemented at 60 requests per minute per IP
- Static files are served with GZip compression for responses > 1KB

## CI/CD

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) runs:
- Python 3.9, 3.10, 3.11 compatibility tests
- flake8 linting
- Application startup tests with `--skip-index` flag
- Docker build tests
- Trivy security scanning (non-blocking)
- Multi-platform Docker builds (amd64, arm64)

## Deployment

Multiple deployment options:
1. Docker Compose (recommended): `docker compose -f docker-compose.yml -f docker-compose.[dev|prod].yml up`
2. Standalone Docker: `docker build -t n8n-workflows . && docker run -p 8000:8000 n8n-workflows`
3. Python direct: `pip install -r requirements.txt && python run.py`
4. Kubernetes: Apply manifests in `k8s/` directory
5. Helm: Use chart in `helm/` directory

See `DEPLOYMENT.md` for detailed deployment instructions including SSL/TLS, authentication, monitoring, and scaling configurations.

# Overview
This repository contains a collection of n8n workflow automation files. n8n is a workflow automation tool that allows creating complex automations through a visual node-based interface. Each workflow is stored as a JSON file containing node definitions, connections, and configurations.

#

# Repository Structure
```text

text

text
n8n-workflows/
├── workflows/

# Common Patterns

- **Data Pipeline**: Trigger → Fetch Data → Transform → Store/Send

- **Integration Sync**: Cron → API Call → Compare → Update Systems

- **Automation**: Webhook → Process → Conditional Logic → Actions

- **Monitoring**: Schedule → Check Status → Alert if Issues

#