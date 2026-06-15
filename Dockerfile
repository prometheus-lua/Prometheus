FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    lua5.1 \
    git \
    build-essential \
    cmake \
    ninja-build \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Build upstream LuaJIT from source (apt version has fatal bugs incompatible with Prometheus)
RUN git clone https://luajit.org/git/luajit.git /opt/luajit-src \
    && cd /opt/luajit-src \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && rm -rf /opt/luajit-src

# Build Luau from source
RUN git clone https://github.com/luau-lang/luau.git /opt/luau-src \
    && cd /opt/luau-src \
    && mkdir build && cd build \
    && cmake .. -GNinja -DCMAKE_BUILD_TYPE=Release \
    && ninja \
    && cp luau /usr/local/bin/luau \
    && cp luau-analyze /usr/local/bin/luau-analyze 2>/dev/null || true \
    && cp luau-compile /usr/local/bin/luau-compile 2>/dev/null || true \
    && cp luau-reduce /usr/local/bin/luau-reduce 2>/dev/null || true \
    && rm -rf /opt/luau-src

# Verify installations
RUN lua5.1 -v && luajit -v && printf 'print("luau OK")\n' > /tmp/luau_check.lua && luau /tmp/luau_check.lua && rm /tmp/luau_check.lua

WORKDIR /app
COPY . /app

ENTRYPOINT ["lua5.1", "docker-test-runner.lua"]
