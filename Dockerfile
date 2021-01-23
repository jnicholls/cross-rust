ARG RUST_VERSION=latest

# Start with the official rust container, which will have Linux glibc support.
FROM rust:${RUST_VERSION}

RUN mkdir ~/.cargo

# Setup tooling for cross-compiling to Windows.
RUN apt-get update -y && apt-get install -y mingw-w64
RUN rustup target add x86_64-pc-windows-gnu
RUN printf "[target.x86_64-pc-windows-gnu]\nlinker = \"/usr/bin/x86_64-w64-mingw32-gcc\"\n" >> ~/.cargo/config

# Setup tooling for cross-compiling Apple.
RUN apt-get update -y && apt-get install -y clang cmake libmpc-dev libmpfr-dev
RUN git clone https://github.com/tpoechtrager/osxcross
COPY MacOSX11.1.sdk.tar.xz osxcross/tarballs/.
RUN cd osxcross && UNATTENDED=1 ./build.sh && rm -rf build
ENV PATH ${PATH}:/osxcross/target/bin
RUN rustup target add x86_64-apple-darwin x86_64-apple-ios aarch64-apple-ios
RUN cargo install cargo-lipo
RUN printf "[target.x86_64-apple-darwin]\nlinker = \"x86_64-apple-darwin20.2-clang\"\nar = \"x86_64-apple-darwin20.2-ar\"\n" >> ~/.cargo/config
RUN printf "[target.x86_64-apple-ios]\nlinker = \"x86_64-apple-darwin20.2-clang\"\nar = \"x86_64-apple-darwin20.2-ar\"\n" >> ~/.cargo/config
RUN printf "[target.aarch64-apple-ios]\nlinker = \"aarch64-apple-darwin20.2-clang\"\nar = \"aarch64-apple-darwin20.2-ar\"\n" >> ~/.cargo/config
