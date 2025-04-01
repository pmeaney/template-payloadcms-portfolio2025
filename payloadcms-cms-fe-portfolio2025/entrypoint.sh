#!/bin/sh
set -e

# Set environment variables from .env file if it exists
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# Wait for database to be ready if DATABASE_URI is set
if [ -n "$DATABASE_URI" ]; then
  echo "Waiting for database to be ready..."
  
  # Parse database connection details
  DB_HOST=$(echo $DATABASE_URI | sed -n 's/.*@\([^:]*\).*/\1/p')
  DB_PORT=$(echo $DATABASE_URI | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
  
  # Default to port 5432 if not found
  if [ -z "$DB_PORT" ]; then
    DB_PORT=5432
  fi
  
  # Wait for database connection
  until pg_isready -h $DB_HOST -p $DB_PORT -U postgres; do
    echo "Database is unavailable - sleeping"
    sleep 2
  done
  
  echo "Database is up and running!"
fi

# Run migrations
echo "Running database migrations..."
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate --force-accept-warning

# Start the application
echo "Starting the application..."
exec pnpm run start