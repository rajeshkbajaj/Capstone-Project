FROM node:14-alpine

# Create app directory
WORKDIR /usr/src/app

# Install app dependencies,make ensure both package.json AND package-lock.json are copied
COPY package*.json ./

RUN npm install

# Bundle app source
COPY . .

EXPOSE 8081

CMD [ "node", "server.js" ]