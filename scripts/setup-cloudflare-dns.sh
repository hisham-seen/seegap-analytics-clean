#!/bin/bash

# Cloudflare DNS Setup Script for loyalty.seegap.com
# This script sets up DNS records for the Analytics Loyalty Platform

set -e

# Load environment variables
if [[ -f .env ]]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check required environment variables
check_env() {
    log "Checking environment variables..."
    
    if [[ -z "$CLOUDFLARE_API_TOKEN" ]]; then
        error "CLOUDFLARE_API_TOKEN is not set"
    fi
    
    if [[ -z "$CLOUDFLARE_ZONE_ID" ]]; then
        warning "CLOUDFLARE_ZONE_ID is not set. Will attempt to find it automatically."
    fi
    
    if [[ -z "$DOMAIN" ]]; then
        error "DOMAIN is not set"
    fi
    
    success "Environment variables checked"
}

# Get zone ID if not provided
get_zone_id() {
    if [[ -z "$CLOUDFLARE_ZONE_ID" ]]; then
        log "Getting zone ID for seegap.com..."
        
        ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=seegap.com" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" | \
            jq -r '.result[0].id')
        
        if [[ "$ZONE_ID" == "null" || -z "$ZONE_ID" ]]; then
            error "Could not find zone ID for seegap.com"
        fi
        
        CLOUDFLARE_ZONE_ID="$ZONE_ID"
        success "Found zone ID: $CLOUDFLARE_ZONE_ID"
        
        # Update .env file with zone ID
        if grep -q "CLOUDFLARE_ZONE_ID=" .env; then
            sed -i.bak "s/CLOUDFLARE_ZONE_ID=.*/CLOUDFLARE_ZONE_ID=$CLOUDFLARE_ZONE_ID/" .env
        else
            echo "CLOUDFLARE_ZONE_ID=$CLOUDFLARE_ZONE_ID" >> .env
        fi
        success "Updated .env file with zone ID"
    fi
}

# Create DNS record
create_dns_record() {
    local name="$1"
    local type="$2"
    local content="$3"
    local proxied="$4"
    
    log "Creating DNS record: $name.$DOMAIN -> $content"
    
    # Check if record already exists
    existing_record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records?name=$name.seegap.com" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.result[0].id // empty')
    
    if [[ -n "$existing_record" ]]; then
        log "Updating existing DNS record: $name.seegap.com"
        
        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$existing_record" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{
                \"type\": \"$type\",
                \"name\": \"$name\",
                \"content\": \"$content\",
                \"proxied\": $proxied
            }")
    else
        log "Creating new DNS record: $name.seegap.com"
        
        response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{
                \"type\": \"$type\",
                \"name\": \"$name\",
                \"content\": \"$content\",
                \"proxied\": $proxied
            }")
    fi
    
    # Check if request was successful
    success_status=$(echo "$response" | jq -r '.success')
    if [[ "$success_status" == "true" ]]; then
        success "DNS record created/updated: $name.seegap.com"
    else
        error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        error "Failed to create DNS record: $error_msg"
    fi
}

# Get server IP address
get_server_ip() {
    log "Getting server IP address..."
    
    # Try to get public IP
    SERVER_IP=$(curl -s https://ipv4.icanhazip.com || curl -s https://api.ipify.org || echo "")
    
    if [[ -z "$SERVER_IP" ]]; then
        warning "Could not automatically detect server IP"
        read -p "Please enter your server IP address: " SERVER_IP
    fi
    
    if [[ -z "$SERVER_IP" ]]; then
        error "Server IP address is required"
    fi
    
    success "Server IP: $SERVER_IP"
}

# Setup DNS records
setup_dns_records() {
    log "Setting up DNS records for loyalty.seegap.com..."
    
    # Main domain - loyalty.seegap.com
    create_dns_record "loyalty" "A" "$SERVER_IP" "true"
    
    # API subdomain - api.loyalty.seegap.com
    create_dns_record "api.loyalty" "A" "$SERVER_IP" "true"
    
    # Tracking subdomain - track.loyalty.seegap.com
    create_dns_record "track.loyalty" "A" "$SERVER_IP" "true"
    
    success "All DNS records created successfully!"
}

# Configure Cloudflare settings
configure_cloudflare_settings() {
    log "Configuring Cloudflare settings..."
    
    # Enable Always Use HTTPS
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/always_use_https" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}' > /dev/null
    
    # Enable Auto Minify
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/minify" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"value":{"css":"on","html":"on","js":"on"}}' > /dev/null
    
    # Enable Brotli compression
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/brotli" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"value":"on"}' > /dev/null
    
    # Set Security Level to Medium
    curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings/security_level" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"value":"medium"}' > /dev/null
    
    success "Cloudflare settings configured"
}

# Create page rules for optimization
create_page_rules() {
    log "Creating Cloudflare page rules..."
    
    # Page rule for tracking script - high cache
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/pagerules" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
            "targets": [{"target": "url", "constraint": {"operator": "matches", "value": "track.loyalty.seegap.com/track.js"}}],
            "actions": [
                {"id": "cache_level", "value": "cache_everything"},
                {"id": "edge_cache_ttl", "value": 3600},
                {"id": "browser_cache_ttl", "value": 3600}
            ],
            "priority": 1,
            "status": "active"
        }' > /dev/null
    
    # Page rule for API - bypass cache
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/pagerules" \
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{
            "targets": [{"target": "url", "constraint": {"operator": "matches", "value": "api.loyalty.seegap.com/api/*"}}],
            "actions": [
                {"id": "cache_level", "value": "bypass"}
            ],
            "priority": 2,
            "status": "active"
        }' > /dev/null
    
    success "Page rules created"
}

# Display DNS information
display_dns_info() {
    echo ""
    echo "=== DNS Configuration Complete ==="
    echo ""
    echo "Domain Configuration:"
    echo "  Main Site: https://loyalty.seegap.com"
    echo "  API: https://api.loyalty.seegap.com"
    echo "  Tracking: https://track.loyalty.seegap.com"
    echo ""
    echo "DNS Records Created:"
    echo "  loyalty.seegap.com -> $SERVER_IP (Proxied)"
    echo "  api.loyalty.seegap.com -> $SERVER_IP (Proxied)"
    echo "  track.loyalty.seegap.com -> $SERVER_IP (Proxied)"
    echo ""
    echo "Cloudflare Features Enabled:"
    echo "  ✓ Always Use HTTPS"
    echo "  ✓ Auto Minify (CSS, HTML, JS)"
    echo "  ✓ Brotli Compression"
    echo "  ✓ Security Level: Medium"
    echo "  ✓ Page Rules for Optimization"
    echo ""
    echo "Next Steps:"
    echo "  1. Wait 5-10 minutes for DNS propagation"
    echo "  2. Run: ./deploy.sh --ssl"
    echo "  3. Deploy the application: ./deploy.sh"
    echo ""
}

# Main function
main() {
    log "Starting Cloudflare DNS setup for loyalty.seegap.com"
    
    check_env
    get_zone_id
    get_server_ip
    setup_dns_records
    configure_cloudflare_settings
    create_page_rules
    display_dns_info
    
    success "Cloudflare DNS setup completed successfully!"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    error "jq is required but not installed. Please install jq first."
fi

# Run main function
main "$@"
