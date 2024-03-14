# Compile
FROM    nvidia/cuda:12.3.2-devel-ubuntu22.04 AS compiler

ENV	NVIDIA_VISIBLE_DEVICES all
ENV	NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV	CUDA_COMPUTE_CAP 89

RUN     apt-get update -qq \
        && apt-get install -y -qq build-essential curl pkg-config libssl-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

RUN     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

ENV     PATH "/root/.cargo/bin:/usr/bin:${PATH}"

WORKDIR /

ARG     COMMIT_SHA
ARG     COMMIT_DATE
ARG     GIT_TAG
ENV     VERGEN_GIT_SHA=${COMMIT_SHA} VERGEN_GIT_COMMIT_TIMESTAMP=${COMMIT_DATE} VERGEN_GIT_DESCRIBE=${GIT_TAG}
ENV     RUSTFLAGS "-C target-feature=-crt-static"
ENV     RUST_BACKTRACE=1

COPY    . .
RUN     set -eux; \
        cargo build --release -p meilisearch -p meilitool -p milli --no-default-features --features "cuda analytics mini-dashboard japanese"

# Run
FROM    nvidia/cuda:12.3.2-runtime-ubuntu22.04

#ENV	NVIDIA_VISIBLE_DEVICES all
#ENV	NVIDIA_DRIVER_CAPABILITIES compute,utility

ENV     MEILI_HTTP_ADDR 0.0.0.0:7700
ENV     MEILI_SERVER_PROVIDER docker

RUN     apt-get update -qq \
        && apt-get install -y -qq tini curl \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

# add meilisearch and meilitool to the `/bin` so you can run it from anywhere
# and it's easy to find.
COPY    --from=compiler /target/release/meilisearch /bin/meilisearch
COPY    --from=compiler /target/release/meilitool /bin/meilitool
# To stay compatible with the older version of the container (pre v0.27.0) we're
# going to symlink the meilisearch binary in the path to `/meilisearch`
RUN     ln -s /bin/meilisearch /meilisearch

# This directory should hold all the data related to meilisearch so we're going
# to move our PWD in there.
# We don't want to put the meilisearch binary
WORKDIR /meili_data


EXPOSE  7700/tcp

ENTRYPOINT ["tini", "--"]
CMD     /bin/meilisearch
