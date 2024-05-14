# syntax=docker/dockerfile:1

FROM node:18-alpine

WORKDIR /packages 

COPY . .

RUN yarn install

CMD ["yarn", "start"]

EXPOSE 3000
