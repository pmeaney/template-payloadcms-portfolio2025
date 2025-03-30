# To use this Dockerfile, you have to set `output: 'standalone'` in your next.config.js file.
# From https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile

FROM node:22.12.0-alpine AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies based on the preferred package manager
COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then \
    npm install -g pnpm@10.3.0 && \
    NODE_OPTIONS=--no-deprecation pnpm i --frozen-lockfile; \
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

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
# ENV NEXT_TELEMETRY_DISABLED 1

# Add support for skipping the Next.js build during CI
ARG SKIP_NEXTJS_BUILD=false

# If skipping build, prepare files for runtime build
RUN if [ "$SKIP_NEXTJS_BUILD" = "true" ]; then \
      echo "Preparing for runtime build..." && \
      if [ -f yarn.lock ]; then yarn install; \
      elif [ -f package-lock.json ]; then npm install; \
      elif [ -f pnpm-lock.yaml ]; then npm install -g pnpm@10.3.0 && NODE_OPTIONS=--no-deprecation pnpm install; \
      else echo "Lockfile not found." && exit 1; \
      fi && \
      mkdir -p .next/standalone .next/static && \
      echo '{"type":"commonjs"}' > .next/package.json && \
      echo 'module.exports = {props: {}}' > .next/standalone/server.js && \
      echo "true" > .next/skip-build; \
    else \
      # Run the build normally \
      if [ -f yarn.lock ]; then yarn run build; \
      elif [ -f package-lock.json ]; then npm run build; \
      elif [ -f pnpm-lock.yaml ]; then npm install -g pnpm@10.3.0 && NODE_OPTIONS=--no-deprecation pnpm run build; \
      else echo "Lockfile not found." && exit 1; \
      fi; \
    fi

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

# Install PostgreSQL client for pg_isready and other utilities
RUN apk add --no-cache postgresql-client

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy public directory 
COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Copy build output and dependency files
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# If we're in skip build mode, copy the source code for runtime build
COPY --from=builder --chown=nextjs:nodejs /app/.next/skip-build ./.next/skip-build
RUN if [ -f .next/skip-build ]; then \
      mkdir -p ./src && \
      cp -r /app/src/* ./src/ && \
      cp /app/next.config.js ./ && \
      cp /app/postcss.config.js ./ && \
      cp /app/tailwind.config.mjs ./ && \
      cp /app/tsconfig.json ./ && \
      cp /app/redirects.js ./; \
    fi

# Copy entrypoint script and make it executable
COPY --from=builder --chown=nextjs:nodejs /app/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

# We don't need to chown all files since we've done it for each copy
USER nextjs

EXPOSE 3000
ENV PORT 3000

# Use the entrypoint script
CMD ["./entrypoint.sh"]
