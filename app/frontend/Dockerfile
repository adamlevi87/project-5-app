# Stage 1: Build React app
FROM node:18-alpine AS builder

WORKDIR /app

# Only copy package files first to leverage layer caching
COPY package*.json ./

# Install deps separately to cache better
RUN npm install

# Copy the rest of the source
COPY . .

# Build with a dummy value (can use any default here)
ARG REACT_APP_BACKEND_URL=http://localhost:3000
ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL

# Build the app
RUN npm run build

# Stage 2: Serve static app with nginx
FROM nginx:alpine

# Copy the static build
COPY --from=builder /app/build /usr/share/nginx/html

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy optimized nginx config if needed (optional)
# COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]