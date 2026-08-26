# syntax=docker/dockerfile:1

ARG RUBY_VERSION=3.4.10
FROM ruby:${RUBY_VERSION}-slim-bookworm

ARG NODE_MAJOR=20
ARG YARN_VERSION=1.22.19

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
      build-essential \
      curl \
      git \
      gnupg2 \
      less \
      libjemalloc2 \
      libpq-dev \
      libvips \
      libyaml-dev \
      pkg-config \
      postgresql-client && \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends nodejs && \
    npm install --global yarn@${YARN_VERSION}

ENV LANG=C.UTF-8 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4 \
    BUNDLE_RETRY=3 \
    BOOTSNAP_CACHE_DIR=/usr/local/bundle/_bootsnap \
    HISTFILE=/app/log/.bash_history

WORKDIR /app

CMD ["sleep", "infinity"]
