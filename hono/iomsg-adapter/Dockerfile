FROM node:12

COPY package.json .
COPY package-lock.json .
RUN npm i --production

COPY lib ./lib
COPY bin ./bin

CMD ["node", "./bin/server.js"]