#!/bin/bash
################################################################################
# Judge0 Deployment Script for Azure VM (Ubuntu 22.04)
################################################################################

set -e

echo "=================================="
echo "Judge0 Azure VM Deployment Script"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
   echo "Please run as root (use sudo)"
   exit 1
fi

echo "Step 1: Updating system packages..."
apt-get update
apt-get upgrade -y

echo ""
echo "Step 2: Installing required packages..."
apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    unzip

echo ""
echo "Step 3: Installing Docker..."
if ! command -v docker &> /dev/null; then
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    echo "Docker installed successfully"
else
    echo "Docker is already installed"
fi

echo ""
echo "Step 4: Configuring GRUB for cgroups v1 (required for Judge0)..."
if ! grep -q "systemd.unified_cgroup_hierarchy=0" /etc/default/grub; then
    cp /etc/default/grub /etc/default/grub.backup
    sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="systemd.unified_cgroup_hierarchy=0"/' /etc/default/grub
    sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 systemd.unified_cgroup_hierarchy=0"/' /etc/default/grub
    update-grub
    echo "GRUB updated. System will need to reboot after this script completes."
    NEEDS_REBOOT=1
else
    echo "GRUB already configured"
fi

echo ""
echo "Step 5: Setting up Judge0..."
JUDGE0_DIR="/opt/judge0"
mkdir -p $JUDGE0_DIR
cd $JUDGE0_DIR

echo "Deployment directory: $JUDGE0_DIR"

echo ""
echo "Step 6: Configuring firewall..."
if command -v ufw &> /dev/null; then
    ufw allow 2358/tcp
    echo "Firewall configured to allow port 2358"
fi

echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Copy your judge0 project files to: $JUDGE0_DIR"
echo "   (including docker-compose.yml, judge0.conf, etc.)"
echo ""
if [ "$NEEDS_REBOOT" = "1" ]; then
    echo "2. REBOOT THE SYSTEM: sudo reboot"
    echo ""
    echo "3. After reboot, navigate to $JUDGE0_DIR and run:"
else
    echo "2. Navigate to $JUDGE0_DIR and run:"
fi
echo "   cd $JUDGE0_DIR"
echo "   docker compose up -d db redis"
echo "   sleep 10"
echo "   docker compose up -d"
echo ""
echo "4. Access Judge0 at: http://<YOUR-VM-IP>:2358/docs"
echo ""
echo "=================================="
