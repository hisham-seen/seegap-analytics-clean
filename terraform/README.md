# SeeGap Analytics - Terraform Infrastructure

This directory contains Terraform configuration for deploying the SeeGap Analytics platform to Google Cloud Platform with Cloudflare DNS management.

## 🏗️ Infrastructure Overview

The Terraform configuration creates:

- **GCP Compute Instance** (e2-standard-2) with Ubuntu 22.04 LTS
- **Static IP Address** for consistent external access
- **Firewall Rules** for HTTP, HTTPS, and SSH traffic
- **Cloudflare DNS Records** for main domain and subdomains
- **Automated SSL Certificates** via Let's Encrypt
- **Docker & Docker Compose** setup
- **Nginx Reverse Proxy** configuration
- **Systemd Service** for application management

## 📋 Prerequisites

### 1. Install Required Tools

```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://developer.hashicorp.com/terraform/downloads

# Install Google Cloud CLI
brew install google-cloud-sdk  # macOS
# or download from https://cloud.google.com/sdk/docs/install
```

### 2. Authentication Setup

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud config set project eminent-subset-462023-f9

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable dns.googleapis.com
```

### 3. SSH Key Setup

```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# The public key should be at ~/.ssh/id_rsa.pub
```

### 4. Configuration Setup

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your values
nano terraform.tfvars
```

## 🚀 Deployment

### Quick Deployment

```bash
# Make the deployment script executable
chmod +x deploy.sh

# Run the deployment
./deploy.sh
```

### Manual Deployment

```bash
# Initialize Terraform
terraform init

# Review the deployment plan
terraform plan

# Apply the configuration
terraform apply
```

## 📊 Infrastructure Components

### Compute Instance
- **Machine Type**: e2-standard-2 (2 vCPUs, 8GB RAM)
- **Disk**: 50GB SSD
- **OS**: Ubuntu 22.04 LTS
- **Zone**: europe-west1-b

### Network Configuration
- **Static IP**: Automatically assigned
- **Firewall**: HTTP (80), HTTPS (443), SSH (22)
- **DNS**: Cloudflare managed records

### Application Stack
- **Frontend**: Next.js on port 3000
- **Backend**: Node.js API on port 4000
- **Database**: PostgreSQL in Docker
- **Cache**: Redis in Docker
- **Proxy**: Nginx with SSL termination

## 🔧 Configuration Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP Project ID | `eminent-subset-462023-f9` |
| `region` | GCP Region | `europe-west1` |
| `zone` | GCP Zone | `europe-west1-b` |
| `cloudflare_api_token` | Cloudflare API Token | Required |
| `cloudflare_zone_id` | Cloudflare Zone ID | `758f689c0c7c67dd8e5083aec851f53f` |
| `domain` | Main domain | `loyalty.seegap.com` |
| `machine_type` | VM machine type | `e2-standard-2` |

## 🌐 DNS Records Created

| Record | Type | Target | Purpose |
|--------|------|--------|---------|
| `loyalty.seegap.com` | A | VM IP | Main dashboard |
| `api.loyalty.seegap.com` | A | VM IP | API endpoint |
| `track.loyalty.seegap.com` | A | VM IP | Tracking script |

## 📈 Monitoring & Management

### Check Deployment Status

```bash
# Get infrastructure outputs
terraform output

# SSH into the VM
terraform output -raw ssh_command

# Check application status
gcloud compute ssh analytics-vm --zone=europe-west1-b --command="/opt/monitor.sh"
```

### Application Management

```bash
# SSH into the VM
gcloud compute ssh analytics-vm --zone=europe-west1-b

# Check Docker containers
sudo docker-compose -f /opt/analytics/docker-compose.yml ps

# View application logs
sudo docker-compose -f /opt/analytics/docker-compose.yml logs -f

# Restart services
sudo systemctl restart seegap-analytics.service

# Check SSL certificates
sudo certbot certificates
```

## 🔒 Security Features

- **Firewall Rules**: Only necessary ports exposed
- **SSL Certificates**: Automatic Let's Encrypt certificates
- **Non-root User**: Application runs as ubuntu user
- **Cloudflare Proxy**: DDoS protection and CDN
- **Secure Secrets**: Random passwords generated by Terraform

## 🛠️ Troubleshooting

### Common Issues

1. **SSH Key Not Found**
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

2. **GCP Authentication**
   ```bash
   gcloud auth login
   gcloud config set project eminent-subset-462023-f9
   ```

3. **Terraform State Issues**
   ```bash
   terraform refresh
   terraform plan
   ```

4. **Application Not Starting**
   ```bash
   # SSH into VM and check logs
   gcloud compute ssh analytics-vm --zone=europe-west1-b
   sudo journalctl -u seegap-analytics.service -f
   ```

### Logs Locations

- **Terraform**: `terraform.log`
- **Application**: `/opt/analytics/logs/`
- **Nginx**: `/var/log/nginx/`
- **SSL Setup**: `/var/log/ssl-setup.log`
- **System**: `journalctl -u seegap-analytics.service`

## 🔄 Updates & Maintenance

### Update Application Code

```bash
# SSH into VM
gcloud compute ssh analytics-vm --zone=europe-west1-b

# Update code
cd /opt/analytics
sudo git pull origin main
sudo docker-compose up -d --build
```

### Update Infrastructure

```bash
# Modify terraform files
# Plan and apply changes
terraform plan
terraform apply
```

### SSL Certificate Renewal

SSL certificates are automatically renewed via systemd timer. Manual renewal:

```bash
# SSH into VM
gcloud compute ssh analytics-vm --zone=europe-west1-b

# Renew certificates
sudo certbot renew
sudo systemctl reload nginx
```

## 💰 Cost Estimation

**Monthly Costs (approximate):**
- **Compute Instance** (e2-standard-2): ~$50/month
- **Static IP**: ~$3/month
- **Disk Storage** (50GB): ~$2/month
- **Network Egress**: Variable based on traffic
- **Total**: ~$55-70/month

## 🗑️ Cleanup

To destroy all infrastructure:

```bash
terraform destroy
```

**Warning**: This will permanently delete all resources and data!

## 📞 Support

For issues with:
- **Terraform**: Check the [Terraform documentation](https://developer.hashicorp.com/terraform/docs)
- **GCP**: Check the [Google Cloud documentation](https://cloud.google.com/docs)
- **Cloudflare**: Check the [Cloudflare documentation](https://developers.cloudflare.com/)

## 🎯 Next Steps

After successful deployment:

1. **Access the platform**: Visit `https://loyalty.seegap.com`
2. **Create admin account**: Register the first user
3. **Add websites**: Configure tracking for client sites
4. **Monitor performance**: Use the built-in monitoring tools
5. **Scale as needed**: Upgrade VM size or add load balancers

---

**🎉 Your SeeGap Analytics platform is now ready for production use!**
