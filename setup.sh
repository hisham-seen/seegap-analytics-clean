#!/bin/bash

# SeeGap Analytics - Complete Setup Script
# This script sets up the entire Analytics Loyalty Platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ASCII Art Banner
show_banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
   ____            ____             _                _       _   _          
  / ___|  ___  ___/ ___| __ _ _ __ | |    ___  _   _| | __ _| |_| |_ _   _ 
  \___ \ / _ \/ _ \ |  _ / _` | '_ \| |   / _ \| | | | |/ _` | __| __| | | |
   ___) |  __/  __/ |_| | (_| | |_) | |__| (_) | |_| | | (_| | |_| |_| |_| |
  |____/ \___|\___|\____|\__,_| .__/|_____\___/ \__, |_|\__,_|\__|\__|\__, |
                              |_|               |___/                 |___/ 
                                                                            
     Analytics Platform with Loyalty Rewards - Complete Setup
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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running on macOS or Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]] && [[ "$OSTYPE" != "darwin"* ]]; then
        error "This script requires Linux or macOS"
    fi
    
    # Check required commands
    local required_commands=("curl" "git" "docker" "docker-compose" "node" "npm")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        error "Missing required commands: ${missing_commands[*]}"
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker and try again."
    fi
    
    # Check Node.js version
    local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ $node_version -lt 18 ]]; then
        error "Node.js 18 or higher is required. Current version: $(node --version)"
    fi
    
    success "All prerequisites met"
}

# Setup environment
setup_environment() {
    log "Setting up environment..."
    
    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            cp .env.example .env
            success "Created .env from .env.example"
        else
            error ".env.example file not found"
        fi
    else
        success "Environment file already exists"
    fi
    
    # Generate secure secrets if they're still placeholders
    if grep -q "your_jwt_secret_key_here" .env; then
        local jwt_secret=$(node -e "console.log(require('crypto').randomBytes(64).toString('hex'))")
        sed -i.bak "s/your_jwt_secret_key_here_make_it_long_and_secure/$jwt_secret/" .env
        success "Generated secure JWT secret"
    fi
    
    if grep -q "your_session_secret_key_here" .env; then
        local session_secret=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
        sed -i.bak "s/your_session_secret_key_here/$session_secret/" .env
        success "Generated secure session secret"
    fi
    
    if grep -q "secure_password_123" .env; then
        local db_password=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
        sed -i.bak "s/secure_password_123/$db_password/" .env
        success "Generated secure database password"
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    # Backend dependencies
    if [[ -d backend ]]; then
        log "Installing backend dependencies..."
        cd backend
        npm install
        cd ..
        success "Backend dependencies installed"
    fi
    
    # Frontend dependencies
    if [[ -d frontend ]]; then
        log "Installing frontend dependencies..."
        cd frontend
        npm install
        cd ..
        success "Frontend dependencies installed"
    fi
}

# Setup GitHub repository
setup_github() {
    log "Setting up GitHub repository..."
    
    if command -v gh &> /dev/null; then
        if gh auth status &> /dev/null; then
            info "GitHub CLI is authenticated. Setting up repository..."
            ./scripts/setup-github-repo.sh
        else
            warning "GitHub CLI not authenticated. Skipping GitHub setup."
            echo "To set up GitHub later, run: gh auth login && ./scripts/setup-github-repo.sh"
        fi
    else
        warning "GitHub CLI not installed. Skipping GitHub setup."
        echo "To install GitHub CLI: https://cli.github.com/"
    fi
}

# Setup Cloudflare DNS
setup_cloudflare() {
    log "Setting up Cloudflare DNS..."
    
    if [[ -n "$CLOUDFLARE_API_TOKEN" ]] && [[ "$CLOUDFLARE_API_TOKEN" != "sYY4tjUjUPP0jXFsE89Sfea3VNXw1xIAFf2FGsoT" ]]; then
        info "Cloudflare API token found. Setting up DNS..."
        ./scripts/setup-cloudflare-dns.sh
    else
        warning "Cloudflare API token not configured. Skipping DNS setup."
        echo "To set up DNS later:"
        echo "1. Update CLOUDFLARE_API_TOKEN in .env"
        echo "2. Run: ./scripts/setup-cloudflare-dns.sh"
    fi
}

