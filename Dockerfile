## Build an image which just installs dependencies (needing git and ssh)
FROM node:carbon-alpine AS builder
RUN apk add --update --no-cache git openssh-client yarn

ARG RSA_KEY
RUN mkdir -p /root/.ssh/ && \
    echo -e "$RSA_KEY" > /root/.ssh/id_rsa && \
    chmod 400 /root/.ssh/id_rsa && \
    ssh-keyscan -t rsa github.com > ~/.ssh/known_hosts

# Install deps
ARG NODE_ENV=development
ENV NODE_ENV ${NODE_ENV}
ARG API_ENV=production
ENV API_ENV ${API_ENV}

COPY . /app/
RUN git fetch --tags --unshallow || true
RUN yarn install

# Build webpack files if needed
RUN if [ "$NODE_ENV" == "production" ]; then yarn build; fi

# Image to which takes dependencies from last image and adds in the rest on top
FROM node:carbon-alpine

RUN apk add --update --no-cache git tini yarn

COPY --from=builder /app /app
COPY . /app/
RUN chown -R node /app/

EXPOSE 8080
ENV PORT=8080

ARG NODE_ENV=development
ENV NODE_ENV=$NODE_ENV
ARG API_ENV=production
ENV API_ENV ${API_ENV}

WORKDIR /app

# Never run as root
USER node
