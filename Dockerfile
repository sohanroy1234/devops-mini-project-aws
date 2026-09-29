# ── Stage 1: Install production dependencies ──
FROM node:18-alpine AS builder
WORKDIR /app
COPY app/package*.json ./
RUN npm ci --only=production

# ── Stage 2: Lean production image ──
FROM node:18-alpine AS production
LABEL org.opencontainers.image.description="DevOps Mini Project"

WORKDIR /app

# Security: non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S appuser -u 1001 -G nodejs

COPY --from=builder --chown=appuser:nodejs /app/node_modules ./node_modules
COPY --chown=appuser:nodejs app/server.js ./
COPY --chown=appuser:nodejs app/src ./src

USER appuser
EXPOSE 4500

ARG APP_VERSION=1.0.0
ENV PORT=4500 \
    APP_VERSION=${APP_VERSION}

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:4500/health || exit 1

CMD ["node", "server.js"]