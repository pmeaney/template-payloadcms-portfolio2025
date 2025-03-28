# To use this Dockerfile, you have to set `output: 'standalone'` in your next.config.js file.
# From https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile

# FROM node:22.12.0-alpine AS base
# Corepack seems to have a problem with Node v22.  Going to try v20
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

RUN \
  if [ "$SKIP_NEXTJS_BUILD" = "true" ]; then \
    echo "Skipping Next.js build due to SKIP_NEXTJS_BUILD flag" && \
    mkdir -p .next/standalone .next/static && \
    echo '{"type":"commonjs"}' > .next/package.json && \
    echo 'module.exports = {props: {}}' > .next/standalone/server.js && \
    touch .next/skip-build; \
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

# Set the correct permission for prerender cache
RUN mkdir -p .next
RUN chown nextjs:nodejs .next

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Copy the skip-build flag if it exists
COPY --from=builder --chown=nextjs:nodejs /app/.next/skip-build ./.next/skip-build || true

USER nextjs

EXPOSE 3000

ENV PORT 3000

# Modify the CMD to handle the case where we skipped the build
CMD if [ -f .next/skip-build ]; then \
      echo "Running Next.js build that was skipped during Docker build..." && \
      npm install && \
      next build && \
      HOSTNAME="0.0.0.0" node server.js; \
    else \
      HOSTNAME="0.0.0.0" node server.js; \
    fi