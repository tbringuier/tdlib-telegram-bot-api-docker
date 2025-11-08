FROM ubuntu:24.04 AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG TELEGRAM_BOT_API_REF=master
ARG TELEGRAM_BOT_API_REPO=https://github.com/tdlib/telegram-bot-api.git

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates git build-essential cmake gperf \
      zlib1g-dev libssl-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --recursive --depth=1 --branch "${TELEGRAM_BOT_API_REF}" "${TELEGRAM_BOT_API_REPO}" . 

RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local && \
    cmake --build build --target install -- -j"$(nproc)" && \

FROM ubuntu:24.04 AS runtime
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates libssl3 zlib1g libstdc++6 tzdata && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/telegram-bot-api /usr/local/bin/telegram-bot-api

RUN useradd -r -u 10001 -m -d /data botapi && \
    install -d -o botapi -g botapi /data

USER botapi
VOLUME ["/data"]
EXPOSE 8081

ENTRYPOINT ["telegram-bot-api"]
CMD ["--local", "--dir=/data"]
