# To use this Dockerfile, you have to set `output: 'standalone'` in your next.config.js file.
FROM node:20-alpine AS base

# Install pnpm only once in the base image
RUN npm install -g pnpm@10.3.0

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies using pnpm
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Copies the CICD provided env file to .env in the container
ARG ENV_FILE
COPY ${ENV_FILE} .env
# Save environment variables for later stages
RUN cat .env > /tmp/env_vars
ENV $(cat .env | xargs)

# Add support for skipping the Next.js build during CI
ARG SKIP_NEXTJS_BUILD=false

# Prepare for different build strategies
RUN mkdir -p .next/standalone .next/static

# If skipping build, prepare files for runtime build
RUN if [ "$SKIP_NEXTJS_BUILD" = "true" ]; then \
      echo "Preparing for runtime build..." && \
      NODE_OPTIONS=--no-deprecation pnpm install && \
      echo '{"type":"commonjs"}' > .next/package.json && \
      echo 'module.exports = {props: {}}' > .next/standalone/server.js && \
      echo "true" > .next/skip-build && \
      # Copy necessary files for runtime build \
      cp -r ./src .next/ && \
      cp next.config.js .next/ && \
      cp tsconfig.json .next/ && \
      cp postcss.config.js .next/ && \
      cp redirects.js .next/ && \
      cp tailwind.config.mjs .next/; \
    else \
      # Run the build with migrations \
      NODE_OPTIONS=--no-deprecation pnpm run ci; \
    fi

# Create a separate preparation stage for runtime files
FROM builder AS prepare-runtime
WORKDIR /app

RUN mkdir -p /runtime-prep

# Copy base files that are needed regardless of build mode
COPY --from=builder /tmp/env_vars /runtime-prep/.env
COPY --from=builder /app/public /runtime-prep/public
COPY --from=builder /app/package.json /runtime-prep/package.json
COPY --from=builder /app/next.config.js /runtime-prep/
COPY --from=builder /app/postcss.config.js /runtime-prep/
COPY --from=builder /app/tailwind.config.mjs /runtime-prep/
COPY --from=builder /app/tsconfig.json /runtime-prep/
COPY --from=builder /app/redirects.js /runtime-prep/

# Copy src directory, ensuring migrations folder exists
RUN mkdir -p /runtime-prep/src/migrations
COPY --from=builder /app/src/migrations /runtime-prep/src/migrations

# Copy additional files based on build mode
RUN if [ "$SKIP_NEXTJS_BUILD" = "true" ]; then \
      echo "Preparing for runtime build..." && \
      cp -r /app/src/* /runtime-prep/src/ && \
      cp -r /app/.next /runtime-prep/; \
    else \
      echo "Using built artifacts..." && \
      cp -r /app/.next /runtime-prep/; \
    fi


# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

# Install PostgreSQL client for database connection checks
RUN apk add --no-cache postgresql-client

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy all prepared files from the preparation stage
COPY --from=prepare-runtime --chown=nextjs:nodejs /runtime-prep/. .

# Copy node_modules
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules

# Ensure migration directory exists with correct permissions
RUN mkdir -p /app/src/migrations && chown -R nextjs:nodejs /app/src/migrations

USER nextjs

EXPOSE 3000
ENV PORT 3000

# Use a cleaner startup approach with a shell script using heredoc
CMD ["sh", "-c", "cat > /tmp/startup.sh << 'EOL' && chmod +x /tmp/startup.sh && /tmp/startup.sh
#!/bin/sh
set -e

# Logging helper
log() {
  local level=\"$1\"
  local message=\"$2\"
  echo \"[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message\"
}

# Environment validation
if [ ! -f \"/app/.env\" ]; then
  log \"WARN\" \".env file not found at /app/.env\"
fi

if [ -z \"$DATABASE_URI\" ]; then
  log \"ERROR\" \"DATABASE_URI environment variable is not set\"
  exit 1
fi

if [ -z \"$PAYLOAD_SECRET\" ]; then
  log \"ERROR\" \"PAYLOAD_SECRET environment variable is not set\"
  exit 1
fi

# Parse database connection details from DATABASE_URI
DB_HOST=$(echo $DATABASE_URI | sed -E 's/.*@([^:]+):.*/\\1/')
DB_PORT=$(echo $DATABASE_URI | sed -E 's/.*:([0-9]+)\\/.*/\\1/')
DB_NAME=$(echo $DATABASE_URI | sed -E 's/.*\\/([^?]+).*/\\1/')
DB_USER=$(echo $DATABASE_URI | sed -E 's/.*:\\/\\/([^:]+):.*/\\1/')

# Database connection check
log \"INFO\" \"Connecting to PostgreSQL database at $DB_HOST:$DB_PORT/$DB_NAME...\"
postgres_ready() {
  pg_isready -h \"$DB_HOST\" -p \"$DB_PORT\" -U \"$DB_USER\" -d \"$DB_NAME\" > /dev/null 2>&1
  return $?
}

RETRIES=30
until postgres_ready || [ $RETRIES -eq 0 ]; do
  log \"INFO\" \"Waiting for PostgreSQL... $RETRIES attempts remaining\"
  RETRIES=$((RETRIES-1))
  sleep 3
done

if [ $RETRIES -eq 0 ]; then
  log \"ERROR\" \"PostgreSQL connection failed after multiple attempts\"
  exit 1
fi

log \"INFO\" \"PostgreSQL connection established successfully\"

# Database migrations
log \"INFO\" \"Checking migration status...\"
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate:status

log \"INFO\" \"Applying pending migrations...\"
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate

log \"INFO\" \"Running final migration status check...\"
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate:status

log \"INFO\" \"Creating new migration if needed...\"
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate:create

log \"INFO\" \"Applying all migrations...\"
NODE_OPTIONS=--no-deprecation pnpm run payload:migrate

# Handle deferred build if needed
if [ -f .next/skip-build ]; then
  log \"INFO\" \"Running deferred Next.js build...\"
  NEXT_SKIP_DB_CONNECT=true NODE_OPTIONS=--no-deprecation pnpm run build
fi

# Launch application
log \"INFO\" \"Starting Next.js application in standalone mode\"
exec NODE_OPTIONS=--no-deprecation pnpm run start
EOL"]