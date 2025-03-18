#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Update and install dependencies
echo "Updating system and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl

# Install Prometheus
echo "Installing Prometheus..."
sudo useradd --no-create-home --shell /bin/false prometheus
sudo mkdir -p /etc/prometheus /var/lib/prometheus
cd /tmp
PROM_VERSION=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
wget https://github.com/prometheus/prometheus/releases/download/v$PROM_VERSION/prometheus-$PROM_VERSION.linux-amd64.tar.gz
tar xvf prometheus-$PROM_VERSION.linux-amd64.tar.gz
cd prometheus-$PROM_VERSION.linux-amd64
sudo mv prometheus promtool /usr/local/bin/
sudo mv consoles console_libraries prometheus.yml /etc/prometheus/
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Create Prometheus systemd service
echo "Configuring Prometheus service..."
echo "[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file=/etc/prometheus/prometheus.yml \\
    --storage.tsdb.path=/var/lib/prometheus \\
    --web.console.templates=/etc/prometheus/consoles \\
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/prometheus.service

sudo systemctl daemon-reload
sudo systemctl enable --now prometheus

# Install Node Exporter
echo "Installing Node Exporter..."
cd /tmp
NODE_VERSION=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep tag_name | cut -d '"' -f 4 | sed 's/v//')
wget https://github.com/prometheus/node_exporter/releases/download/v$NODE_VERSION/node_exporter-$NODE_VERSION.linux-amd64.tar.gz
tar xvf node_exporter-$NODE_VERSION.linux-amd64.tar.gz
cd node_exporter-$NODE_VERSION.linux-amd64
sudo mv node_exporter /usr/local/bin/

# Create Node Exporter systemd service
echo "Configuring Node Exporter service..."
echo "[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=root
Group=root
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/node_exporter.service

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter

# Install NVIDIA DCGM Exporter
echo "Installing NVIDIA DCGM Exporter..."
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt update
sudo apt install -y datacenter-gpu-manager
wget https://developer.download.nvidia.com/compute/redist/dcgm-exporter/dcgm-exporter_3.2.0-1_amd64.deb
sudo dpkg -i dcgm-exporter_3.2.0-1_amd64.deb
sudo systemctl enable --now dcgm-exporter

# Configure Prometheus to scrape Node Exporter and DCGM Exporter
echo "Configuring Prometheus scrape jobs..."
echo "scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
  - job_name: 'dcgm_exporter'
    static_configs:
      - targets: ['localhost:9400']" | sudo tee /etc/prometheus/prometheus.yml

sudo systemctl restart prometheus

echo "Installation complete!"
echo "Prometheus is running at http://<VM-IP>:9090"
echo "Node Exporter is running at http://<VM-IP>:9100/metrics"
echo "DCGM Exporter is running at http://<VM-IP>:9400/metrics"