# Build and start services
start_services() {
    log "Building and starting services..."
    
    # Build Docker images
    docker-compose build
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 30
    
    # Health check
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f http://localhost:4000/health &> /dev/null; then
            success "API is healthy"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            error "API health check failed after $max_attempts attempts"
        fi
        
        log "Waiting for API... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    # Check frontend
    attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f http://localhost:3000 &> /dev/null; then
            success "Frontend is healthy"
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            error "Frontend health check failed after $max_attempts attempts"
        fi
        
        log "Waiting for frontend... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
}

# Display final information
show_completion_info() {
    echo ""
    echo -e "${GREEN}🎉 SeeGap Analytics Setup Complete! 🎉${NC}"
    echo ""
    echo -e "${CYAN}=== Access Your Platform ===${NC}"
    echo ""
    echo -e "📊 ${YELLOW}Dashboard:${NC} http://localhost:3000"
    echo -e "🔌 ${YELLOW}API:${NC} http://localhost:4000"
    echo -e "📈 ${YELLOW}Health Check:${NC} http://localhost:4000/health"
    echo ""
    echo -e "${CYAN}=== Production URLs ===${NC}"
    echo ""
    echo -e "🌐 ${YELLOW}Live Site:${NC} https://loyalty.seegap.com"
    echo -e "🔌 ${YELLOW}API:${NC} https://api.loyalty.seegap.com"
    echo -e "📊 ${YELLOW}Tracking:${NC} https://track.loyalty.seegap.com/track.js"
    echo ""
    echo -e "${CYAN}=== Default Login ===${NC}"
    echo ""
    echo -e "📧 ${YELLOW}Email:${NC} admin@analytics.com"
    echo -e "🔑 ${YELLOW}Password:${NC} admin123"
    echo ""
    echo -e "${CYAN}=== Quick Commands ===${NC}"
    echo ""
    echo -e "📋 ${YELLOW}View logs:${NC} docker-compose logs -f"
    echo -e "📊 ${YELLOW}Monitor:${NC} ./monitor.sh"
    echo -e "🔄 ${YELLOW}Restart:${NC} docker-compose restart"
    echo -e "🛑 ${YELLOW}Stop:${NC} docker-compose down"
    echo -e "🚀 ${YELLOW}Deploy:${NC} ./deploy.sh"
    echo ""
    echo -e "${CYAN}=== Integration Example ===${NC}"
    echo ""
    echo -e "Add this to your website's ${YELLOW}<head>${NC} section:"
    echo ""
    echo -e "${GREEN}<script>"
    echo -e "  window.ANALYTICS_TRACKING_ID = 'DEMO_TRACKING_ID';"
    echo -e "  window.ANALYTICS_API_URL = 'http://localhost:4000';"
    echo -e "</script>"
    echo -e "<script src=\"http://localhost:4000/track.js\" async></script>${NC}"
    echo ""
    echo -e "${CYAN}=== Next Steps ===${NC}"
    echo ""
    echo -e "1. 🔧 Configure your Cloudflare API token in .env"
    echo -e "2. 🌐 Run DNS setup: ./scripts/setup-cloudflare-dns.sh"
    echo -e "3. 🔐 Set up SSL certificates: ./deploy.sh --ssl"
    echo -e "4. 🚀 Deploy to production: ./deploy.sh"
    echo -e "5. 📚 Read the documentation: README.md"
    echo ""
    echo -e "${PURPLE}Happy tracking! 🚀${NC}"
    echo ""
}

# Main setup function
main() {
    show_banner
    
    log "Starting SeeGap Analytics setup..."
    
    check_prerequisites
    setup_environment
    install_dependencies
    setup_github
    setup_cloudflare
    start_services
    show_completion_info
    
    success "Setup completed successfully!"
}

# Handle script arguments
case "$1" in
    --help|-h)
        echo "SeeGap Analytics Setup Script"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --skip-github  Skip GitHub repository setup"
        echo "  --skip-dns     Skip Cloudflare DNS setup"
        echo "  --dev          Development mode (skip production setup)"
        echo ""
        echo "Examples:"
        echo "  $0                    # Full setup"
        echo "  $0 --skip-github     # Setup without GitHub"
        echo "  $0 --dev             # Development setup only"
        exit 0
        ;;
    --skip-github)
        SKIP_GITHUB=true
        ;;
    --skip-dns)
        SKIP_DNS=true
        ;;
    --dev)
        DEV_MODE=true
        ;;
esac

# Run main function
main "$@"
