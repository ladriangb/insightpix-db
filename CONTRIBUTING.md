# Contributing to InsightPix DB

Thank you for your interest in contributing to **InsightPix DB** —  
a modular PostgreSQL-based analytical database for the *InsightPix* ecosystem.

This document defines the contribution workflow, naming conventions, and testing standards used in this repository.  
Even if you are the main contributor, keeping a consistent process ensures code quality and reproducibility.

---

## 🧭 Development Workflow

1. **Create a feature branch**

    ```bash
       git checkout -b feat/feature-name
    ```
2. **Work locally** — make small, focused commits following the Conventional Commits format.
3. **Rebase regularly** to stay aligned with `main`:

   ```bash
   git fetch origin
   git rebase origin/main
   ```
4. **Run tests and lints** before pushing:

   ```bash
   docker compose up -d
   docker compose exec db bash -c "sh /scripts/test.sh"
   ```
5. **Merge back** via fast-forward or Pull Request (recommended if you want to simulate collaborative workflows).

---

## Branch Naming Convention

| Type          | Prefix      | Example                         |
|---------------|-------------|---------------------------------|
| Feature       | `feat/`     | `feat/periodic-metrics`         |
| Fix           | `fix/`      | `fix/initdb-permissions`        |
| Documentation | `docs/`     | `docs/readme-update`            |
| Refactor      | `refactor/` | `refactor/schema-cleanup`       |
| Chore         | `chore/`    | `chore/docker-compose-update`   |
| Test          | `test/`     | `test/pgtap-schema-validation`  |

> 🔹 Keep branch names lowercase, use hyphens, and avoid long sentences.

---

##  Commit Message Guidelines

Use the [Conventional Commits](https://www.conventionalcommits.org) format:

```
<type>(<scope>): <short summary>
```

### Examples

```
feat(schema): add periodic metrics table
fix(init): correct permissions for optional loader
docs(readme): update datamart section
```

Each commit should represent one logical change — small, reviewable, and testable.

---

## Testing

All SQL-level unit tests are written using **pgTAP**.

Run them locally:

```bash
docker compose exec db bash -c "sh /scripts/test.sh"
```

Tests should validate:

* Table and column existence
* Constraints and triggers
* Stored functions and expected outputs

CI pipelines (or manual scripts) must pass all tests before merging to `main`.

---

## Project Structure

```
initdb/          → Base schema and initialization scripts
migrations/      → Versioned schema migrations (Flyway)
tests/           → pgTAP unit tests
scripts/         → Utility scripts for backup & migration
docs/            → Data-Mart diagrams (.puml / .dot)
docker-compose.yaml
```

---

## Local Environment Setup

1. Copy environment variables:

   ```bash
   cp .env.example .env
   ```
2. Start PostgreSQL service:

   ```bash
   docker compose up -d
   ```
3. Access the database:

   ```bash
   docker exec -it insightpix-db psql -U $POSTGRES_USER -d $POSTGRES_DB
   ```

---

## License

All contributions must comply with the [MIT License](./LICENSE).

By submitting a Pull Request or pushing changes, you agree that your code will be distributed under the same license.

---

*Maintained by **Luis Adrian Gonzalez Benavides** — part of the InsightPix modular data ecosystem.*

