# Building extra binaries needed by 'kubeasz'
# @author:  gjmzj
# @repo:    https://github.com/easzlab/dockerfile-kubeasz-ext-build
# @ref:     https://github.com/easzlab/kubeasz

FROM ubuntu:22.04 AS builder

ENV NGINX_VERSION=1.30.4
ENV CHRONY_VERSION=4.8
ENV CHRONY_DOWNLOAD_URL="https://chrony-project.org/releases/chrony-${CHRONY_VERSION}.tar.gz"
ENV KEEPALIVED_VERSION=2.4.3
ENV KEEPALIVED_DOWNLOAD_URL="http://keepalived.org/software/keepalived-${KEEPALIVED_VERSION}.tar.gz"

RUN set -x; \
    apt-get update && \
    apt-get install --no-install-recommends --no-install-suggests -y \
      ca-certificates \
      build-essential \
      git \
      curl \
      libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl-dev \
      libseccomp-dev \
      libnl-3-dev libnl-genl-3-dev libnfnetlink-dev \
 && curl -o nginx.tar.gz -SL http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz \
 && tar -xzf nginx.tar.gz -C /tmp/ \
 && cd /tmp/nginx-* \
 && ./configure --with-stream \
                --without-http \
                --without-http_uwsgi_module \
                --without-http_scgi_module \
                --without-http_fastcgi_module \
 && make && make install

RUN set -x; \
 cd / \
 && curl -o chrony.tar.gz -SL $CHRONY_DOWNLOAD_URL \
 #&& echo "${CHRONY_SHA256} *chrony.tar.gz" | sha256sum -c - \
 && tar xzf chrony.tar.gz -C /tmp/ \
 && cd /tmp/chrony* \
 && ./configure \
        --without-editline \
        --disable-sechash \
        --disable-nts \
        --disable-ipv6 \
        --disable-privdrop \
        --without-libcap \
        --without-seccomp \
        --disable-cmdmon \
  && make && make install

RUN set -x; \
  cd / \
  && curl -o keepalived.tar.gz -SL $KEEPALIVED_DOWNLOAD_URL \
  && tar xzf keepalived.tar.gz -C /tmp/ \
  && cd /tmp/keepalived* \
  && ./configure \
        --disable-lvs \
		--disable-vrrp-auth \
		--disable-routes \
		--disable-linkbeat \
		--disable-iptables \
		--disable-libipset-dynamic \
		--disable-nftables \
		--disable-hardening \
		--with-init=systemd \
  && make && make install


FROM golang:1.22 as builder2
ENV CFSSL_VER=v1.6.5
RUN set -x \
    && mkdir -p /ext-bin \
    && git config --global advice.detachedHead false \
    && git clone --depth 1 -b ${CFSSL_VER} https://github.com/cloudflare/cfssl.git \
    && cd cfssl \
    && go build -tags 'netgo,osusergo,sqlite_omit_load_extension' -ldflags '-s -w -extldflags "-static"' cmd/cfssl/cfssl.go \
    && go build -tags 'netgo,osusergo,sqlite_omit_load_extension' -ldflags '-s -w -extldflags "-static"' cmd/cfssljson/cfssljson.go \
    && go build -tags 'netgo,osusergo,sqlite_omit_load_extension' -ldflags '-s -w -extldflags "-static"' cmd/cfssl-certinfo/cfssl-certinfo.go \
    && mv cfssljson cfssl-certinfo cfssl /ext-bin


FROM alpine:3.22

ENV EXT_BUILD_VER=1.5.0

COPY --from=builder /usr/local/nginx/sbin/nginx /ext-bin/
COPY --from=builder /usr/local/sbin/chronyd /ext-bin/
COPY --from=builder /usr/local/sbin/keepalived /ext-bin/
COPY --from=builder2 /ext-bin/* /ext-bin/
