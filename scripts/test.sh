#!/bin/bash

#!/bin/bash
set -e

docker compose exec db bash -c "pg_prove -U \$POSTGRES_USER -d \$POSTGRES_DB /tests/*.sql"

echo "Initializing InsightPix optional DB..."

if [ "$INSTALL_OPTIONAL_TAGS" = "true" ]; then
  if [ -d /tests/optional/ ];then
    echo "→ Running optional tests"
    docker compose exec db bash -c "pg_prove -U \$POSTGRES_USER -d \$POSTGRES_DB /tests/optional/*.sql"
  else
    echo "⚠ No optional modules found in /tests/optionals"
  fi
else
  echo "⚠ Skipping optional modules (set INSTALL_OPTIONAL_TAGS=true to enable)"
fi

echo "✅ Initialization complete!"