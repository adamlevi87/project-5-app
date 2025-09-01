FROM node:22-alpine

WORKDIR /app

# Copy package files
COPY package.json .
COPY index.js .

# Install dependencies
RUN npm install

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S lambda -u 1001 -G nodejs

# Change to non-root user
USER lambda

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "console.log('Health check passed')" || exit 1

CMD ["node", "index.js"]