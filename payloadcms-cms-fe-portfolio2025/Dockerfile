# To use this Dockerfile, you have to set `output: 'standalone'` in your next.config.js file.
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Install dependencies using npm only
COPY package.json package-lock.json* ./
RUN npm ci

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
      npm install && \
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
      npm run ci; \
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

# Modify the CMD to handle runtime build with the proper permissions
CMD if [ -f .next/skip-build ]; then \
      echo "Running Next.js build that was skipped during Docker build..." && \
      npm run ci && \
      HOSTNAME="0.0.0.0" node server.js; \
    else \
      HOSTNAME="0.0.0.0" node server.js; \
    fi