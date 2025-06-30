# SeeGap Analytics - Terraform Infrastructure Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Configure the Cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Variables
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "eminent-subset-462023-f9"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "europe-west1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "europe-west1-b"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for seegap.com"
  type        = string
  default     = "758f689c0c7c67dd8e5083aec851f53f"
}

variable "domain" {
  description = "Domain name"
  type        = string
  default     = "loyalty.seegap.com"
}

variable "machine_type" {
  description = "GCP Machine Type"
  type        = string
  default     = "e2-standard-2"
}

# Data sources
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

# Static IP Address
resource "google_compute_address" "analytics_ip" {
  name   = "analytics-static-ip"
  region = var.region
}

# Firewall Rules
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

resource "google_compute_firewall" "allow_https" {
  name    = "allow-https"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["https-server"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-server"]
}

# Startup script for VM
locals {
  startup_script = <<-EOF
#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Nginx
apt-get install -y nginx

# Install Certbot
apt-get install -y certbot python3-certbot-nginx

# Install Git
apt-get install -y git

# Create application directory
mkdir -p /opt/analytics
chown ubuntu:ubuntu /opt/analytics

# Clone repository
cd /opt/analytics
git clone https://github.com/hisham-seen/seegap-analytics-clean.git .
chown -R ubuntu:ubuntu .

# Create environment file
cat > .env << 'ENV_EOF'
# Database Configuration
DB_PASSWORD=${random_password.db_password.result}
DB_HOST=localhost
DB_PORT=5432
DB_NAME=analytics_db
DB_USER=analytics_user

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379

# Application Configuration
NODE_ENV=production
JWT_SECRET=${random_password.jwt_secret.result}
SESSION_SECRET=${random_password.session_secret.result}
API_URL=https://api.${var.domain}
FRONTEND_URL=https://${var.domain}
TRACKING_URL=https://track.${var.domain}

# Cloudflare Configuration
CLOUDFLARE_API_TOKEN=${var.cloudflare_api_token}
CLOUDFLARE_ZONE_ID=${var.cloudflare_zone_id}
DOMAIN=${var.domain}
EMAIL=hisham@seegap.com

# Analytics Configuration
ANALYTICS_RETENTION_DAYS=365
MAX_EVENTS_PER_MINUTE=1000
DEFAULT_LOYALTY_POINTS=10

# Logging Configuration
LOG_LEVEL=info
LOG_FILE=./logs/app.log

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
ENV_EOF

# Configure Nginx
cat > /etc/nginx/sites-available/analytics << 'NGINX_EOF'
server {
    listen 80;
    server_name ${var.domain};

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 80;
    server_name api.${var.domain};

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}

server {
    listen 80;
    server_name track.${var.domain};

    location / {
        proxy_pass http://localhost:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_EOF

# Enable site
ln -sf /etc/nginx/sites-available/analytics /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart nginx
nginx -t
systemctl restart nginx
systemctl enable nginx

# Create systemd service for the application
cat > /etc/systemd/system/seegap-analytics.service << 'SERVICE_EOF'
[Unit]
Description=SeeGap Analytics Platform
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/analytics
ExecStart=/usr/local/bin/docker-compose up -d --build
ExecStop=/usr/local/bin/docker-compose down
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable seegap-analytics.service

# Start the application
cd /opt/analytics
sudo -u ubuntu docker-compose up -d --build

# Setup SSL certificates (will run after DNS is configured)
cat > /opt/setup-ssl.sh << 'SSL_EOF'
#!/bin/bash
sleep 60  # Wait for DNS propagation
certbot --nginx -d ${var.domain} -d api.${var.domain} -d track.${var.domain} --non-interactive --agree-tos --email hisham@seegap.com
systemctl enable certbot.timer
systemctl start certbot.timer
SSL_EOF

chmod +x /opt/setup-ssl.sh
nohup /opt/setup-ssl.sh > /var/log/ssl-setup.log 2>&1 &

# Create monitoring script
cat > /opt/monitor.sh << 'MONITOR_EOF'
#!/bin/bash
echo "=== SeeGap Analytics Platform Status ==="
echo "Date: $(date)"
echo ""
echo "=== Docker Containers ==="
docker-compose -f /opt/analytics/docker-compose.yml ps
echo ""
echo "=== Nginx Status ==="
systemctl status nginx --no-pager -l
echo ""
echo "=== SSL Certificates ==="
certbot certificates
echo ""
echo "=== Disk Usage ==="
df -h
echo ""
echo "=== Memory Usage ==="
free -h
MONITOR_EOF

chmod +x /opt/monitor.sh

echo "SeeGap Analytics Platform setup completed!"
EOF
}

# Random passwords
resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "random_password" "session_secret" {
  length  = 32
  special = true
}

# Compute Instance
resource "google_compute_instance" "analytics_vm" {
  name         = "analytics-vm"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["http-server", "https-server", "ssh-server"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 50
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.analytics_ip.address
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  metadata_startup_script = local.startup_script

  service_account {
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_compute_firewall.allow_http,
    google_compute_firewall.allow_https,
    google_compute_firewall.allow_ssh
  ]
}

# Cloudflare DNS Records
resource "cloudflare_record" "main" {
  zone_id = var.cloudflare_zone_id
  name    = "loyalty"
  content = google_compute_address.analytics_ip.address
  type    = "A"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "api" {
  zone_id = var.cloudflare_zone_id
  name    = "api"
  content = google_compute_address.analytics_ip.address
  type    = "A"
  ttl     = 300
  proxied = true
}

resource "cloudflare_record" "track" {
  zone_id = var.cloudflare_zone_id
  name    = "track"
  content = google_compute_address.analytics_ip.address
  type    = "A"
  ttl     = 300
  proxied = true
}

# Outputs
output "vm_external_ip" {
  description = "External IP address of the VM"
  value       = google_compute_address.analytics_ip.address
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM"
  value       = google_compute_instance.analytics_vm.network_interface[0].network_ip
}

output "main_url" {
  description = "Main application URL"
  value       = "https://${var.domain}"
}

output "api_url" {
  description = "API URL"
  value       = "https://api.${var.domain}"
}

output "tracking_url" {
  description = "Tracking URL"
  value       = "https://track.${var.domain}"
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "gcloud compute ssh analytics-vm --zone=${var.zone}"
}

output "db_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "jwt_secret" {
  description = "JWT secret"
  value       = random_password.jwt_secret.result
  sensitive   = true
}
