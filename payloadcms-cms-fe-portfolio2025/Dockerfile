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

# We don't need an entrypoint script anymore 
# as we're using the standard Next.js server startup
RUN chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000
ENV PORT 3000

# Write a debug script for troubleshooting
RUN echo '#!/bin/sh\n\
echo "====== Starting container with debugging ======"\n\
echo "Environment: $NODE_ENV"\n\
echo "Checking for key files:"\n\
ls -la /app/\n\
echo "\nChecking for .next directory:"\n\
ls -la /app/.next/\n\
\n\
echo "\nChecking for .next/standalone directory:"\n\
ls -la /app/.next/standalone/\n\
\n\
echo "\nChecking server.js file:"\n\
if [ -f /app/.next/standalone/server.js ]; then\n\
  echo "server.js exists"\n\
  head -n 10 /app/.next/standalone/server.js\n\
else\n\
  echo "ERROR: server.js does not exist!"\n\
fi\n\
\n\
echo "\n====== Starting application ======"\n\
if [ -f /app/.next/standalone/server.js ]; then\n\
  # Start with error catching to keep container alive\n\
  node /app/.next/standalone/server.js || {\n\
    echo "ERROR: Application crashed. Staying alive for debugging."\n\
    echo "Check logs and fix the issue. Container will remain running."\n\
    # Keep container alive for debugging\n\
    tail -f /dev/null\n\
  }\n\
else\n\
  echo "ERROR: Cannot start application, server.js is missing."\n\
  echo "Container will remain running for debugging."\n\
  # Keep container alive for debugging\n\
  tail -f /dev/null\n\
fi' > /app/docker-entrypoint.sh

RUN chmod +x /app/docker-entrypoint.sh

# Use the debug entrypoint script
CMD ["/app/docker-entrypoint.sh"]