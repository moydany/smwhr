# syntax=docker/dockerfile:1.7
# Build context = repo root. Railway uses railway.json (dockerfilePath=apps/api/Dockerfile).

# ---- 1. base: shared image with corepack + pinned pnpm ----
FROM node:20-bookworm-slim AS base
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable && corepack prepare pnpm@10.31.0 --activate

# ---- 2. builder: full install (incl. devDeps) + prisma generate + nest build ----
FROM base AS builder
WORKDIR /app

COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/api/package.json ./apps/api/
COPY apps/api/prisma ./apps/api/prisma

RUN pnpm install --frozen-lockfile --filter api...

COPY apps/api ./apps/api

WORKDIR /app/apps/api
RUN pnpm exec prisma generate \
 && pnpm build

# ---- 3. prod-deps: production-only node_modules + prisma client ----
FROM base AS prod-deps
WORKDIR /app

COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/api/package.json ./apps/api/
COPY apps/api/prisma ./apps/api/prisma

RUN pnpm install --frozen-lockfile --prod --filter api...

WORKDIR /app/apps/api
RUN pnpm exec prisma generate

# ---- 4. runtime ----
FROM base AS runtime
ENV NODE_ENV=production
WORKDIR /app

# Manifests + workspace structure (preserves pnpm symlinks across stages).
COPY --from=prod-deps /app/pnpm-workspace.yaml /app/package.json /app/pnpm-lock.yaml ./
COPY --from=prod-deps /app/apps/api/package.json ./apps/api/
COPY --from=prod-deps /app/apps/api/prisma ./apps/api/prisma

# Prod-only node_modules (workspace + package levels).
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=prod-deps /app/apps/api/node_modules ./apps/api/node_modules

# Compiled NestJS output.
COPY --from=builder /app/apps/api/dist ./apps/api/dist

EXPOSE 3000
WORKDIR /app/apps/api

# Verbose startup so Railway logs show exactly which phase fails.
# `set -e` exits immediately on the first failed step so we don't silently
# fall through to `node dist/main` after a broken migrate.
CMD ["sh", "-c", "set -e; echo '[boot] PORT='${PORT:-unset}; echo '[boot] node='$(node -v); echo '[boot] running prisma migrate deploy'; node node_modules/prisma/build/index.js migrate deploy; echo '[boot] migrations done, starting Nest'; node dist/src/main.js"]
