# To use this Dockerfile, you have to set `output: 'standalone'` in your next.config.js file.
# From https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile

FROM node:20-alpine AS base

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
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Rebuild the source code only when needed
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Copies the CICD provided `env-defaults.env` file to `.env` in the container
# ENV $(cat .env | xargs) command reads all the environment variables from the file and adds them to the container's environment
ARG ENV_FILE
COPY ${ENV_FILE} .env
ENV $(cat .env | xargs)

# Next.js collects completely anonymous telemetry data about general usage.
# Learn more here: https://nextjs.org/telemetry
# Uncomment the following line in case you want to disable telemetry during the build.
# ENV NEXT_TELEMETRY_DISABLED 1

# Add support for skipping the Next.js build during CI
ARG SKIP_NEXTJS_BUILD=false

# If we're skipping the build during Docker image creation, install dependencies
# so they're available for the runtime build
RUN \
  mkdir -p .next/standalone .next/static && \
  if [ "$SKIP_NEXTJS_BUILD" = "true" ]; then \
    echo "Preparing for runtime build..." && \
    if [ -f yarn.lock ]; then yarn install; \
    elif [ -f package-lock.json ]; then npm install; \
    elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install; \
    else echo "Lockfile not found." && exit 1; \
    fi && \
    echo '{"type":"commonjs"}' > .next/package.json && \
    echo 'module.exports = {props: {}}' > .next/standalone/server.js && \
    echo "true" > .next/skip-build; \
  elif [ -f yarn.lock ]; then yarn run build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  else echo "Lockfile not found." && exit 1; \
  fi

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
# ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Remove this line if you do not have this folder
COPY --from=builder /app/public ./public

# Set the correct permission for prerender cache and node_modules
RUN mkdir -p .next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/package-lock.json* ./package-lock.json*
RUN chown -R nextjs:nodejs /app

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy the skip-build marker file
COPY --from=builder --chown=nextjs:nodejs /app/.next/skip-build ./.next/skip-build

# Switch to nextjs user
USER nextjs

EXPOSE 3000

ENV PORT 3000

# Modify the CMD to handle runtime build with the proper permissions
CMD if [ -f .next/skip-build ]; then \
      echo "Running Next.js build that was skipped during Docker build..." && \
      npx next build && \
      HOSTNAME="0.0.0.0" node server.js; \
    else \
      HOSTNAME="0.0.0.0" node server.js; \
    fi