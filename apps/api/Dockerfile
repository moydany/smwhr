FROM node:20-bookworm-slim AS builder

WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.31.0 --activate

COPY pnpm-workspace.yaml package.json pnpm-lock.yaml ./
COPY apps/api/package.json ./apps/api/
COPY apps/api/prisma ./apps/api/prisma

RUN pnpm install --frozen-lockfile --filter api...

COPY apps/api ./apps/api

WORKDIR /app/apps/api
RUN pnpm exec prisma generate
RUN pnpm build

# ---- Runtime ----
FROM node:20-bookworm-slim AS runtime

ENV NODE_ENV=production
ENV PORT=3000

WORKDIR /app
RUN corepack enable && corepack prepare pnpm@10.31.0 --activate

COPY --from=builder /app/pnpm-workspace.yaml /app/package.json /app/pnpm-lock.yaml ./
COPY --from=builder /app/apps/api/package.json ./apps/api/
COPY --from=builder /app/apps/api/prisma ./apps/api/prisma
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/apps/api/node_modules ./apps/api/node_modules
COPY --from=builder /app/apps/api/dist ./apps/api/dist

EXPOSE 3000

WORKDIR /app/apps/api
CMD ["pnpm", "start:prod"]
