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

## Periodic Metrics Table (Time-Bucketed Metrics)

To support analytical workloads and historical trend visualization, **InsightPix DB** includes a *periodic snapshot fact table* called:

```
category_metrics_periodic
```

### Purpose

This table stores **aggregated metrics over fixed time intervals** (year, quarter, month, week, day, hour, and day period).
Each row represents a pre-calculated summary for a specific `category_id` and time bucket, allowing queries such as:

- “Which category received more positive votes this week?”
- “What is the trend of engagement per quarter?”
- “At what time of day are users most active?”

By decoupling analytical aggregation from transactional tables, the system supports both:

- **Real-time updates** (via triggers on `votes` and `image_metrics`)
- **Historical summaries** (via `category_metrics_periodic`)

### Data-Mart Design

This table implements a **Periodic Snapshot Fact Table** — a core pattern in dimensional modeling for time-series analytics.
It complements the transactional and aggregated layers:

| Layer         | Type              | Example Table               | Purpose                        |
|---------------|-------------------|-----------------------------|--------------------------------|
| 1 Transaction | Fact Table        | `votes`                     | Raw user events                |
| 2 Aggregation | Snapshot          | `image_metrics`             | On-demand metric updates       |
| 3 History     | Periodic Snapshot | `category_metrics_periodic` | Time-bucketed trend storage    |
| 4 Derived     | Materialized View | `tag_stats_mv`              | Precomputed analytical results |

Each level feeds the next in the *data lineage*:

```
votes → image_metrics → category_metrics_periodic → tag_stats_mv → dashboards
```

> This design enables InsightPix DB to act not only as a transactional backend but also as a compact analytical data mart.


---

## Tech Stack

| Component        | Technology         | Purpose                     |
|------------------|--------------------|-----------------------------|
| Database         | **PostgreSQL 16**  | Core engine                 |
| Migrations       | **Flyway**         | Schema versioning           |
| Unit Tests       | **pgTAP**          | SQL testing                 |
| Containerization | **Docker Compose** | Local orchestration         |
| Scripting        | **Bash** / `psql`  | Migration & seed automation |

---

## Project Structure

```

insightpix-db/
├── docker/
│   ├── Dockerfile
│   └── init/
│       ├── optionals/
│       │   └── 01_tags.sql
│       ├── 01_schema.sql
│       └── 99_optionals.sh
├── migrations/
│   ├── V1__initial_schema.sql
│   └── ...
├── tests/
│   ├── 01_schema_tests.sql
│   └── ...
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

