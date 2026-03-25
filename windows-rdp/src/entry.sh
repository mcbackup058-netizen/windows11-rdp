#!/usr/bin/env bash
# Windows 11 Pro - RDP Only Entry Script
# Simplified version without web viewer

set -Eeuo pipefail

# Configuration
: "${APP:="Windows 11 Pro"}"
: "${PLATFORM:="x64"}"
: "${BOOT_MODE:="windows_secure"}"
: "${SUPPORT:="https://github.com/dockur/windows"}"

# Hardcoded Windows 11 Pro
VERSION="win11x64"
DETECTED="win11x64"

cd /run

# Source required modules from QEMU base image
if [ -f /run/utils.sh ]; then
    . /run/utils.sh
fi

# Create necessary directories
mkdir -p /run/shm
mkdir -p /storage

# Initialize variables
STORAGE="/storage"
TMP="/storage/tmp"
BOOT="/storage/win11x64.iso"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

info() {
    log "INFO: $*"
}

error() {
    log "ERROR: $*"
}

warn() {
    log "WARN: $*"
}

# Check KVM support
check_kvm() {
    if [ ! -e /dev/kvm ]; then
        warn "KVM not available - running in emulation mode (slower)"
        return 1
    fi

    if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
        warn "KVM permission denied - add user to kvm group"
        return 1
    fi

    info "KVM acceleration enabled"
    return 0
}

# Check disk space
check_disk_space() {
    local required=20000000000  # 20GB minimum
    local available
    available=$(df --output=avail -B 1 "$STORAGE" | tail -n 1)

    if [ "$available" -lt "$required" ]; then
        error "Not enough disk space. Need at least 20GB"
        return 1
    fi

    info "Disk space check passed"
}

# Download Windows 11 Pro ISO
download_windows11() {
    local iso_url="https://software-static.download.prss.microsoft.com/dbazure/888969d5-f34g-4e03-ac9d-1f9786c66749/26200.6584.250915-1905.25h2_ge_release_svc_refresh_CLIENT_CONSUMER_x64FRE_en-us.iso"
    local iso_size=7736125440

    if [ -f "$BOOT" ] && [ -s "$BOOT" ]; then
        info "ISO already exists: $BOOT"
        return 0
    fi

    info "Downloading Windows 11 Pro ISO..."
    info "Size: ~7.2GB - This may take a while..."

    mkdir -p "$TMP"

    # Try multiple mirrors
    local mirrors=(
        "$iso_url"
        "https://dl.bobpony.com/windows/11/en-us_windows_11_24h2_x64.iso"
    )

    for url in "${mirrors[@]}"; do
        info "Trying: $url"
        if wget "$url" -O "$BOOT" --continue -q --timeout=30 --show-progress --progress=bar:noscroll 2>&1; then
            local downloaded
            downloaded=$(stat -c%s "$BOOT" 2>/dev/null || echo "0")
            if [ "$downloaded" -gt 1000000000 ]; then
                info "Download completed successfully"
                return 0
            fi
        fi
        rm -f "$BOOT"
    done

    error "Failed to download Windows 11 Pro ISO"
    return 1
}

# Create virtual disk
create_disk() {
    local disk="${STORAGE}/windows.qcow2"
    local size="${DISK_SIZE:-64G}"

    if [ -f "$disk" ]; then
        info "Virtual disk already exists: $disk"
        return 0
    fi

    info "Creating virtual disk: $disk ($size)"
    qemu-img create -f qcow2 "$disk" "$size"
}

