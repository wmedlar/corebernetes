FROM python:3.7-alpine
WORKDIR /etc/corebernetes

ARG ANSIBLE_VERSION=2.7

RUN apk add --no-cache openssl && \
    apk add --no-cache --virtual=build-dependencies build-base libffi-dev openssl-dev && \
    pip install ansible=="$ANSIBLE_VERSION" && \
    apk del build-dependencies

COPY . .
