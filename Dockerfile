# Imagem da API. A app não tem dependências de produção, então basta o Node e o código-fonte.
FROM node:24-alpine

ENV NODE_ENV=production PORT=3000
WORKDIR /app

COPY package.json ./
COPY src ./src

# Roda sem privilégios de root (usuário "node" já existe na imagem oficial).
USER node
EXPOSE 3000

# Docker marca o container como "unhealthy" se /health parar de responder 200.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "src/server.js"]
