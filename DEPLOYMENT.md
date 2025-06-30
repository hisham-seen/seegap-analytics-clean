# Deployment Guide - SeeGap Analytics Loyalty Platform

This guide covers deploying the SeeGap Analytics Loyalty Platform to Google Cloud Platform (GCP) using GitHub CI/CD.

## Prerequisites

Before deploying, ensure you have the following:

### 1. GCP Setup
- Google Cloud Project with billing enabled
- Project ID: `eminent-subset-462023-f9`
- Required APIs enabled:
  - Compute Engine API
  - Cloud Resource Manager API
  - IAM Service Account Credentials API

### 2. GitHub Repository Setup
- Fork or clone this repository
- Enable GitHub Actions
- Set up the required secrets (see below)

### 3. Domain Setup
- Domain: `seegap.com`
- Cloudflare account with domain management
- DNS records will be automatically configured

## Required GitHub Secrets

Configure the following secrets in your GitHub repository settings:

### GCP Authentication
```
GCP_SERVICE_ACCOUNT_KEY: <JSON key for GCP service account>
```

### SSH Keys
```
SSH_PRIVATE_KEY: <Private SSH key for VM access>
SSH_PUBLIC_KEY: <Public SSH key for VM access>
```

### Cloudflare Configuration
```
CLOUDFLARE_API_TOKEN: <Cloudflare API token with Zone:Edit permissions>
CLOUDFLARE_ZONE_ID: <Zone ID for seegap.com domain>
```

## Deployment Architecture

The deployment consists of:

1. **Infrastructure Layer** (Terraform)
   - GCP Compute Engine VM (e2-standard-2)
   - Static IP address
   - Firewall rules (HTTP, HTTPS, SSH)
   - Cloudflare DNS records

2. **Application Layer** (Docker Compose)
   - Frontend (Next.js)
   - Backend API (Express.js)
   - PostgreSQL Database
   - Redis Cache
   - Background Worker
   - Nginx Reverse Proxy

3. **CI/CD Pipeline** (GitHub Actions)
   - Automated testing
   - Docker image building
   - Infrastructure provisioning
   - Application deployment
   - Security scanning

## Deployment Process

### Automatic Deployment

The deployment is fully automated through GitHub Actions:

1. **Push to main branch** triggers the deployment pipeline
2. **Testing phase** runs unit tests and linting
3. **Build phase** creates Docker images and pushes to GitHub Container Registry
4. **Infrastructure phase** provisions GCP resources using Terraform
5. **Application phase** deploys the application to the VM
6. **Verification phase** runs health checks and purges CDN cache

### Manual Deployment

If you need to deploy manually:

1. **Set up environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Deploy infrastructure:**
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

3. **Deploy application:**
   ```bash
   ./deploy.sh
   ```

## Environment Configuration

### Production URLs
- Main Application: `https://loyalty.seegap.com`
- API Endpoint: `https://api.loyalty.seegap.com`
- Tracking Endpoint: `https://track.loyalty.seegap.com`

### Database Configuration
- PostgreSQL 15 with automatic backups
- Redis 7 for caching and sessions
- Persistent volumes for data storage

### Security Features
- SSL/TLS certificates via Let's Encrypt
- Rate limiting and DDoS protection via Cloudflare
- Security headers and CORS configuration
- Vulnerability scanning with Trivy

## Monitoring and Maintenance

### Health Checks
The application includes built-in health check endpoints:
- Frontend: `https://loyalty.seegap.com/health`
- Backend: `https://api.loyalty.seegap.com/health`

### Logging
- Application logs: `/opt/analytics/logs/`
- Nginx logs: `/var/log/nginx/`
- System logs: `journalctl -u seegap-analytics.service`

### Monitoring Script
Run the monitoring script on the VM:
```bash
sudo /opt/monitor.sh
```

### SSL Certificate Renewal
Certificates are automatically renewed via certbot:
```bash
sudo certbot renew --dry-run
```

## Scaling Considerations

### Vertical Scaling
- Upgrade VM instance type in `terraform/main.tf`
- Adjust resource limits in `docker-compose.yml`

### Horizontal Scaling
- Set up load balancer
- Configure database clustering
- Implement Redis clustering

### Performance Optimization
- Enable Cloudflare caching
- Optimize Docker images
- Configure database connection pooling

## Troubleshooting

### Common Issues

1. **Deployment fails at infrastructure phase:**
   - Check GCP service account permissions
   - Verify Terraform state is not corrupted
   - Ensure quotas are not exceeded

2. **Application fails to start:**
   - Check environment variables
   - Verify database connectivity
   - Review application logs

3. **SSL certificate issues:**
   - Ensure DNS records are properly configured
   - Check Cloudflare proxy settings
   - Verify domain ownership

### Debug Commands

```bash
# Check service status
sudo systemctl status seegap-analytics.service

# View application logs
sudo journalctl -u seegap-analytics.service -f

# Check Docker containers
sudo docker-compose ps
sudo docker-compose logs

# Test connectivity
curl -I https://loyalty.seegap.com
curl -I https://api.loyalty.seegap.com/health
```

## Rollback Procedure

If deployment fails or issues arise:

1. **Rollback application:**
   ```bash
   cd /opt/analytics
   sudo git reset --hard <previous-commit-hash>
   sudo systemctl restart seegap-analytics.service
   ```

2. **Rollback infrastructure:**
   ```bash
   cd terraform
   terraform plan -destroy
   terraform apply -destroy
   ```

## Security Best Practices

1. **Regular Updates:**
   - Keep base images updated
   - Apply security patches promptly
   - Monitor vulnerability reports

2. **Access Control:**
   - Use SSH keys instead of passwords
   - Implement least privilege principle
   - Regular audit of access permissions

3. **Data Protection:**
   - Enable database encryption
   - Regular backups
   - Secure environment variables

## Support

For deployment issues or questions:
- Check the troubleshooting section above
- Review GitHub Actions logs
- Contact: hisham@seegap.com

## License

This deployment configuration is part of the SeeGap Analytics Platform and is subject to the same license terms.
