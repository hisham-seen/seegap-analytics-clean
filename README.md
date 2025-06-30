# SeeGap Analytics - Loyalty Platform

A comprehensive Google Analytics clone with integrated loyalty rewards system, built as a SaaS platform. Website owners can track their analytics while offering customizable loyalty rewards to their visitors.

**Live Demo:** https://loyalty.seegap.com
**API Endpoint:** https://api.loyalty.seegap.com
**Tracking Script:** https://track.loyalty.seegap.com/track.js

## 🚀 Features

### Analytics Dashboard
- **Real-time Analytics**: Live visitor tracking and session monitoring
- **Advanced Metrics**: Page views, unique visitors, bounce rate, conversion funnels
- **Traffic Sources**: Direct, referral, search, social media analysis
- **Geographic Analytics**: Country, region, and city-level insights
- **Device Analytics**: Browser, OS, and device type breakdown
- **Custom Event Tracking**: Track specific user interactions
- **Real-time Dashboard**: Live updates via WebSocket connections

### Loyalty Rewards System
- **Custom Rule Engine**: Website owners configure point-earning rules
- **Flexible Rewards**: Points, discounts, free items, badges, tier upgrades
- **Tier-based System**: Bronze, Silver, Gold, Platinum tiers
- **Visitor Portal**: Dedicated interface for reward redemption
- **Real-time Point Allocation**: Instant rewards for user actions
- **Fraud Detection**: Prevent point gaming and abuse

### SaaS Platform
- **Multi-tenant Architecture**: Isolated data per customer
- **Subscription Management**: Multiple pricing tiers
- **API Access**: RESTful API with comprehensive documentation
- **White-label Options**: Customizable branding for enterprise
- **Team Collaboration**: Multi-user access with role management
- **Billing Integration**: Stripe integration for payments

## 🏗️ Architecture

### Technology Stack

**Frontend:**
- Next.js 14 with TypeScript
- Tailwind CSS for styling
- Chart.js for data visualizations
- Socket.IO for real-time updates
- React Query for state management

**Backend:**
- Node.js with Express.js
- TypeScript for type safety
- PostgreSQL for data storage
- Redis for caching and sessions
- Bull Queue for background jobs
- Socket.IO for real-time features

**Infrastructure:**
- Docker & Docker Compose
- Nginx reverse proxy
- Cloudflare CDN and security
- GitHub Actions CI/CD
- Single VM deployment ready

### System Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Website A     │    │   Website B     │    │   Website C     │
│                 │    │                 │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │     Tracking Script       │
                    │   (JavaScript SDK)        │
                    └─────────────┬─────────────┘
                                 │
                    ┌─────────────▼─────────────┐
                    │      Analytics API        │
                    │    (Express.js)           │
                    └─────────────┬─────────────┘
                                 │
          ┌──────────────────────┼──────────────────────┐
          │                      │                      │
┌─────────▼───────┐    ┌─────────▼───────┐    ┌─────────▼───────┐
│   PostgreSQL    │    │      Redis      │    │   Background    │
│   Database      │    │     Cache       │    │    Workers      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for development)
- Git

### Installation

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/analytics-loyalty-platform.git
cd analytics-loyalty-platform
```

2. **Set up environment variables:**
```bash
cp .env.example .env
# Edit .env with your configuration
```

3. **Start the platform:**
```bash
chmod +x deploy.sh
./deploy.sh
```

4. **Access the application:**
- Frontend Dashboard: http://localhost:3000
- API: http://localhost:4000
- Health Check: http://localhost:4000/health

### Development Setup

1. **Install dependencies:**
```bash
# Backend
cd backend && npm install

# Frontend
cd frontend && npm install
```

2. **Start development servers:**
```bash
# Start all services
npm run dev

# Or start individually
npm run dev:backend
npm run dev:frontend
```

## 📊 Usage

### For Website Owners (SaaS Customers)

1. **Sign up** for an account at your dashboard
2. **Add your website** and get a tracking ID
3. **Install the tracking script** on your website:

```html
<!-- Add before closing </head> tag -->
<script>
  window.ANALYTICS_TRACKING_ID = 'YOUR_TRACKING_ID';
  window.ANALYTICS_API_URL = 'https://api.yourdomain.com';
</script>
<script src="https://track.yourdomain.com/track.js" async></script>
```

4. **Configure loyalty rules** in the dashboard
5. **Set up rewards** for your visitors
6. **Monitor analytics** and loyalty performance

### For Website Visitors

Visitors automatically earn points based on the rules configured by website owners:

- **Page Views**: Earn points for visiting pages
- **Time Spent**: Bonus points for engagement
- **Custom Actions**: Points for specific interactions
- **Tier Progression**: Unlock higher tiers with more points

### API Integration

```javascript
// Track custom events
Analytics.trackEvent('purchase', {
  value: 99.99,
  currency: 'USD',
  items: ['product-1', 'product-2']
});

// Get visitor's loyalty points
Analytics.loyalty.getPoints((error, points) => {
  console.log('Visitor has', points, 'points');
});

