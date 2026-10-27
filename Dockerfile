FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    lua5.1 \
    python3 \
    patch \
    git \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download pre-built Luau binary
RUN --mount=type=secret,id=ca-bundle \
    if [ -f /run/secrets/ca-bundle ]; then export CURL_CA_BUNDLE=/run/secrets/ca-bundle; fi; \
    curl -fsSLo /tmp/luau-ubuntu.zip \
    https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip \
    && unzip -j /tmp/luau-ubuntu.zip luau -d /usr/local/bin \
    && chmod +x /usr/local/bin/luau \
    && rm /tmp/luau-ubuntu.zip

# Verify installations
RUN lua5.1 -v && printf 'print("luau OK")\n' > /tmp/luau_check.lua && luau /tmp/luau_check.lua && rm /tmp/luau_check.lua

WORKDIR /app
COPY . /app

RUN lua5.1 tests/harness/metadata.lua \
    && timeout 60s lua5.1 tests/harness/numbers-to-expressions.lua \
    && timeout 60s lua5.1 tests/harness/cff-arity.lua \
    && timeout 60s lua5.1 tests/harness/cff-native.lua \
    && timeout 60s lua5.1 tests/harness/vm-arity.lua \
    && timeout 60s lua5.1 tests/harness/vm-prototypes.lua \
    && timeout 60s lua5.1 tests/harness/vm-fastpaths.lua \
    && timeout 60s lua5.1 tests/harness/vm-layout.lua \
    && python3 tests/harness/runner.py

ENTRYPOINT ["lua5.1", "docker-test-runner.lua"]
