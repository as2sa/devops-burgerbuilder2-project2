# Multi-stage build for React application

# Stage 1: Build the application
FROM node:20-alpine AS build

# Set working directory inside the docker container
WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy source code and build
COPY . .

# Build argument for API URL
ARG VITE_API_BASE_URL
ENV VITE_API_BASE_URL=$VITE_API_BASE_URL

# Debug: Print the environment variable to verify it's set
RUN echo "VITE_API_BASE_URL is set to: $VITE_API_BASE_URL"

RUN chmod +x node_modules/.bin/tsc || true

# Build the application
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:alpine
WORKDIR /usr/share/nginx/html

# Remove default nginx static assets
RUN rm -rf ./*

# Copy built assets from build stage to the current working directory of the container
COPY --from=build /app/dist .

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80
EXPOSE 80

# Start nginx
CMD ["nginx", "-g", "daemon off;"]