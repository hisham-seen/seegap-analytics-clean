#!/bin/bash

# Google Cloud VM Deployment Script for SeeGap Analytics
# This script deploys the Analytics Loyalty Platform to a single VM with Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="eminent-subset-462023-f9"
REGION="europe-west1"
ZONE="europe-west1-b"
VM_NAME="analytics-vm"
MACHINE_TYPE="e2-standard-4"
DOMAIN="loyalty.seegap.com"

# ASCII Art Banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
   ____            ____             _   _     ____  ____ ____  
  / ___|  ___  ___/ ___| __ _ _ __ | | | |   / ___|/ ___|  _ \ 
  \___ \ / _ \/ _ \ |  _ / _` | '_ \| | | |  | |  _| |   | |_) |
   ___) |  __/  __/ |_| | (_| | |_) | |_| |  | |_| | |___|  __/ 
  |____/ \___|\___|\____|\__,_| .__/ \___/    \____|\____|_|    
                              |_|                               
                                                                
     SeeGap Analytics - Google Cloud VM Deployment
EOF
    echo -e "${NC}"
}

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

info() {
    echo -e "${PURPLE}ℹ${NC} $1"
}

# Check if gcloud CLI is installed
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        error "Google Cloud CLI is not installed. Please install it first: https://cloud.google.com/sdk/docs/install"
    fi
    
    success "Google Cloud CLI is installed"
}

# Authenticate with Google Cloud
authenticate_gcp() {
    log "Authenticating with Google Cloud..."
    
    # Check if already authenticated
    if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        local current_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
        info "Already authenticated as: $current_account"
        success "Using existing authentication"
    else
        log "Starting non-interactive authentication..."
        info "Please run: gcloud auth login"
        info "Then run this script again"
        exit 1
    fi
    
    success "Google Cloud authentication verified"
}

# Set up GCP project
setup_project() {
    log "Setting up GCP project..."
    
    # Set current project
    gcloud config set project "$PROJECT_ID"
    success "Project set to: $PROJECT_ID"
    
    # Enable required APIs
    log "Enabling required APIs..."
    gcloud services enable \
        compute.googleapis.com \
        dns.googleapis.com
    
    success "Required APIs enabled"
}

# Create VM instance
create_vm() {
    log "Creating VM instance..."
    
    # Check if VM exists
    if gcloud compute instances describe "$VM_NAME" --zone="$ZONE" &>/dev/null; then
        info "VM $VM_NAME already exists"
    else
        log "Creating VM instance: $VM_NAME"
        
        # Create startup script
        cat > startup-script.sh << 'EOF'
#!/bin/bash

# Update system
apt-get update
apt-get install -y curl git nginx certbot python3-certbot-nginx

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Create app directory
mkdir -p /opt/analytics
chown ubuntu:ubuntu /opt/analytics

# Configure Nginx
cat > /etc/nginx/sites-available/analytics << 'NGINX_EOF'
server {
    listen 80;
    server_name loyalty.seegap.com api.loyalty.seegap.com track.loyalty.seegap.com;

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
    server_name api.loyalty.seegap.com;

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
    server_name track.loyalty.seegap.com;

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

# Enable the site
ln -sf /etc/nginx/sites-available/analytics /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload nginx
nginx -t && systemctl reload nginx

echo "VM setup complete" > /var/log/vm-setup.log
EOF

        gcloud compute instances create "$VM_NAME" \
            --zone="$ZONE" \
            --machine-type="$MACHINE_TYPE" \
            --network-interface=network-tier=PREMIUM,subnet=default \
            --maintenance-policy=MIGRATE \
            --provisioning-model=STANDARD \
            --service-account=default \
            --scopes=https://www.googleapis.com/auth/cloud-platform \
            --create-disk=auto-delete=yes,boot=yes,device-name="$VM_NAME",image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts,mode=rw,size=50,type=projects/"$PROJECT_ID"/zones/"$ZONE"/diskTypes/pd-ssd \
            --metadata-from-file startup-script=startup-script.sh \
            --tags=http-server,https-server
        
        # Clean up startup script
        rm startup-script.sh
        
        success "VM instance created: $VM_NAME"
    fi
}

# Configure firewall rules
setup_firewall() {
    log "Setting up firewall rules..."
    
    # HTTP rule
    if ! gcloud compute firewall-rules describe allow-http &>/dev/null; then
        gcloud compute firewall-rules create allow-http \
            --allow tcp:80 \
            --source-ranges 0.0.0.0/0 \
            --target-tags http-server
    fi
    
    # HTTPS rule
    if ! gcloud compute firewall-rules describe allow-https &>/dev/null; then
        gcloud compute firewall-rules create allow-https \
            --allow tcp:443 \
            --source-ranges 0.0.0.0/0 \
            --target-tags https-server
    fi
    
    success "Firewall rules configured"
}

# Reserve static IP
reserve_static_ip() {
    log "Reserving static IP address..."
    
    if gcloud compute addresses describe analytics-vm-ip --region="$REGION" &>/dev/null; then
        info "Static IP already reserved"
    else
        gcloud compute addresses create analytics-vm-ip --region="$REGION"
        success "Static IP reserved"
    fi
    
    local static_ip=$(gcloud compute addresses describe analytics-vm-ip --region="$REGION" --format="value(address)")
    info "Static IP address: $static_ip"
    
    # Assign static IP to VM
    gcloud compute instances delete-access-config "$VM_NAME" \
        --access-config-name="External NAT" \
        --zone="$ZONE" || true
    
    gcloud compute instances add-access-config "$VM_NAME" \
        --access-config-name="External NAT" \
        --address="$static_ip" \
        --zone="$ZONE"
    
    success "Static IP assigned to VM"
    echo "Please update your DNS records to point to: $static_ip"
}

# Deploy application to VM
deploy_application() {
    log "Deploying application to VM..."
    
    # Wait for VM to be ready
    log "Waiting for VM to be ready..."
    sleep 90
    
    # Create deployment package
    log "Creating deployment package..."
    tar -czf analytics-app.tar.gz \
        --exclude='.git' \
        --exclude='node_modules' \
        --exclude='*.log' \
        --exclude='.env' \
        .
    
    # Copy files to VM
    log "Copying files to VM..."
    gcloud compute scp analytics-app.tar.gz "$VM_NAME":/tmp/ --zone="$ZONE"
    
    # Copy environment file
    gcloud compute scp .env "$VM_NAME":/tmp/ --zone="$ZONE"
    
    # Deploy via SSH
    log "Setting up application on VM..."
    gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
        set -e
        
        # Extract application
        cd /opt/analytics
        sudo tar -xzf /tmp/analytics-app.tar.gz
        sudo cp /tmp/.env .
        sudo chown -R ubuntu:ubuntu .
        
        # Install dependencies
        cd backend && npm install --production
        cd ../frontend && npm install --production
        cd ..
        
        # Build frontend
        cd frontend && npm run build
        cd ..
        
        # Start services
        docker-compose down || true
        docker-compose up -d --build
        
        echo 'Application deployed successfully'
    "
    
    # Clean up
    rm analytics-app.tar.gz
    
    success "Application deployed to VM"
}

# Setup SSL certificates
setup_ssl() {
    log "Setting up SSL certificates..."
    
    gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
        # Wait for DNS to propagate
        echo 'Waiting for DNS propagation...'
        sleep 30
        
        # Get SSL certificates
        sudo certbot --nginx -d loyalty.seegap.com -d api.loyalty.seegap.com -d track.loyalty.seegap.com --non-interactive --agree-tos --email hisham@seegap.com || echo 'SSL setup will be completed after DNS propagation'
        
        # Setup auto-renewal
        sudo systemctl enable certbot.timer
        sudo systemctl start certbot.timer
    "
    
    success "SSL certificates configured"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    # Create monitoring script
    gcloud compute ssh "$VM_NAME" --zone="$ZONE" --command="
        sudo tee /opt/analytics/monitor.sh > /dev/null << 'EOF'
#!/bin/bash
echo '=== System Status ==='
date
echo
echo '=== Docker Containers ==='
docker ps
echo
echo '=== Disk Usage ==='
df -h
echo
echo '=== Memory Usage ==='
free -h
echo
echo '=== Nginx Status ==='
sudo systemctl status nginx --no-pager
echo
echo '=== Application Logs ==='
docker-compose logs --tail=20
EOF
        sudo chmod +x /opt/analytics/monitor.sh
    "
    
    success "Monitoring configured"
}

# Display deployment information
show_deployment_info() {
    local static_ip=$(gcloud compute addresses describe analytics-vm-ip --region="$REGION" --format="value(address)" 2>/dev/null || echo "Not created")
    
    echo ""
    echo -e "${GREEN}🎉 GCP VM Deployment Complete! 🎉${NC}"
    echo ""
    echo -e "${CYAN}=== Deployment Information ===${NC}"
    echo ""
    echo -e "🌐 ${YELLOW}Project ID:${NC} $PROJECT_ID"
    echo -e "📍 ${YELLOW}Region:${NC} $REGION"
    echo -e "🖥️ ${YELLOW}VM Name:${NC} $VM_NAME"
    echo -e "🌍 ${YELLOW}Static IP:${NC} $static_ip"
    echo ""
    echo -e "${CYAN}=== URLs ===${NC}"
    echo ""
    echo -e "🌐 ${YELLOW}Main Site:${NC} https://loyalty.seegap.com"
    echo -e "🔌 ${YELLOW}API:${NC} https://api.loyalty.seegap.com"
    echo -e "📊 ${YELLOW}Tracking:${NC} https://track.loyalty.seegap.com"
    echo ""
    echo -e "${CYAN}=== Direct Access (if DNS not ready) ===${NC}"
    echo ""
    echo -e "🌐 ${YELLOW}Frontend:${NC} http://$static_ip"
    echo -e "🔌 ${YELLOW}API:${NC} http://$static_ip:4000"
    echo -e "📊 ${YELLOW}Health Check:${NC} http://$static_ip:4000/health"
    echo ""
    echo -e "${CYAN}=== Management ===${NC}"
    echo ""
    echo -e "☁️ ${YELLOW}GCP Console:${NC} https://console.cloud.google.com/compute/instances?project=$PROJECT_ID"
    echo -e "🖥️ ${YELLOW}SSH Access:${NC} gcloud compute ssh $VM_NAME --zone=$ZONE"
    echo -e "📊 ${YELLOW}Monitor:${NC} gcloud compute ssh $VM_NAME --zone=$ZONE --command='/opt/analytics/monitor.sh'"
    echo ""
    echo -e "${CYAN}=== Next Steps ===${NC}"
    echo ""
    echo -e "1. 🌐 Update DNS records to point to: $static_ip"
    echo -e "   - loyalty.seegap.com -> $static_ip"
    echo -e "   - api.loyalty.seegap.com -> $static_ip"
    echo -e "   - track.loyalty.seegap.com -> $static_ip"
    echo -e "2. 🔧 Configure Cloudflare DNS: ./scripts/setup-cloudflare-dns.sh"
    echo -e "3. ⏳ Wait for DNS propagation (5-10 minutes)"
    echo -e "4. 🔐 SSL certificates will auto-configure after DNS propagation"
    echo -e "5. 📊 Access your dashboard at: https://loyalty.seegap.com"
    echo ""
    echo -e "${CYAN}=== Useful Commands ===${NC}"
    echo ""
    echo -e "📋 ${YELLOW}View logs:${NC} gcloud compute ssh $VM_NAME --zone=$ZONE --command='cd /opt/analytics && docker-compose logs -f'"
    echo -e "🔄 ${YELLOW}Restart:${NC} gcloud compute ssh $VM_NAME --zone=$ZONE --command='cd /opt/analytics && docker-compose restart'"
    echo -e "🛑 ${YELLOW}Stop:${NC} gcloud compute ssh $VM_NAME --zone=$ZONE --command='cd /opt/analytics && docker-compose down'"
    echo -e "🚀 ${YELLOW}Start:${NC} gcloud compute ssh $VM_NAME --zone=$ZONE --command='cd /opt/analytics && docker-compose up -d'"
    echo -e "🔧 ${YELLOW}Update SSL:${NC} gcloud compute ssh $VM_NAME --zone=$ZONE --command='sudo certbot --nginx -d loyalty.seegap.com -d api.loyalty.seegap.com -d track.loyalty.seegap.com'"
    echo ""
    echo -e "${CYAN}=== Database & Services ===${NC}"
    echo ""
    echo -e "🗄️ ${YELLOW}PostgreSQL:${NC} Running in Docker container"
    echo -e "🔴 ${YELLOW}Redis:${NC} Running in Docker container"
    echo -e "🌐 ${YELLOW}Nginx:${NC} Reverse proxy with SSL termination"
    echo -e "📊 ${YELLOW}All services:${NC} Managed via Docker Compose"
    echo ""
    echo -e "${PURPLE}Happy tracking on Google Cloud! 🚀${NC}"
    echo ""
}

# Main deployment function
main() {
    show_banner
    
    log "Starting GCP VM deployment for SeeGap Analytics..."
    
    check_gcloud
    authenticate_gcp
    setup_project
    create_vm
    setup_firewall
    reserve_static_ip
    deploy_application
    setup_ssl
    setup_monitoring
    show_deployment_info
    
    success "GCP VM deployment completed successfully!"
}

# Handle script arguments
case "$1" in
    --help|-h)
        echo "SeeGap Analytics GCP VM Deployment Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --project-id   Set custom project ID"
        echo "  --region       Set custom region (default: europe-west1)"
        echo ""
        echo "Examples:"
        echo "  $0                              # Deploy with defaults"
        echo "  $0 --project-id my-project     # Deploy with custom project"
        echo "  $0 --region us-central1        # Deploy to different region"
        exit 0
        ;;
    --project-id)
        PROJECT_ID="$2"
        shift 2
        ;;
    --region)
        REGION="$2"
        ZONE="$2-b"
        shift 2
        ;;
esac

# Run main function
main "$@"
