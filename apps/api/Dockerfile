# syntax=docker/dockerfile:1.7
# Build context = repo root. Railway invokes via railway.json (dockerfilePath=apps/api/Dockerfile).

# ---- 1. base: shared image with corepack + pinned pnpm ----
FROM node:20-bookworm-slim AS base
ENV PNPM_HOME=/pnpm
ENV PATH=$PNPM_HOME:$PATH
RUN corepack enable && corepack prepare pnpm@10.31.0 --activate

# ---- 2. builder: full install + nest build + prisma generate ----
FROM base AS builder
WORKDIR /app

# Manifests first → maximize layer cache hits when source changes but deps don't.
COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/api/package.json ./apps/api/

RUN pnpm install --frozen-lockfile --filter api...

# Source comes after deps so dep layers stay cached.
COPY apps/api ./apps/api

WORKDIR /app/apps/api
RUN pnpm exec prisma generate \
 && pnpm build

# Strip dev deps + flatten workspace into self-contained tree at /prod/api.
WORKDIR /app
RUN pnpm --filter=api deploy --prod /prod/api

# pnpm deploy reinstalls fresh, so regenerate the prisma client in the prod tree.
RUN cd /prod/api && pnpm exec prisma generate

# ---- 3. runtime: minimal final image ----
FROM base AS runtime
ENV NODE_ENV=production
WORKDIR /app

COPY --from=builder --chown=node:node /prod/api /app

USER node
EXPOSE 3000
CMD ["pnpm", "start:prod"]
