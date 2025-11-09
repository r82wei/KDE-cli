FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm install --production=false || npm install --production=false

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY tsconfig.json package.json ./
COPY src ./src
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/dist ./dist
COPY package.json ./
RUN npm install --omit=dev && adduser -D appuser && chown -R appuser:appuser /app
USER appuser
EXPOSE 3333
ENV HOST=0.0.0.0
CMD ["node", "dist/server.js"]


