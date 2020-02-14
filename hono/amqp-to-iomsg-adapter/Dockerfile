FROM node:8

COPY package.json .
COPY package-lock.json .

RUN npm i --production

COPY lib ./lib

CMD ["node", "lib/client.js"]