# syntax=docker/dockerfile:1

############################
# Build stage
############################
FROM node:22-bookworm-slim AS build

# corepack provee pnpm segun el campo "packageManager" del package.json (pnpm@9.14.4)
RUN corepack enable

WORKDIR /app

# Copiamos primero los manifiestos para aprovechar la cache de capas
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY patches ./patches

# Resto del codigo (el submodulo privado sdk-components-animation no se clona;
# el build degrada correctamente a src/components.ts)
COPY . .

# Instalamos dependencias, generamos el cliente de prisma y construimos todo
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile

RUN pnpm --filter=@webstudio-is/prisma-client generate

RUN pnpm build

############################
# Runtime stage
############################
FROM node:22-bookworm-slim AS runtime

ENV NODE_ENV=production
ENV PORT=3000

RUN corepack enable

WORKDIR /app

# Copiamos el workspace ya construido (incluye node_modules, build/ y el cliente prisma generado)
COPY --from=build /app /app

# El compose ejecuta: migrations migrate && start del builder
CMD ["sh", "-c", "pnpm --filter=@webstudio-is/prisma-client migrations migrate && pnpm --filter=@webstudio-is/builder start"]
