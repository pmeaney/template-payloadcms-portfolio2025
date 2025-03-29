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

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy prepared files from the preparation stage
COPY --from=prepare-runtime --chown=nextjs:nodejs /runtime-prep .

# Setup dependencies
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# Add public directory which is always needed
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

RUN chown -R nextjs:nodejs /app

USER nextjs

EXPOSE 3000
ENV PORT 3000

CMD if [ -f .next/skip-build ]; then \
      echo "Running Next.js build that was skipped during Docker build..." && \
      NEXT_SKIP_DB_CONNECT=true npx next build && \
      echo "Running database migrations..." && \
      # Use npx instead of npm run for direct command execution
      npx payload migrate:create || true && \
      npx payload migrate && \
      # Start the application
      HOSTNAME="0.0.0.0" node server.js; \
    else \
      echo "Running database migrations..." && \
      # Use npx instead of npm run for direct command execution
      npx payload migrate:create || true && \
      npx payload migrate && \
      # Start the application
      HOSTNAME="0.0.0.0" node server.js; \
    fi