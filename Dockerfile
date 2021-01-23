ARG RUST_VERSION=latest

# Start with the official rust container, which will have Linux glibc support.
FROM rust:${RUST_VERSION}

# Set the cargo registry as a mount point, for caching purposes.
VOLUME ["/usr/local/cargo/registry"]

# Copy in the checksum files for tools we will be downloading.
# A modification to these files (e.g. a version upgrade) will
# cause a rebuild of all of our toolchains.
COPY / /checksums

# Setup tooling for cross-compiling to Windows.
RUN apt-get update -y && apt-get install -y mingw-w64
RUN rustup target add x86_64-pc-windows-gnu

# Setup tooling for cross-compiling macOS and iOS.
RUN apt-get update -y && apt-get install -y clang cmake libmpc-dev libmpfr-dev
RUN git clone https://github.com/tpoechtrager/osxcross \
    && cd /osxcross/tarballs \
    && curl -LO https://github.com/jnicholls/cross-rust/raw/main/MacOSX11.1.sdk.tar.xz \
    && curl -LO https://github.com/jnicholls/cross-rust/raw/main/iPhoneOS14.3.sdk.tar.xz \
    && curl -LO https://github.com/jnicholls/cross-rust/raw/main/iPhoneSimulator14.3.sdk.tar.xz \
    && sha256sum -c /checksums/*.tar.xz.sha256 \
    && cd /osxcross \
    && UNATTENDED=1 ./build.sh \
    && cd /osxcross/target/SDK \
    && tar xJf /osxcross/tarballs/iPhoneOS14.3.sdk.tar.xz \
    && tar xJf /osxcross/tarballs/iPhoneSimulator14.3.sdk.tar.xz \
    && rm -rf /osxcross/build /osxcross/tarballs/*
ENV PATH ${PATH}:/osxcross/target/bin
RUN rustup target add x86_64-apple-darwin x86_64-apple-ios aarch64-apple-ios
RUN cargo install cargo-lipo

# Setup tooling for cross-compiling Android.
RUN curl -LO https://dl.google.com/android/repository/android-ndk-r22-linux-x86_64.zip \
    && sha256sum -c /checksums/*.zip.sha256 \
    && unzip android-ndk-r22-linux-x86_64.zip \
    && rm android-ndk-r22-linux-x86_64.zip
ENV ANDROID_NDK_HOME /android-ndk-r22
ENV PATH ${PATH}:${ANDROID_NDK_HOME}
RUN rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    i686-linux-android \
    x86_64-linux-android
RUN cargo install cargo-ndk

# Setup the cargo config for our various targets.
RUN printf "[target.x86_64-pc-windows-gnu]\nlinker = \"/usr/bin/x86_64-w64-mingw32-gcc\"\n" >> /usr/local/cargo/config
RUN printf "[target.x86_64-apple-darwin]\nlinker = \"x86_64-apple-darwin20.2-clang\"\nar = \"x86_64-apple-darwin20.2-ar\"\n" >> /usr/local/cargo/config
RUN printf "[target.x86_64-apple-ios]\nlinker = \"x86_64-apple-darwin20.2-clang\"\nar = \"x86_64-apple-darwin20.2-ar\"\n" >> /usr/local/cargo/config
RUN printf "[target.aarch64-apple-ios]\nlinker = \"aarch64-apple-darwin20.2-clang\"\nar = \"aarch64-apple-darwin20.2-ar\"\n" >> /usr/local/cargo/config
