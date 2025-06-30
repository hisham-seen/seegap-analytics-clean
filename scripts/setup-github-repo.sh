#!/bin/bash

# GitHub Repository Setup Script for Analytics Loyalty Platform
# This script creates and configures the GitHub repository

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

# Configuration
REPO_NAME="analytics-loyalty-platform"
REPO_DESCRIPTION="SeeGap Analytics with integrated loyalty rewards system - SaaS platform"
REPO_OWNER="hisham-seen"  # Update this to your GitHub username

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

# Check if GitHub CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        error "GitHub CLI (gh) is not installed. Please install it first: https://cli.github.com/"
    fi
    
    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        log "GitHub CLI not authenticated. Please run: gh auth login"
        exit 1
    fi
    
    success "GitHub CLI is installed and authenticated"
}

# Initialize git repository
init_git_repo() {
    log "Initializing Git repository..."
    
    if [[ ! -d .git ]]; then
        git init
        success "Git repository initialized"
    else
        success "Git repository already exists"
    fi
    
    # Set up git config if not set
    if [[ -z "$(git config user.name)" ]]; then
        git config user.name "Hisham Sait"
        git config user.email "hisham@seegap.com"
        success "Git user configuration set"
    fi
}

# Create GitHub repository
create_github_repo() {
    log "Creating GitHub repository..."
    
    # Check if repository already exists
    if gh repo view "$REPO_OWNER/$REPO_NAME" &> /dev/null; then
        warning "Repository $REPO_OWNER/$REPO_NAME already exists"
        return
    fi
    
    # Create repository
    gh repo create "$REPO_NAME" \
        --description "$REPO_DESCRIPTION" \
        --public \
        --clone=false \
        --add-readme=false
    
    success "GitHub repository created: https://github.com/$REPO_OWNER/$REPO_NAME"
}

# Add remote origin
add_remote_origin() {
    log "Adding remote origin..."
    
    # Remove existing origin if it exists
    if git remote get-url origin &> /dev/null; then
        git remote remove origin
    fi
    
    # Add new origin
    git remote add origin "https://github.com/$REPO_OWNER/$REPO_NAME.git"
    success "Remote origin added"
}

# Create and push initial commit
create_initial_commit() {
    log "Creating initial commit..."
    
    # Add all files
    git add .
    
    # Create initial commit
    git commit -m "🚀 Initial commit: Analytics Loyalty Platform

- Complete Google Analytics clone with loyalty rewards
- SaaS platform with multi-tenant architecture
- Real-time analytics dashboard with Next.js
- Express.js API with PostgreSQL and Redis
- Docker Compose deployment ready
- Cloudflare CDN integration
- GitHub Actions CI/CD pipeline
- Comprehensive documentation

Features:
✅ Real-time visitor tracking
✅ Custom loyalty rules engine
✅ Reward redemption system
✅ Multi-tier loyalty program
✅ Advanced analytics metrics
✅ JavaScript tracking SDK
✅ Production-ready deployment"

    success "Initial commit created"
}

# Push to GitHub
push_to_github() {
    log "Pushing to GitHub..."
    
    # Set upstream and push
    git branch -M main
    git push -u origin main
    
    success "Code pushed to GitHub"
}

# Set up repository settings
setup_repo_settings() {
    log "Configuring repository settings..."
    
    # Enable issues and projects
    gh repo edit "$REPO_OWNER/$REPO_NAME" \
        --enable-issues \
        --enable-projects \
        --enable-wiki
    
    # Add topics
    gh repo edit "$REPO_OWNER/$REPO_NAME" \
        --add-topic "analytics" \
        --add-topic "loyalty" \
        --add-topic "saas" \
        --add-topic "tracking" \
        --add-topic "dashboard" \
        --add-topic "rewards" \
        --add-topic "nextjs" \
        --add-topic "nodejs" \
        --add-topic "postgresql" \
        --add-topic "redis" \
        --add-topic "docker" \
        --add-topic "cloudflare"
    
    success "Repository settings configured"
}

