# syntax=docker/dockerfile:1

##############################################################################
# Builder — follows the official upstream build instructions for Ubuntu 26.04
# (clang + libc++, Release, installed into /usr/local):
#   https://tdlib.github.io/telegram-bot-api/build.html
##############################################################################
FROM ubuntu:26.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
# Accepts a branch, a tag or a full commit SHA (the CI pins the resolved SHA).
ARG TELEGRAM_BOT_API_REF=master
ARG TELEGRAM_BOT_API_REPO=https://github.com/tdlib/telegram-bot-api.git

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      binutils \
      ca-certificates \
      clang-21 \
      cmake \
      git \
      gperf \
      libc++-21-dev \
      libc++abi-21-dev \
      libssl-dev \
      make \
      ninja-build \
      zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Toolchain exactly as upstream recommends: clang with libc++.
# libc++ is linked statically so the runtime image needs no C++ runtime at all.
ENV CC=/usr/bin/clang-21 \
    CXX=/usr/bin/clang++-21 \
    CXXFLAGS="-stdlib=libc++" \
    LDFLAGS="-stdlib=libc++ -static-libstdc++"

WORKDIR /src

# Fetch a single commit (works for refs *and* raw SHAs, unlike --branch).
RUN git init -q . && \
    git remote add origin "${TELEGRAM_BOT_API_REPO}" && \
    git fetch --depth=1 --no-tags origin "${TELEGRAM_BOT_API_REF}" && \
    git checkout -q FETCH_HEAD && \
    git submodule update --init --recursive --depth=1 && \
    git rev-parse HEAD > /telegram-bot-api.commit

RUN cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build build --target install && \
    strip --strip-all /usr/local/bin/telegram-bot-api && \
    rm -rf /src

##############################################################################
# Runtime — the stripped binary plus the CA store and timezone data only.
# libssl3t64, zlib1g and libgcc_s already ship in the ubuntu:26.04 base, and
# libc++ is baked into the binary, so nothing else is required.
##############################################################################
FROM ubuntu:26.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="telegram-bot-api" \
      org.opencontainers.image.description="Telegram Bot API server (tdlib/telegram-bot-api), built from source with clang/libc++ on Ubuntu 26.04, non-root." \
      org.opencontainers.image.source="https://github.com/tbringuier/tdlib-telegram-bot-api-docker" \
      org.opencontainers.image.base.name="docker.io/library/ubuntu:26.04" \
      org.opencontainers.image.licenses="Boost-1.0"

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates tzdata && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

RUN groupadd -r -g 10001 botapi && \
    useradd -r -u 10001 -g botapi -m -d /data botapi && \
    install -d -o botapi -g botapi /data

COPY --link --from=builder /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api
COPY --link --from=builder /telegram-bot-api.commit /usr/local/share/telegram-bot-api.commit

USER botapi:botapi

VOLUME ["/data"]
EXPOSE 8081

# TCP probe via bash instead of pulling curl (and libcurl) into the runtime.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/8081' || exit 1

ENTRYPOINT ["telegram-bot-api"]
CMD ["--local", "--dir=/data"]
