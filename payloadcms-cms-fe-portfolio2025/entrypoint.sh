#!/bin/bash
set -e

# Check if required environment variables exist
if [ -z "$DATABASE_URI" ]; then
  echo "Error: DATABASE_URI environment variable is not set"
  exit 1
fi

if [ -z "$PAYLOAD_SECRET" ]; then
  echo "Error: PAYLOAD_SECRET environment variable is not set"
  exit 1
fi

# Extract database connection details from DATABASE_URI
DB_HOST=$(echo $DATABASE_URI | sed -E 's/.*@([^:]+):.*/\1/')
DB_PORT=$(echo $DATABASE_URI | sed -E 's/.*:([0-9]+)\/.*/\1/')
DB_NAME=$(echo $DATABASE_URI | sed -E 's/.*\/([^?]+).*/\1/')
DB_USER=$(echo $DATABASE_URI | sed -E 's/.*:\/\/([^:]+):.*/\1/')

# Function to test if postgres is ready
postgres_ready() {
  pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1
  return $?
}

echo "Waiting for PostgreSQL database..."
RETRIES=30
until postgres_ready || [ $RETRIES -eq 0 ]; do
  echo "Waiting for PostgreSQL to become available... $((RETRIES)) remaining attempts..."
  RETRIES=$((RETRIES-1))
  sleep 3
done

if [ $RETRIES -eq 0 ]; then
  echo "Error: PostgreSQL not available after multiple attempts"
  exit 1
fi

echo "PostgreSQL is available!"

# Migrations directory should already exist with correct permissions
echo "Using migrations directory at /app/src/migrations..."

# Install pnpm if needed
if ! command -v pnpm &> /dev/null; then
  echo "Installing pnpm..."
  npm install -g pnpm@10.3.0
fi

NODE_OPTIONS=--no-deprecation pnpm run payload:migrate:status

# Drops all entities from the database and re-runs all migrations from scratch.
# and re-runs all migrations from scratch.
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate:fresh

# Run migration status check
echo "Checking migration status..."
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate:status

# Create migration if needed
echo "Creating migration if needed..."
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate:create

# Apply migrations
echo "Running migrations..."
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate

# Build Next.js if needed
if [ -f .next/skip-build ]; then
  echo "Running Next.js build that was skipped during Docker build..."
  # Use NEXT_SKIP_DB_CONNECT to avoid database access during build
  NEXT_SKIP_DB_CONNECT=true NODE_OPTIONS=--no-deprecation pnpm run build
fi

# Start the application using the standalone server
echo "Starting Next.js application with standalone server..."
exec NODE_OPTIONS=--no-deprecation pnpm run start