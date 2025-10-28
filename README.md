# InsightPix DB

**InsightPix DB** is the foundational database service of the *InsightPix* ecosystem — a modular system designed to gather user feedback on tagged images and transform it into measurable insights.  
This repository contains everything related to the **PostgreSQL schema, triggers, functions, migrations, and testing** used to maintain consistency and generate metrics directly inside the database layer.

---

## Overview

This module handles:
- Core relational structure (`images`, `votes`, `tags`, and derived metric tables).
- SQL logic for automatic aggregation using **triggers and recursive queries**.
- Versioned migrations through **Flyway**.
- Database unit testing with **pgTAP**.
- Containerized deployment with Docker Compose.

By keeping the logic close to the data layer, InsightPix DB ensures that **all analytical metrics remain consistent**, even if different backend or API layers evolve independently.

---

## Architecture

**Core Entities:**
- `images`: stores uploaded images and metadata (tags, URLs, titles).
- `votes`: stores user votes with timestamps.
- `image_metrics`: pre-aggregated results by tag and date, updated via triggers.

**Key Features:**
- Automatic recalculation of metrics upon every vote.
- Periodic aggregation functions (daily, monthly, yearly).
- Optimized queries for fast analytics retrieval.

**Example Flow:**
1. A new vote is inserted into the `votes` table.  
2. A trigger fires to update or insert a record in `image_metrics`.  
3. Metrics are available for the backend API immediately.

---

## Tech Stack

| Component | Technology | Purpose |
|------------|-------------|----------|
| Database | **PostgreSQL 16** | Core engine |
| Migrations | **Flyway** | Schema versioning |
| Unit Tests | **pgTAP** | SQL testing |
| Containerization | **Docker Compose** | Local orchestration |
| Scripting | **Bash** / `psql` | Migration & seed automation |

---

## Project Structure

```

insightpix-db/
├── docker/
│   ├── Dockerfile
│   └── init/
│       ├── 01_schema.sql
│       ├── 02_triggers.sql
│       ├── 03_functions.sql
│       └── 04_seed_data.sql
├── migrations/
│   ├── V1__initial_schema.sql
│   ├── V2__add_functions.sql
│   └── ...
├── tests/
│   ├── 01_schema_tests.sql
│   ├── 02_trigger_tests.sql
│   └── 03_function_tests.sql
├── docker-compose.yml
├── scripts/
│   ├── migrate.sh
│   └── backup.sh
├── .env.example
└── README.md

````

---

## 🚀 Getting Started

### 1. Clone the repository
```bash
git clone https://github.com/ladriangb/insightpix-db.git
cd insightpix-db
````

### 2. Configure environment variables

Copy and edit `.env.example`:

```bash
cp .env.example .env
```

Example content:

```
POSTGRES_USER=insightpix
POSTGRES_PASSWORD=insightpix
POSTGRES_DB=insightpix
POSTGRES_PORT=5432
```

### 3. Build and run the database

```bash
docker compose up -d
```

The database will:

* Create the schema and relations.
* Load triggers and functions.
* Seed initial data for development.

### 4. Verify installation

Access the container:

```bash
docker exec -it insightpix-db psql -U insightpix -d insightpix
```

Run a test query:

```sql
SELECT * FROM images LIMIT 5;
```

---

## Running Tests

Tests are written using **pgTAP** and run automatically during CI builds.
To execute them locally:

```bash
docker compose run --rm db bash -c "pg_prove /tests/*.sql"
```

Expected output:

```
All tests successful.
Files=3, Tests=45,  5 wallclock secs
Result: PASS
```

---


## Development Notes

* All SQL files under `/docker/init/` are automatically loaded on first container run.
* Subsequent updates should be versioned under `/migrations/`.
* Use consistent naming conventions: lowercase, underscores, plural table names.
* Keep triggers idempotent and ensure each has rollback coverage.

---

## License

MIT License © 2025 [Luis Adrian Gonzalez Benavides](https://github.com/ladriangb)

---

> *Part of the [InsightPix](https://github.com/ladriangb) ecosystem — a full DevOps + Full-Stack demonstration project built with modular architecture, real data logic, and automated testing.*

