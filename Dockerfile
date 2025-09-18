# Multi-stage build for CampusConnect application

# Stage 1: Build React frontend
FROM node:18-alpine AS frontend-build
WORKDIR /app/frontend

# Copy frontend package files
COPY cc/package*.json ./
RUN npm install

# Copy frontend source code
COPY cc/ ./

# Build the React app
RUN npm run build

# Stage 2: Setup Node.js backend
FROM node:18-alpine AS backend
WORKDIR /app

# Copy backend package files
COPY server/package*.json ./
RUN npm install --only=production

# Copy backend source code
COPY server/ ./

# Copy built frontend from stage 1
COPY --from=frontend-build /app/frontend/build ./public

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Change ownership of app directory
RUN chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node --version || exit 1

# Start the application
CMD ["node", "server.js"]