# To use this Dockerfile, you have to set `output: 'standalone'` in your next.config.js file.
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile && pnpm rebuild; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Copies the CICD provided env file to .env in the container
ARG ENV_FILE
COPY ${ENV_FILE} .env
ENV $(cat .env | xargs)

# Add support for skipping the Next.js build during CI
ARG SKIP_NEXTJS_BUILD=false

# Prepare for different build strategies
RUN mkdir -p .next/standalone .next/static

# If skipping build, prepare files for runtime build
RUN if [ "$SKIP_NEXTJS_BUILD" = "true" ]; then \
      echo "Preparing for runtime build..." && \
      if [ -f yarn.lock ]; then yarn install; \
      elif [ -f package-lock.json ]; then npm install; \
      elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install; \
      else echo "Lockfile not found." && exit 1; \
      fi && \
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
      # Run the build normally \
      if [ -f yarn.lock ]; then yarn run build; \
      elif [ -f package-lock.json ]; then npm run build; \
      elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
      else echo "Lockfile not found." && exit 1; \
      fi; \
    fi

# Create a separate preparation stage for runtime files
FROM builder AS prepare-runtime
RUN if [ "$SKIP_NEXTJS_BUILD" = "true" ]; then \
      echo "Creating runtime preparation directory" && \
      mkdir -p /runtime-prep/src && \
      cp -r ./src/* /runtime-prep/src/ && \
      cp next.config.js /runtime-prep/ && \
      cp postcss.config.js /runtime-prep/ && \
      cp tailwind.config.mjs /runtime-prep/ && \
      cp tsconfig.json /runtime-prep/ && \
      cp redirects.js /runtime-prep/ && \
      cp -r .next /runtime-prep/; \
    else \
      echo "Creating build output directory" && \
      mkdir -p /runtime-prep && \
      cp -r .next /runtime-prep/ && \
      cp -r public /runtime-prep/ && \
      cp next.config.js /runtime-prep/ && \
      cp postcss.config.js /runtime-prep/ && \
      cp tailwind.config.mjs /runtime-prep/ && \
      cp tsconfig.json /runtime-prep/ && \
      cp redirects.js /runtime-prep/; \
    fi

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

# Install PostgreSQL client for pg_isready and other utilities
RUN apk add --no-cache postgresql-client

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy prepared files from the preparation stage
COPY --from=prepare-runtime --chown=nextjs:nodejs /runtime-prep .

# Setup dependencies
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# Add public directory which is always needed
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

# Create entrypoint script directly in the container
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Check if required environment variables exist\n\
if [ -z "$DATABASE_URI" ]; then\n\
  echo "Error: DATABASE_URI environment variable is not set"\n\
  exit 1\n\
fi\n\
\n\
if [ -z "$PAYLOAD_SECRET" ]; then\n\
  echo "Error: PAYLOAD_SECRET environment variable is not set"\n\
  exit 1\n\
fi\n\
\n\
# Print environment variables for debugging (redact sensitive info)\n\
echo "==== DEBUGGING: Environment Variables ===="\n\
echo "DATABASE_URI: [REDACTED]"\n\
echo "PAYLOAD_SECRET: [REDACTED]"\n\
echo "NEXT_PUBLIC_SERVER_URL: $NEXT_PUBLIC_SERVER_URL"\n\
echo "========================================"\n\
\n\
# Extract database connection details from DATABASE_URI\n\
DB_HOST=$(echo $DATABASE_URI | sed -E '"'"'s/.*@([^:]+):.*/\\1/'"'"')\n\
DB_PORT=$(echo $DATABASE_URI | sed -E '"'"'s/.*:([0-9]+)\\/.*/\\1/'"'"')\n\
DB_NAME=$(echo $DATABASE_URI | sed -E '"'"'s/.*\\/([^?]+).*/\\1/'"'"')\n\
DB_USER=$(echo $DATABASE_URI | sed -E '"'"'s/.*:\\/\\/([^:]+):.*/\\1/'"'"')\n\
\n\
# Function to test if postgres is ready\n\
postgres_ready() {\n\
  pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1\n\
  return $?\n\
}\n\
\n\
echo "Waiting for PostgreSQL database..."\n\
RETRIES=30\n\
until postgres_ready || [ $RETRIES -eq 0 ]; do\n\
  echo "Waiting for PostgreSQL to become available... $((RETRIES)) remaining attempts..."\n\
  RETRIES=$((RETRIES-1))\n\
  sleep 3\n\
done\n\
\n\
if [ $RETRIES -eq 0 ]; then\n\
  echo "Error: PostgreSQL not available after multiple attempts"\n\
  exit 1\n\
fi\n\
\n\
echo "PostgreSQL is available!"\n\
\n\
# Ensure migrations directory exists\n\
echo "Ensuring migrations directory exists..."\n\
mkdir -p /app/src/migrations\n\
\n\
# Run migration status check\n\
echo "Checking migration status..."\n\
npx payload migrate:status\n\
\n\
# Create migration if needed\n\
echo "Creating migration if needed..."\n\
npx payload migrate:create\n\
\n\
# Apply migrations\n\
echo "Running migrations..."\n\
npx payload migrate\n\
\n\
# Build Next.js if needed\n\
if [ -f .next/skip-build ]; then\n\
  echo "Running Next.js build that was skipped during Docker build..."\n\
  # Use NEXT_SKIP_DB_CONNECT to avoid database access during build\n\
  NEXT_SKIP_DB_CONNECT=true npx next build\n\
fi\n\
\n\
# Start the application using the standalone server\n\
echo "Starting Next.js application with standalone server..."\n\
exec node .next/standalone/server.js' > /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh
# Print directory contents to verify entrypoint.sh exists
RUN ls -la /app/
RUN chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000
ENV PORT 3000

# Use entrypoint script
CMD ["/app/entrypoint.sh"]