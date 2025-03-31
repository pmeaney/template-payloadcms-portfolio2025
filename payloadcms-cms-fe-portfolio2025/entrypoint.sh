#!/bin/sh
set -e

echo "Starting PayloadCMS application..."

# Basic environment checks
if [ -z "$DATABASE_URI" ]; then
  echo "ERROR: DATABASE_URI environment variable is not set"
  exit 1
fi

if [ -z "$PAYLOAD_SECRET" ]; then
  echo "ERROR: PAYLOAD_SECRET environment variable is not set"
  exit 1
fi

# Parse DB connection params
DB_HOST=$(echo $DATABASE_URI | sed -E 's/.*@([^:]+):.*/\1/')
DB_PORT=$(echo $DATABASE_URI | sed -E 's/.*:([0-9]+)\/.*/\1/')
DB_NAME=$(echo $DATABASE_URI | sed -E 's/.*\/([^?]+).*/\1/')
DB_USER=$(echo $DATABASE_URI | sed -E 's/.*:\/\/([^:]+):.*/\1/')

# Wait for DB
echo "Waiting for PostgreSQL at $DB_HOST:$DB_PORT..."
for i in $(seq 1 30); do
  if pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1; then
    echo "PostgreSQL is ready!"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "ERROR: PostgreSQL not available after 30 attempts"
    exit 1
  fi
  
  echo "Waiting for PostgreSQL... attempt $i/30"
  sleep 3
done

# Run migrations
echo "Running database migrations..."
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate

# Build if needed (for CICD skip build mode)
if [ -f .next/skip-build ]; then
  echo "Running Next.js build..."
  NEXT_SKIP_DB_CONNECT=true NODE_OPTIONS=--no-deprecation pnpm run build
fi

# Start application
echo "Starting Next.js application..."
exec NODE_OPTIONS=--no-deprecation pnpm run start