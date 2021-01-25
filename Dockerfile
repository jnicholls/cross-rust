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
    && mkdir -p /applecross/osxcross && mv /osxcross/target/* /applecross/osxcross \
    && /osxcross/build/cctools-port/usage_examples/ios_toolchain/build.sh /osxcross/tarballs/iPhoneOS14.3.sdk.tar.xz arm64 \
    && mkdir -p /applecross/ioscross/arm64 \
    && mv /osxcross/build/cctools-port/usage_examples/ios_toolchain/target/* /applecross/ioscross/arm64 \
    && mkdir /applecross/ioscross/arm64/usr && ln -s /applecross/ioscross/arm64/bin /applecross/ioscross/arm64/usr/bin \
    && sed -i 's#^TRIPLE=.*#TRIPLE="x86_64-apple-darwin11"#' /osxcross/build/cctools-port/usage_examples/ios_toolchain/build.sh \
    && sed -i 's#^WRAPPER_SDKDIR=.*#WRAPPER_SDKDIR=$(echo iPhoneSimulator*sdk | head -n1)#' /osxcross/build/cctools-port/usage_examples/ios_toolchain/build.sh \
    && /osxcross/build/cctools-port/usage_examples/ios_toolchain/build.sh /osxcross/tarballs/iPhoneSimulator14.3.sdk.tar.xz x86_64 \
    && mkdir -p /applecross/ioscross/x86_64 \
    && mv /osxcross/build/cctools-port/usage_examples/ios_toolchain/target/* /applecross/ioscross/x86_64 \
    && mkdir /applecross/ioscross/x86_64/usr && ln -s /applecross/ioscross/x86_64/bin /applecross/ioscross/x86_64/usr/bin \
    && rm -rf /osxcross
ENV PATH ${PATH}:/applecross/osxcross/bin:/applecross/ioscross/arm64/bin:/applecross/ioscross/x86_64/bin
RUN rustup target add aarch64-apple-darwin aarch64-apple-ios x86_64-apple-darwin x86_64-apple-ios
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
RUN printf "[target.aarch64-apple-darwin]\nlinker = \"aarch64-apple-darwin20.2-clang\"\nar = \"aarch64-apple-darwin20.2-ar\"\n" >> /usr/local/cargo/config
RUN printf "[target.aarch64-apple-ios]\nlinker = \"arm-apple-darwin11-clang\"\nar = \"arm-apple-darwin11-ar\"\n" >> /usr/local/cargo/config
RUN printf "[target.x86_64-apple-darwin]\nlinker = \"x86_64-apple-darwin20.2-clang\"\nar = \"x86_64-apple-darwin20.2-ar\"\n" >> /usr/local/cargo/config
RUN printf "[target.x86_64-apple-ios]\nlinker = \"x86_64-apple-darwin11-clang\"\nar = \"x86_64-apple-darwin11-ar\"\n" >> /usr/local/cargo/config

# Install cbindgen so it can be used for projects involving generated bindings.
RUN cargo install cbindgen
