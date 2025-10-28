#!/bin/bash

set -e

echo "Initializing InsightPix DB tests..."

pg_prove -U $POSTGRES_USER -d $POSTGRES_DB /tests/*.sql

if [ "$INSTALL_OPTIONAL_TAGS" = "true" ]; then
  if [ -d /tests/optional/ ];then
    echo "→ Running optional tests"
    pg_prove -U $POSTGRES_USER -d $POSTGRES_DB /tests/optional/*.sql
  else
    echo "⚠ No optional modules found in /tests/optionals"
  fi
else
  echo "⚠ Skipping optional modules (set INSTALL_OPTIONAL_TAGS=true to enable)"
fi

echo "✅ All tests complete!"
