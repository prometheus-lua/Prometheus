FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    lua5.1 \
    git \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download pre-built Luau binary
RUN curl -sSLo /tmp/luau-ubuntu.zip \
    https://github.com/luau-lang/luau/releases/latest/download/luau-ubuntu.zip \
    && unzip -j /tmp/luau-ubuntu.zip luau -d /usr/local/bin \
    && chmod +x /usr/local/bin/luau \
    && rm /tmp/luau-ubuntu.zip

# Verify installations
RUN lua5.1 -v && printf 'print("luau OK")\n' > /tmp/luau_check.lua && luau /tmp/luau_check.lua && rm /tmp/luau_check.lua

WORKDIR /app
COPY . /app

ENTRYPOINT ["lua5.1", "docker-test-runner.lua"]