# Create repository secrets for GitHub Actions
setup_github_secrets() {
    log "Setting up GitHub Actions secrets..."
    
    # Note: These need to be set manually or via GitHub CLI with proper values
    cat << EOF

=== GitHub Secrets Setup Required ===

Please set up the following secrets in your GitHub repository:
https://github.com/$REPO_OWNER/$REPO_NAME/settings/secrets/actions

Required Secrets:
1. SSH_PRIVATE_KEY - SSH private key for server access
2. SERVER_HOST - Your server IP or domain
3. SERVER_USER - SSH username for server
4. CLOUDFLARE_API_TOKEN - $CLOUDFLARE_API_TOKEN
5. CLOUDFLARE_ZONE_ID - (will be auto-detected by DNS script)
6. SLACK_WEBHOOK_URL - (optional) Slack webhook for notifications

To set secrets via CLI:
gh secret set SSH_PRIVATE_KEY < ~/.ssh/id_rsa
gh secret set SERVER_HOST --body "your-server-ip"
gh secret set SERVER_USER --body "your-username"
gh secret set CLOUDFLARE_API_TOKEN --body "$CLOUDFLARE_API_TOKEN"
gh secret set SLACK_WEBHOOK_URL --body "your-slack-webhook-url"

EOF

    warning "GitHub secrets need to be configured manually"
}

# Create development branch
create_dev_branch() {
    log "Creating development branch..."
    
    git checkout -b develop
    git push -u origin develop
    
    # Set develop as default branch for PRs
    gh repo edit "$REPO_OWNER/$REPO_NAME" --default-branch develop
    
    success "Development branch created and set as default"
}

# Create issue templates
create_issue_templates() {
    log "Creating issue templates..."
    
    mkdir -p .github/ISSUE_TEMPLATE
    
    # Bug report template
    cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Environment:**
 - OS: [e.g. iOS]
 - Browser [e.g. chrome, safari]
 - Version [e.g. 22]

**Additional context**
Add any other context about the problem here.
EOF

    # Feature request template
    cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature request
about: Suggest an idea for this project
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is. Ex. I'm always frustrated when [...]

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions or features you've considered.

**Additional context**
Add any other context or screenshots about the feature request here.
EOF

    success "Issue templates created"
}

# Create pull request template
create_pr_template() {
    log "Creating pull request template..."
    
    cat > .github/pull_request_template.md << 'EOF'
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] New tests added for new functionality
- [ ] Manual testing completed

## Checklist
- [ ] Code follows the project's style guidelines
- [ ] Self-review of code completed
- [ ] Code is commented, particularly in hard-to-understand areas
- [ ] Documentation updated if needed
- [ ] No new warnings introduced

## Screenshots (if applicable)
Add screenshots to help explain your changes.
EOF

    success "Pull request template created"
}

# Display repository information
display_repo_info() {
    echo ""
    echo "=== GitHub Repository Setup Complete ==="
    echo ""
    echo "Repository Information:"
    echo "  URL: https://github.com/$REPO_OWNER/$REPO_NAME"
    echo "  Clone: git clone https://github.com/$REPO_OWNER/$REPO_NAME.git"
    echo "  SSH: git clone git@github.com:$REPO_OWNER/$REPO_NAME.git"
    echo ""
    echo "Branches:"
    echo "  main - Production branch"
    echo "  develop - Development branch (default)"
    echo ""
    echo "Features Configured:"
    echo "  ✓ Repository created and configured"
    echo "  ✓ Initial commit pushed"
    echo "  ✓ Development workflow setup"
    echo "  ✓ Issue and PR templates"
    echo "  ✓ Topics and settings configured"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure GitHub Actions secrets (see above)"
    echo "  2. Set up your server for deployment"
    echo "  3. Run DNS setup: ./scripts/setup-cloudflare-dns.sh"
    echo "  4. Deploy: ./deploy.sh"
    echo ""
    echo "GitHub Actions will automatically:"
    echo "  ✓ Run tests on pull requests"
    echo "  ✓ Build and deploy on main branch"
    echo "  ✓ Security scanning"
    echo "  ✓ Performance testing"
    echo ""
}

# Main function
main() {
    log "Starting GitHub repository setup for Analytics Loyalty Platform"
    
    check_gh_cli
    init_git_repo
    create_github_repo
    add_remote_origin
    create_initial_commit
    push_to_github
    setup_repo_settings
    create_dev_branch
    create_issue_templates
    create_pr_template
    
    # Add and commit the new templates
    git add .github/
    git commit -m "📝 Add GitHub templates and workflows

- Issue templates for bugs and features
- Pull request template
- GitHub Actions workflow for CI/CD"
    git push
    
    setup_github_secrets
    display_repo_info
    
    success "GitHub repository setup completed successfully!"
}

# Run main function
main "$@"
