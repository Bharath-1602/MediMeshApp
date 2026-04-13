FROM node:20-alpine
RUN apk update && apk upgrade --no-cache
WORKDIR /app
COPY package*.json ./
RUN npm install --production && npm cache clean --force
COPY . .
RUN rm -rf /usr/local/lib/node_modules/npm /opt/yarn-v* /usr/local/lib/node_modules/corepack /root/.npm
EXPOSE 5002
CMD ["node", "server.js"]
