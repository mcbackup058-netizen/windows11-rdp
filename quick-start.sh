#!/bin/bash
# Quick Start Script for Windows 11 Pro RDP Edition

set -e

echo "=============================================="
echo "  Windows 11 Pro - RDP Only Edition"
echo "  Quick Start Script"
echo "=============================================="
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed!"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
    echo "WARNING: Docker Compose is not installed!"
    echo "Will use docker build and run instead..."
    USE_COMPOSE=false
else
    USE_COMPOSE=true
fi

# Check KVM
echo "Checking KVM support..."
if [ -e /dev/kvm ]; then
    if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
        echo "✓ KVM is available and accessible"
    else
        echo "⚠ KVM exists but permission denied"
        echo "  Run: sudo usermod -aG kvm \$USER"
        echo "  Then logout and login again"
        read -p "Continue without KVM? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    echo "⚠ KVM is not available"
    echo "  VM will run in emulation mode (slower)"
    read -p "Continue without KVM? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check disk space
echo ""
echo "Checking disk space..."
AVAILABLE=$(df --output=avail -BG . | tail -n 1 | tr -d ' G')
if [ "$AVAILABLE" -lt 80 ]; then
    echo "WARNING: Less than 80GB free space (only ${AVAILABLE}GB available)"
    echo "Windows 11 requires significant disk space"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo "✓ Disk space OK (${AVAILABLE}GB available)"
fi

# Create storage directory
mkdir -p storage

# Ask for customization
echo ""
echo "Configuration (press Enter for defaults):"
read -p "RAM Size [4G]: " RAM_SIZE
RAM_SIZE=${RAM_SIZE:-4G}

read -p "CPU Cores [2]: " CPU_CORES
CPU_CORES=${CPU_CORES:-2}

read -p "Disk Size [64G]: " DISK_SIZE
DISK_SIZE=${DISK_SIZE:-64G}

read -p "Username [Docker]: " USERNAME
USERNAME=${USERNAME:-Docker}

read -p "Password [admin]: " PASSWORD
PASSWORD=${PASSWORD:-admin}

echo ""
echo "Configuration Summary:"
echo "  RAM: $RAM_SIZE"
echo "  CPU: $CPU_CORES cores"
echo "  Disk: $DISK_SIZE"
echo "  Username: $USERNAME"
echo "  Password: $PASSWORD"
echo ""

read -p "Start deployment? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Deploy
echo ""
echo "Starting deployment..."
echo ""

if [ "$USE_COMPOSE" = true ]; then
    # Create custom compose file
    cat > docker-compose.override.yml << EOF
services:
  windows11-rdp:
    environment:
      RAM_SIZE: "$RAM_SIZE"
      CPU_CORES: "$CPU_CORES"
      DISK_SIZE: "$DISK_SIZE"
EOF

    echo "Building and starting container..."
    docker compose up -d --build

    echo ""
    echo "=============================================="
    echo "  Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "Monitor installation:"
    echo "  docker logs -f windows11-rdp"
    echo ""
    echo "Connect via RDP:"
    echo "  Address: localhost:3389"
    echo "  Username: $USERNAME"
    echo "  Password: $PASSWORD"
    echo ""
else
    # Build and run without compose
    echo "Building Docker image..."
    docker build -t windows11-rdp .

    echo "Starting container..."
    docker run -d \
        --name windows11-rdp \
        --device=/dev/kvm \
        --device=/dev/net/tun \
        --cap-add=NET_ADMIN \
        -p 3389:3389/tcp \
        -p 3389:3389/udp \
        -e "RAM_SIZE=$RAM_SIZE" \
        -e "CPU_CORES=$CPU_CORES" \
        -e "DISK_SIZE=$DISK_SIZE" \
        -v "$(pwd)/storage:/storage" \
        windows11-rdp

    echo ""
    echo "=============================================="
    echo "  Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "Monitor installation:"
    echo "  docker logs -f windows11-rdp"
    echo ""
    echo "Connect via RDP:"
    echo "  Address: localhost:3389"
    echo "  Username: $USERNAME"
    echo "  Password: $PASSWORD"
    echo ""
fi

echo "NOTE: Initial installation takes 25-60 minutes"
echo "      depending on internet speed."
echo ""
