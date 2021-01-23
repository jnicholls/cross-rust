ARG RUST_VERSION=latest

# Start with the official rust container, which will have Linux glibc support.
FROM rust:${RUST_VERSION}

RUN mkdir ~/.cargo

# Setup tooling for cross-compiling to Windows.
RUN rustup target add x86_64-pc-windows-gnu
RUN apt-get update -y && apt-get install -y mingw-w64
RUN printf "[target.x86_64-pc-windows-gnu]\nlinker = \"/usr/bin/x86_64-w64-mingw32-gcc\"" >> ~/.cargo/config

# Setup tooling for cross-compiling Apple.

