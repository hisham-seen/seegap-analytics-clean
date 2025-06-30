#!/bin/bash

# Analytics Loyalty Platform Deployment Script
# This script handles deployment to a single VM with Docker Compose

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="analytics-loyalty-platform"
BACKUP_DIR="./backups"
LOG_FILE="./logs/deploy.log"

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root for security reasons"
    fi
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    command -v docker >/dev/null 2>&1 || error "Docker is not installed"
    command -v docker-compose >/dev/null 2>&1 || error "Docker Compose is not installed"
    command -v git >/dev/null 2>&1 || error "Git is not installed"
    
    # Check if user is in docker group
    if ! groups $USER | grep &>/dev/null '\bdocker\b'; then
        error "User $USER is not in the docker group. Run: sudo usermod -aG docker $USER"
    fi
    
    success "All dependencies are installed"
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    
    mkdir -p logs
    mkdir -p uploads
    mkdir -p backups
    mkdir -p nginx/ssl
    
    success "Directories created"
}

# Setup environment file
setup_environment() {
    log "Setting up environment configuration..."
    
    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            cp .env.example .env
            warning "Created .env from .env.example. Please update the values before continuing."
            echo "Edit .env file with your configuration:"
            echo "  - Database passwords"
            echo "  - JWT secrets"
            echo "  - API keys"
            echo "  - Domain names"
            read -p "Press Enter after updating .env file..."
        else
            error ".env.example file not found"
        fi
    fi
    
    success "Environment configuration ready"
}

# Backup existing data
backup_data() {
    log "Creating backup of existing data..."
    
    if docker-compose ps | grep -q "Up"; then
        BACKUP_FILE="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        # Create database backup
        docker-compose exec -T postgres pg_dump -U analytics_user analytics_db > "$BACKUP_DIR/db_backup_$(date +%Y%m%d_%H%M%S).sql"
        
        # Create Redis backup
        docker-compose exec -T redis redis-cli BGSAVE
        docker cp analytics_redis:/data/dump.rdb "$BACKUP_DIR/redis_backup_$(date +%Y%m%d_%H%M%S).rdb"
        
        # Create full backup
        tar -czf "$BACKUP_FILE" logs uploads
        
        success "Backup created: $BACKUP_FILE"
    else
        warning "No running containers found, skipping backup"
    fi
}

# Pull latest code
update_code() {
    log "Updating code from repository..."
    
    if [[ -d .git ]]; then
        git fetch origin
        git pull origin main
        success "Code updated from repository"
    else
        warning "Not a git repository, skipping code update"
    fi
}

# Build and deploy
deploy() {
    log "Starting deployment..."
    
    # Stop existing containers
    log "Stopping existing containers..."
    docker-compose down
    
    # Remove old images (optional)
    if [[ "$1" == "--clean" ]]; then
        log "Removing old Docker images..."
        docker system prune -f
        docker-compose build --no-cache
    else
        # Build new images
        log "Building Docker images..."
        docker-compose build
    fi
    
    # Start services
    log "Starting services..."
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 30
    
    # Health checks
    health_check
    
    success "Deployment completed successfully!"
}

# Health checks
health_check() {
    log "Running health checks..."
    
    # Check if containers are running
    if ! docker-compose ps | grep -q "Up"; then
        error "Some containers are not running"
    fi
    
    # Check API health
    for i in {1..30}; do
        if curl -f http://localhost:4000/health >/dev/null 2>&1; then
            success "API is healthy"
            break
        fi
        if [[ $i -eq 30 ]]; then
            error "API health check failed"
        fi
        sleep 2
    done
    
    # Check frontend
    for i in {1..30}; do
        if curl -f http://localhost:3000 >/dev/null 2>&1; then
            success "Frontend is healthy"
            break
        fi
        if [[ $i -eq 30 ]]; then
            error "Frontend health check failed"
        fi
        sleep 2
    done
    
    # Check database
    if docker-compose exec -T postgres pg_isready -U analytics_user >/dev/null 2>&1; then
        success "Database is healthy"
    else
        error "Database health check failed"
    fi
    
    # Check Redis
    if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
        success "Redis is healthy"
    else
        error "Redis health check failed"
    fi
}

# Setup SSL certificates (Let's Encrypt)
setup_ssl() {
    log "Setting up SSL certificates..."
    
    if [[ -z "$DOMAIN" ]]; then
        warning "DOMAIN environment variable not set, skipping SSL setup"
        return
    fi
    
    # Install certbot if not present
    if ! command -v certbot >/dev/null 2>&1; then
        log "Installing certbot..."
        sudo apt update
        sudo apt install -y certbot
    fi
    
    # Generate certificates
    sudo certbot certonly --standalone -d "$DOMAIN" -d "api.$DOMAIN" -d "track.$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive
    
    # Copy certificates to nginx directory
    sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./nginx/ssl/
    sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./nginx/ssl/
    sudo chown $USER:$USER ./nginx/ssl/*
    
    success "SSL certificates configured"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    # Create monitoring script
    cat > monitor.sh << 'EOF'
#!/bin/bash
# System monitoring script

echo "=== System Resources ==="
free -h
df -h
echo ""

echo "=== Docker Containers ==="
docker-compose ps
echo ""

echo "=== Service Health ==="
curl -s http://localhost:4000/health | jq .
echo ""

echo "=== Database Status ==="
docker-compose exec -T postgres pg_stat_activity -c "SELECT count(*) as active_connections FROM pg_stat_activity;"
echo ""

echo "=== Redis Status ==="
docker-compose exec -T redis redis-cli info memory | grep used_memory_human
EOF

    chmod +x monitor.sh
    
    # Setup log rotation
    sudo tee /etc/logrotate.d/analytics-platform > /dev/null << EOF
./logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
    
    success "Monitoring configured"
}

# Cleanup old backups
cleanup_backups() {
    log "Cleaning up old backups..."
    
    # Keep only last 7 days of backups
    find "$BACKUP_DIR" -name "*.sql" -mtime +7 -delete
    find "$BACKUP_DIR" -name "*.rdb" -mtime +7 -delete
    find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
    
    success "Old backups cleaned up"
}

# Show status
show_status() {
    echo ""
    echo "=== Analytics Loyalty Platform Status ==="
    echo ""
    
    echo "Services:"
    docker-compose ps
    echo ""
    
    echo "URLs:"
    echo "  Frontend: http://localhost:3000"
    echo "  API: http://localhost:4000"
    echo "  Health Check: http://localhost:4000/health"
    echo ""
    
    echo "Logs:"
    echo "  Application: ./logs/"
    echo "  Docker: docker-compose logs -f"
    echo ""
    
    echo "Management:"
    echo "  Monitor: ./monitor.sh"
    echo "  Backup: ./deploy.sh --backup"
    echo "  Update: ./deploy.sh --update"
    echo ""
}

# Main deployment function
main() {
    log "Starting Analytics Loyalty Platform deployment"
    
    case "$1" in
        --backup)
            backup_data
            ;;
        --update)
            update_code
            deploy
            ;;
        --clean)
            check_root
            check_dependencies
            create_directories
            setup_environment
            backup_data
            update_code
            deploy --clean
            setup_monitoring
            cleanup_backups
            show_status
            ;;
        --ssl)
            setup_ssl
            ;;
        --status)
            show_status
            ;;
        --health)
            health_check
            ;;
        *)
            check_root
            check_dependencies
            create_directories
            setup_environment
            backup_data
            update_code
            deploy
            setup_monitoring
            cleanup_backups
            show_status
            ;;
    esac
    
    success "Deployment script completed"
}

# Run main function with all arguments
main "$@"
