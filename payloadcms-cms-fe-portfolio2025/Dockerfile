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
ARG ENV_FILE
COPY ${ENV_FILE} .env
ENV $(cat .env | xargs)

# Add support for skipping the Next.js build during CI
ARG SKIP_NEXTJS_BUILD=false

# If we're skipping the build during Docker image creation, install dependencies
# so they're available for the runtime build
RUN mkdir -p .next/standalone .next/static
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
      mkdir -p .next/src && \
      cp -r ./src .next/ && \
      cp next.config.js .next/ && \
      cp tsconfig.json .next/ && \
      cp postcss.config.js .next/ && \
      cp tailwind.config.mjs .next/; \
    elif [ -f yarn.lock ]; then yarn run build; \
    elif [ -f package-lock.json ]; then npm run build; \
    elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
    else echo "Lockfile not found." && exit 1; \
    fi

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy public directory and standard files
COPY --from=builder /app/public ./public
COPY --from=builder /app/next.config.js ./next.config.js
COPY --from=builder /app/postcss.config.js ./postcss.config.js
COPY --from=builder /app/tailwind.config.mjs ./tailwind.config.mjs
COPY --from=builder /app/tsconfig.json ./tsconfig.json

# Set the correct permission for prerender cache and node_modules
RUN mkdir -p .next
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json
COPY --from=builder --chown=nextjs:nodejs /app/package-lock.json* ./package-lock.json* || true

# Create src directory conditionally
RUN mkdir -p ./src

# Copy either runtime or built files
COPY --from=builder --chown=nextjs:nodejs /app/.next/skip-build ./.next/skip-build || true
COPY --from=builder --chown=nextjs:nodejs /app/.next/src ./src || true
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./ || true
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static || true

# Copy source files if they weren't copied by the previous step
COPY --from=builder --chown=nextjs:nodejs /app/src ./src || true

RUN chown -R nextjs:nodejs /app

# Switch to nextjs user
USER nextjs

EXPOSE 3000

ENV PORT 3000

# Modify the CMD to handle runtime build with the proper permissions
CMD if [ -f .next/skip-build ]; then \
      echo "Running Next.js build that was skipped during Docker build..." && \
      PAYLOAD_SKIP_MIGRATION=true NEXT_SKIP_DB_CONNECT=true npx next build && \
      HOSTNAME="0.0.0.0" node server.js; \
    else \
      HOSTNAME="0.0.0.0" node server.js; \
    fi