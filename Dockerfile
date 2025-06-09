# -----------------------
# STAGE 1: BUILD FFmpeg
# -----------------------
  FROM alpine:3.20 as builder

  RUN apk update && apk add --no-cache \
      libgomp \
      zeromq \
      zeromq-dev \
      opencore-amr \
      opencore-amr-dev \
      libogg \
      libogg-static \
      libogg-dev \
      libtheora \
      libtheora-static \
      libtheora-dev \
      x264 \
      x264-libs \
      x264-dev \
      x265 \
      x265-libs \
      x265-dev \
      opus \
      opus-tools \
      opus-dev \
      libvorbis \
      libvorbis-static \
      libvorbis-dev \
      libvpx \
      libvpx-utils \
      libvpx-dev \
      libwebp \
      libwebp-dev \
      libwebp-static \
      libwebp-tools \
      lame \
      lame-libs \
      lame-dev \
      xvidcore \
      xvidcore-static \
      xvidcore-dev \
      fdk-aac \
      fdk-aac-dev \
      openjpeg \
      openjpeg-tools \
      openjpeg-dev \
      freetype \
      freetype-static \
      freetype-dev \
      vidstab \
      vidstab-dev \
      fribidi \
      fribidi-static \
      fribidi-dev \
      fontconfig \
      fontconfig-static \
      fontconfig-dev \
      font-dejavu \
      libass \
      libass-dev \
      aom \
      aom-libs \
      aom-dev \
      util-macros \
      xorgproto \
      libxau \
      libxau-dev \
      libxml2 \
      libxml2-static \
      libxml2-utils \
      libxml2-dev \
      libsrt \
      libsrt-progs \
      libsrt-dev \
      libpng \
      libpng-static \
      libpng-utils \
      libpng-dev \
      zimg \
      zimg-dev \
      dav1d \
      libdav1d \
      dav1d-dev \
      svt-av1 \
      svt-av1-dev \
      libSvtAv1Enc \
      gnutls-dev \
      libunistring-dev \
      libSvtAv1Dec
  
  RUN apk update && apk add --no-cache \
      autoconf \
      automake \
      bash \
      binutils \
      bzip2 \
      cmake \
      coreutils \
      curl \
      wget \
      jq \
      diffutils \
      expat-dev \
      file \
      g++ \
      gcc \
      git \
      gperf \
      libtool \
      make \
      meson \
      ninja-build \
      nasm \
      openssl-dev \
      python3 \
      tar \
      xz \
      xcb-proto \
      yasm \
      zlib-dev \
      alpine-sdk \
      linux-headers
  
  # 构建 x265（static，支持 .pc 文件）
  WORKDIR /build
  RUN git clone --depth=1 --branch=3.6 https://bitbucket.org/multicoreware/x265_git.git && \
      cd x265_git/build/linux && \
      MAKEFLAGS="-j8" bash multilib.sh && \
      cd 8bit && \
      make install && \
      cp libx265.so.* /usr/local/lib/
  
  # 克隆 FFmpeg 6.0 官方源码
  WORKDIR /build
  RUN git clone --branch n6.0 --depth=1 https://git.ffmpeg.org/ffmpeg.git ffmpeg
  
  RUN git clone https://github.com/runner365/ffmpeg_rtmp_h265.git ffmpeg_rtmp_h265
  
  # flv 补丁
  WORKDIR /build/ffmpeg
  RUN cp ../ffmpeg_rtmp_h265/flv*.c ./libavformat/ && \
      cp ../ffmpeg_rtmp_h265/flv.h ./libavformat/
  
  # 修复配置命令
  RUN ./configure \
      --prefix=/opt/ffmpeg \
      --enable-static \
      --disable-shared \
      --disable-hardcoded-tables \
      --pkg-config-flags="--static" \
      --extra-ldflags="-lm -lz -llzma -lpthread" \
      --extra-libs="-lpthread -lm" \
      --enable-libfdk_aac \
      --enable-libfreetype \
      --enable-libmp3lame \
      --enable-libopus \
      --enable-libvpx \
      --enable-encoder=libvpx_vp8 --enable-encoder=libvpx_vp9 --enable-decoder=vp8 --enable-decoder=vp9 --enable-parser=vp8 --enable-parser=vp9 \
      --enable-gpl \
      --enable-libx264 \
      --enable-libx265 \
      --enable-libaom \
      --enable-decoder=h264 \
      --enable-decoder=h265 \
      --enable-decoder=hevc \
      --enable-libass \
      --enable-libfreetype \
      --enable-libfontconfig \
      --enable-libfribidi \
      --enable-libwebp \
      --enable-demuxer=dash \
      --enable-libxml2 \
      --enable-nonfree \
      --enable-openssl
  
  RUN make -j$(nproc) && make install

  # 提取 ffmpeg 所需的动态库, 用于 runtime 阶段
  RUN mkdir -p /opt/ffmpeg-runtime && \
    for lib in $(ldd /opt/ffmpeg/bin/ffmpeg | awk '{print $3}' | grep -E '^/' || true); do \
        cp -v "$lib" /opt/ffmpeg-runtime/; \
    done
  
  # -----------------------
  # STAGE 2: RUNTIME
  # -----------------------
  FROM alpine:3.20 as runtime
  
  # 安装运行时最小依赖（避免缺 libgcc 等基础库）
  RUN apk add --no-cache libgcc libstdc++
  
  # 拷贝 FFmpeg 可执行文件及动态依赖库
  COPY --from=builder /opt/ffmpeg /opt/ffmpeg
  COPY --from=builder /opt/ffmpeg-runtime /usr/lib/
  
  ENV PATH="/opt/ffmpeg/bin:${PATH}"
  
  CMD ["ffmpeg", "-version"]
  
  ENV PATH="/opt/ffmpeg/bin:${PATH}"
  
  CMD ["ffmpeg", "-version"]
  