FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# Match the default port in your server.js
EXPOSE 8080
CMD ["node", "server.js"]