// Get available rewards
Analytics.loyalty.getRewards((error, rewards) => {
  console.log('Available rewards:', rewards);
});
```

## 🔧 Configuration

### Environment Variables

Key environment variables to configure:

```bash
# Database
DB_PASSWORD=your_secure_password
DB_HOST=localhost
DB_PORT=5432

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Security
JWT_SECRET=your_jwt_secret_key

# Cloudflare
CLOUDFLARE_API_TOKEN=your_cloudflare_token
CLOUDFLARE_ZONE_ID=your_zone_id

# URLs
API_URL=https://api.yourdomain.com
FRONTEND_URL=https://analytics.yourdomain.com
TRACKING_URL=https://track.yourdomain.com
```

### Loyalty Rules Configuration

Website owners can configure various types of loyalty rules:

```json
{
  "name": "Page View Reward",
  "type": "page_view",
  "points": 1,
  "conditions": {
    "min_time_on_page": 5
  }
}
```

## 🚀 Deployment

### Single VM Deployment (Recommended)

1. **Prepare your server:**
```bash
# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

2. **Clone and deploy:**
```bash
git clone https://github.com/yourusername/analytics-loyalty-platform.git
cd analytics-loyalty-platform
./deploy.sh
```

3. **Set up SSL (optional):**
```bash
export DOMAIN=yourdomain.com
export EMAIL=your@email.com
./deploy.sh --ssl
```

### Production Deployment with CI/CD

The platform includes GitHub Actions for automated deployment:

1. **Set up GitHub Secrets:**
   - `SSH_PRIVATE_KEY`: SSH key for server access
   - `SERVER_HOST`: Your server IP/domain
   - `SERVER_USER`: SSH username
   - `CLOUDFLARE_API_TOKEN`: Cloudflare API token
   - `CLOUDFLARE_ZONE_ID`: Cloudflare zone ID

2. **Push to main branch** to trigger deployment

## 📈 Monitoring

### Built-in Monitoring

```bash
# Check system status
./deploy.sh --status

# Run health checks
./deploy.sh --health

# Monitor resources
./monitor.sh

# View logs
docker-compose logs -f
```

### Performance Metrics

- **Response Times**: API endpoints < 200ms
- **Throughput**: 1000+ events/minute
- **Uptime**: 99.9% availability target
- **Database**: Optimized for analytics workloads

## 🔒 Security

### Security Features

- **Rate Limiting**: API protection against abuse
- **Input Validation**: Comprehensive data validation
- **SQL Injection Protection**: Parameterized queries
- **XSS Prevention**: Content Security Policy
- **HTTPS Everywhere**: SSL/TLS encryption
- **Data Encryption**: Encrypted data at rest

### Privacy Compliance

- **GDPR Ready**: Data anonymization options
- **Cookie Consent**: Configurable consent management
- **Data Retention**: Configurable retention policies
- **Right to Deletion**: User data removal tools

## 🧪 Testing

### Running Tests

```bash
# Backend tests
cd backend && npm test

# Frontend tests
cd frontend && npm test

# Integration tests
npm run test:integration

# Performance tests
npm run test:performance
```

### Test Coverage

- Unit tests for all core functions
- Integration tests for API endpoints
- End-to-end tests for user workflows
- Performance tests for scalability

## 📚 API Documentation

### Authentication

```bash
# Get access token
POST /api/auth/login
{
  "email": "user@example.com",
  "password": "password"
}
```

### Analytics Endpoints

```bash
# Track event
POST /track
{
  "trackingId": "TRACK_123",
  "eventType": "page_view",
  "pageUrl": "https://example.com/page",
  "visitorId": "visitor_123",
  "sessionId": "session_456"
}

# Get analytics data
GET /api/analytics/dashboard?period=30d
Authorization: Bearer <token>
```

### Loyalty Endpoints

```bash
# Get visitor points
GET /api/loyalty/points/:visitorId

# Redeem reward
POST /api/loyalty/redeem
{
  "visitorId": "visitor_123",
  "rewardId": "reward_456"
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

### Development Guidelines

- Follow TypeScript best practices
- Write tests for new features
- Update documentation
- Follow conventional commit messages

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [docs.yourdomain.com](https://docs.yourdomain.com)
- **Issues**: [GitHub Issues](https://github.com/yourusername/analytics-loyalty-platform/issues)
- **Email**: support@yourdomain.com
- **Discord**: [Join our community](https://discord.gg/yourinvite)

## 🗺️ Roadmap

### Version 2.0
- [ ] Mobile SDK for iOS/Android
- [ ] Advanced ML-powered insights
- [ ] A/B testing framework
- [ ] Advanced segmentation
- [ ] Webhook integrations

### Version 3.0
- [ ] Multi-language support
- [ ] Advanced fraud detection
- [ ] Custom dashboard builder
- [ ] Enterprise SSO integration
- [ ] Advanced reporting engine

---

**Built with ❤️ by [Hisham Sait](mailto:hisham@seen.ie)**

*Transform your website analytics with the power of loyalty rewards!*
