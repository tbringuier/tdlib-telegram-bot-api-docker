# syntax=docker/dockerfile:1
FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG TELEGRAM_BOT_API_REF=master
ARG TELEGRAM_BOT_API_REPO=https://github.com/tdlib/telegram-bot-api.git

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates git build-essential cmake gperf ninja-build \
      zlib1g-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --recursive --shallow-submodules --depth=1 --branch "${TELEGRAM_BOT_API_REF}" "${TELEGRAM_BOT_API_REPO}" .

RUN cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build build --target install

FROM ubuntu:24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates libssl3 zlib1g libstdc++6 tzdata curl && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd -r -g 10001 botapi && \
    useradd -r -u 10001 -g botapi -m -d /data botapi && \
    install -d -o botapi -g botapi /data

COPY --link --from=builder /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api

USER botapi:botapi

VOLUME ["/data"]
EXPOSE 8081
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -s http://127.0.0.1:8081/ || exit 1

ENTRYPOINT ["telegram-bot-api"]
CMD ["--local", "--dir=/data"]
