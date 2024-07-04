ARG NGINX_VERSION=1.25.5
ARG FFMPEG_VERSION=7.0.1
ARG NGINX_RTMP_VERSION=1.2.2-r1
ARG NGINX_VOD_VERSION=1.33

##############################
# Build the NGINX-build image.
FROM alpine:3.20 as build-nginx
ARG NGINX_VERSION
ARG NGINX_RTMP_VERSION
ARG NGINX_VOD_VERSION

# Build dependencies.
RUN apk add --update \
  build-base \
  ca-certificates \
  curl \
  gcc \
  libc-dev \
  libgcc \
  linux-headers \
  make \
  musl-dev \
  openssl \
  openssl-dev \
  pcre \
  pcre-dev \
  pkgconf \
  pkgconfig \
  zlib-dev \
  libxml2-dev \
  libxslt-dev \
  git

# Get nginx source.
RUN cd /tmp && \
  wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz && \
  tar zxf nginx-${NGINX_VERSION}.tar.gz && \
  rm nginx-${NGINX_VERSION}.tar.gz

# Get VOD module
RUN cd /tmp && \
  curl -OLs http://github.com/kaltura/nginx-vod-module/archive/${NGINX_VOD_VERSION}.tar.gz && \
  tar zxf ${NGINX_VOD_VERSION}.tar.gz && rm ${NGINX_VOD_VERSION}.tar.gz

# Get nginx-rtmp module.
RUN cd /tmp && \
  wget https://github.com/sergey-dryabzhinsky/nginx-rtmp-module/archive/refs/tags/v${NGINX_RTMP_VERSION}.tar.gz && \
  tar zxf v${NGINX_RTMP_VERSION}.tar.gz && \
  rm v${NGINX_RTMP_VERSION}.tar.gz

# Get nginx-auth module.
RUN cd /tmp && git clone https://github.com/perusio/nginx-auth-request-module.git

# Compile nginx with nginx-rtmp module.
RUN cd /tmp/nginx-${NGINX_VERSION} && \
  ./configure \
  --prefix=/opt/nginx \
  --add-module=/tmp/nginx-vod-module-${NGINX_VOD_VERSION} \
  --add-module=/tmp/nginx-rtmp-module-${NGINX_RTMP_VERSION} \
  --add-module=/tmp/nginx-auth-request-module \
  --conf-path=/opt/nginx/nginx.conf \
  --with-threads \
  --with-file-aio \
  --with-http_ssl_module \
  --error-log-path=/opt/nginx/logs/error.log \
  --http-log-path=/opt/nginx/logs/access.log \
  --with-debug && \
  cd /tmp/nginx-${NGINX_VERSION} && make CFLAGS="-Wno-error=format-truncation" && make install

##########################
# Build the release image.
FROM vilsol/ffmpeg-alpine as build-ffmpeg
FROM alpine:3.20

ARG LUAJIT_VERSION

RUN apk add --update \
  ca-certificates \
  openssl \
  curl \
  pcre \
  lame \
  libogg \
  libass \
  libvpx \
  libvorbis \
  libwebp \
  libtheora \
  opus \
  rtmpdump \
  x264-dev \
  x265-dev \
  openssl-dev \
  pcre-dev \
  zlib-dev \
  libxml2-dev \
  libxslt-dev

# Copy nginx configs
COPY --from=build-nginx /opt/nginx /opt/nginx
# Copy ffmpeg relations
COPY --from=build-ffmpeg /usr/local /usr/local
COPY --from=build-ffmpeg /root/bin/ffmpeg /bin/ffmpeg
COPY --from=build-ffmpeg /root/bin/ffprobe /bin/ffprobe

# Add NGINX config and static files.
ADD nginx.conf /opt/nginx/nginx.conf
RUN mkdir -p /opt/data && mkdir /www
ADD videos /videos
ADD static /var/www

EXPOSE 1935
EXPOSE 80
EXPOSE 443

CMD ["/opt/nginx/sbin/nginx"]