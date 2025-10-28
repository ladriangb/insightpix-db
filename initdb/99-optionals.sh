#!/bin/bash
set -e

echo "Initializing InsightPix optional DB..."

if [ "$INSTALL_OPTIONAL_TAGS" = "true" ]; then
  if [ -d /docker-entrypoint-initdb.d/optional/ ];then
    for f in /docker-entrypoint-initdb.d/optional/*.sql; do
      echo "→ Running optional script: $f"
      psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
    done
  else
    echo "⚠ No optional modules found in /docker-entrypoint-initdb.d/optional/"
  fi
else
  echo "⚠ Skipping optional modules (set INSTALL_OPTIONAL_TAGS=true to enable)"
fi

echo "✅ Initialization complete!"