# Prepare ISO with drivers and answer file
prepare_iso() {
    local iso="$BOOT"
    local extracted="$TMP/extracted"
    local output="$TMP/prepared.iso"

    if [ -f "$TMP/prepared.iso" ]; then
        info "Prepared ISO already exists"
        return 0
    fi

    info "Preparing Windows 11 Pro installation..."

    mkdir -p "$extracted"

    # Extract ISO
    info "Extracting ISO..."
    7z x "$iso" -o"$extracted" > /dev/null 2>&1 || {
        error "Failed to extract ISO"
        return 1
    }

    # Extract VirtIO drivers
    info "Adding VirtIO drivers..."
    local drivers="$TMP/drivers"
    mkdir -p "$drivers"
    if [ -f /var/drivers.txz ]; then
        tar -xf /var/drivers.txz -C "$drivers" 2>/dev/null || true
    fi

    # Copy answer file
    info "Adding auto-install configuration..."
    if [ -f /run/assets/win11x64-rdp.xml ]; then
        cp /run/assets/win11x64-rdp.xml "$extracted/autounattend.xml"
    fi

    # Rebuild ISO
    info "Building modified ISO..."
    local etfs="boot/etfsboot.com"
    local efisys="efi/microsoft/boot/efisys_noprompt.bin"

    genisoimage -o "$output" \
        -b "$etfs" -no-emul-boot -c "BOOT.CAT" \
        -iso-level 4 -J -l -D -N -joliet-long \
        -relaxed-filenames -V "WIN11_RDP" \
        -udf -boot-info-table -eltorito-alt-boot \
        -eltorito-boot "$efisys" -no-emul-boot \
        -quiet "$extracted" 2>/dev/null || {
        error "Failed to create ISO"
        return 1
    }

    # Replace original
    mv -f "$output" "$iso.prepared"
    rm -rf "$extracted"

    info "ISO preparation completed"
}

# Start QEMU
start_qemu() {
    local disk="${STORAGE}/windows.qcow2"
    local iso="${BOOT}"

    if [ -f "$TMP/prepared.iso" ]; then
        iso="$TMP/prepared.iso"
    elif [ -f "$BOOT.prepared" ]; then
        iso="$BOOT.prepared"
    fi

    local ram="${RAM_SIZE:-4G}"
    local cores="${CPU_CORES:-2}"
    local machine="q35"

    # QEMU arguments
    local qemu_args=(
        -machine "$machine,accel=kvm:tcg"
        -cpu host
        -m "$ram"
        -smp "$cores"
        -drive "file=$disk,format=qcow2,if=virtio,cache=writeback"
        -drive "file=$iso,media=cdrom"
        -netdev user,id=net0,hostfwd=tcp::3389-:3389
        -device virtio-net-pci,netdev=net0
        -device virtio-gpu-pci
        -display none
        -daemonize
        -pidfile /run/shm/qemu.pid
    )

    # Add TPM for Windows 11
    if [ -c /dev/tpm0 ]; then
        qemu_args+=(-chardev tpm,id=chrtpm,path=/dev/tpm0)
        qemu_args+=(-tpmdev emulator,id=tpm0,chardev=chrtpm)
        qemu_args+=(-device tpm-tis,tpmdev=tpm0)
    fi

    info "Starting Windows 11 Pro VM..."
    info "RAM: $ram | CPU: $cores cores"
    info "RDP will be available on port 3389"

    qemu-system-x86_64 "${qemu_args[@]}"

    info "VM started successfully!"
    info ""
    info "=============================================="
    info "  Windows 11 Pro - RDP Access"
    info "=============================================="
    info ""
    info "  Connect via RDP client:"
    info "  - Address: localhost:3389"
    info "  - Username: Docker"
    info "  - Password: admin"
    info ""
    info "  Wait 5-10 minutes for Windows to install..."
    info "=============================================="
}

# Main entry point
main() {
    info "========================================"
    info "  Windows 11 Pro - RDP Only Edition"
    info "========================================"

    # Run checks
    check_kvm || true
    check_disk_space || exit 1

    # Download Windows 11 Pro
    download_windows11 || exit 1

    # Create virtual disk
    create_disk || exit 1

    # Prepare ISO with drivers and answer file
    prepare_iso || warn "Using original ISO (manual installation may be required)"

    # Start QEMU
    start_qemu

    # Keep container running
    info "Container running. Press Ctrl+C to stop."
    tail -f /dev/null
}

# Run main
main "$@"
