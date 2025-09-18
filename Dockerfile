# Simplified single-stage build for CampusConnect application
FROM node:18-alpine

# Install wget for health checks
RUN apk add --no-cache wget

WORKDIR /app

# Install backend dependencies first
COPY server/package*.json ./
RUN npm install

# Copy backend source
COPY server/ ./

# Create a simple static frontend directory with a placeholder
RUN mkdir -p public
COPY cc/public/index.html public/ 2>/dev/null || echo '<!DOCTYPE html><html><head><title>CampusConnect</title></head><body><h1>CampusConnect App</h1><p>Backend is running!</p></body></html>' > public/index.html

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/healthz || exit 1

# Start the application
CMD ["node", "server.js"]