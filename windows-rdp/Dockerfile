# syntax=docker/dockerfile:1
# Windows 11 Pro - RDP Only Edition
# Modified from dockur/windows - Simplified for RDP-only access

ARG VERSION_ARG="latest"
FROM scratch AS build-amd64

# Copy QEMU base image
COPY --from=qemux/qemu:7.29 / /

ARG TARGETARCH
ARG DEBCONF_NOWARNINGS="yes"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBCONF_NONINTERACTIVE_SEEN="true"

# Install only essential packages (no web viewer dependencies)
RUN set -eu && \
    apt-get update && \
    apt-get --no-install-recommends -y install \
        wimtools \
        cabextract \
        libxml2-utils \
        libarchive-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy scripts
COPY --chmod=755 ./src /run/

# Copy Windows 11 Pro answer file
COPY --chmod=755 ./assets /run/assets

# Download VirtIO drivers
ADD --chmod=664 https://github.com/qemus/virtiso-whql/releases/download/v1.9.53-0/virtio-win-1.9.53.tar.xz /var/drivers.txz

FROM build-${TARGETARCH}

ARG VERSION_ARG="0.00"
RUN echo "$VERSION_ARG" > /run/version

# Storage volume
VOLUME /storage

# RDP Port Only (no web viewer)
EXPOSE 3389/tcp
EXPOSE 3389/udp

# Hardcoded settings for Windows 11 Pro
ENV VERSION="win11x64"
ENV RAM_SIZE="4G"
ENV CPU_CORES="2"
ENV DISK_SIZE="64G"
ENV BOOT_MODE="windows_secure"

# No web viewer - RDP only
ENV DISABLE_WEBVIEW="Y"

ENTRYPOINT ["/usr/bin/tini", "-s", "/run/entry.sh"]
