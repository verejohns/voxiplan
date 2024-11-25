FROM ruby:2.7.6-slim

RUN apt update && apt install -y \
    build-essential make curl git \
    libxml2-dev libpq-dev libv8-dev libcurl4-openssl-dev shared-mime-info nodejs \
    && rm -rf /var/lib/apt/lists/*
