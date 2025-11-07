# BUILD
FROM node:18-slim AS builder

WORKDIR /app

COPY package*.json ./
# Install *only* production dependencies
RUN npm ci --only=production
COPY . .

# PRODUCTION
FROM node:18-alpine

WORKDIR /app

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

USER appuser

EXPOSE 3000

CMD [ "node", "app.js" ]