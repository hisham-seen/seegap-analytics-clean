(function() {
  'use strict';
  
  // Analytics Loyalty Platform Tracking Script
  // Version 1.0.0
  
  var Analytics = {
    // Configuration
    config: {
      apiUrl: window.ANALYTICS_API_URL || 'http://localhost:4000',
      trackingId: window.ANALYTICS_TRACKING_ID || null,
      debug: window.ANALYTICS_DEBUG || false,
      autoTrack: window.ANALYTICS_AUTO_TRACK !== false,
      loyaltyEnabled: window.ANALYTICS_LOYALTY_ENABLED !== false
    },
    
    // Internal state
    state: {
      visitorId: null,
      sessionId: null,
      pageLoadTime: Date.now(),
      isInitialized: false,
      eventQueue: []
    },
    
    // Initialize the tracking
    init: function(trackingId) {
      if (this.state.isInitialized) {
        return;
      }
      
      this.config.trackingId = trackingId || this.config.trackingId;
      
      if (!this.config.trackingId) {
        this.log('Error: No tracking ID provided');
        return;
      }
      
      // Generate or retrieve visitor ID
      this.state.visitorId = this.getOrCreateVisitorId();
      
      // Generate session ID
      this.state.sessionId = this.generateSessionId();
      
      // Set up event listeners
      this.setupEventListeners();
      
      // Track initial page view if auto-tracking is enabled
      if (this.config.autoTrack) {
        this.trackPageView();
      }
      
      // Process any queued events
      this.processEventQueue();
      
      this.state.isInitialized = true;
      this.log('Analytics initialized', {
        trackingId: this.config.trackingId,
        visitorId: this.state.visitorId,
        sessionId: this.state.sessionId
      });
    },
    
    // Generate or retrieve visitor ID from localStorage
    getOrCreateVisitorId: function() {
      var storageKey = 'analytics_visitor_id';
      var visitorId = localStorage.getItem(storageKey);
      
      if (!visitorId) {
        visitorId = 'visitor_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        localStorage.setItem(storageKey, visitorId);
      }
      
      return visitorId;
    },
    
    // Generate session ID
    generateSessionId: function() {
      return 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    },
    
    // Set up event listeners for automatic tracking
    setupEventListeners: function() {
      var self = this;
      
      // Track page visibility changes
      document.addEventListener('visibilitychange', function() {
        if (document.visibilityState === 'hidden') {
          self.trackEvent('page_hidden', {
            timeOnPage: Date.now() - self.state.pageLoadTime
          });
        } else {
          self.state.pageLoadTime = Date.now();
          self.trackEvent('page_visible');
        }
      });
      
      // Track clicks on links and buttons
      document.addEventListener('click', function(event) {
        var target = event.target;
        var tagName = target.tagName.toLowerCase();
        
        if (tagName === 'a' || tagName === 'button' || target.getAttribute('data-track-click')) {
          self.trackEvent('click', {
            element: tagName,
            text: target.textContent.trim().substring(0, 100),
            href: target.href || null,
            classes: target.className,
            id: target.id
          });
        }
      });
      
      // Track form submissions
      document.addEventListener('submit', function(event) {
        var form = event.target;
        self.trackEvent('form_submit', {
          formId: form.id,
          formClasses: form.className,
          action: form.action
        });
      });
      
      // Track scroll depth
      var maxScrollDepth = 0;
      var scrollTimer = null;
      
      window.addEventListener('scroll', function() {
        clearTimeout(scrollTimer);
        scrollTimer = setTimeout(function() {
          var scrollDepth = Math.round((window.scrollY / (document.body.scrollHeight - window.innerHeight)) * 100);
          if (scrollDepth > maxScrollDepth && scrollDepth <= 100) {
            maxScrollDepth = scrollDepth;
            if (scrollDepth >= 25 && scrollDepth % 25 === 0) {
              self.trackEvent('scroll_depth', {
                depth: scrollDepth
              });
            }
          }
        }, 250);
      });
      
      // Track time on page before unload
      window.addEventListener('beforeunload', function() {
        self.trackEvent('page_unload', {
          timeOnPage: Date.now() - self.state.pageLoadTime,
          scrollDepth: maxScrollDepth
        });
      });
    },
    
    // Track page view
    trackPageView: function(customData) {
      this.trackEvent('page_view', Object.assign({
        title: document.title,
        url: window.location.href,
        referrer: document.referrer,
        userAgent: navigator.userAgent,
        screenResolution: screen.width + 'x' + screen.height,
        viewportSize: window.innerWidth + 'x' + window.innerHeight,
        language: navigator.language,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone
      }, customData || {}));
    },
    
    // Track custom event
    trackEvent: function(eventType, customData) {
      if (!this.state.isInitialized) {
        this.state.eventQueue.push({ eventType: eventType, customData: customData });
        return;
      }
      
      var eventData = {
        trackingId: this.config.trackingId,
        visitorId: this.state.visitorId,
        sessionId: this.state.sessionId,
        eventType: eventType,
        pageUrl: window.location.href,
        pageTitle: document.title,
        referrer: document.referrer,
        timestamp: new Date().toISOString(),
        customData: customData || {}
      };
      
      this.sendEvent(eventData);
    },
    
    // Send event to server
    sendEvent: function(eventData) {
      var self = this;
      
      // Use sendBeacon if available for better reliability
      if (navigator.sendBeacon) {
        var blob = new Blob([JSON.stringify(eventData)], { type: 'application/json' });
        navigator.sendBeacon(this.config.apiUrl + '/track', blob);
      } else {
        // Fallback to fetch/XMLHttpRequest
        fetch(this.config.apiUrl + '/track', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(eventData),
          keepalive: true
        }).catch(function(error) {
          self.log('Error sending event:', error);
        });
      }
      
      this.log('Event sent:', eventData);
    },
    
    // Process queued events
    processEventQueue: function() {
      while (this.state.eventQueue.length > 0) {
        var event = this.state.eventQueue.shift();
        this.trackEvent(event.eventType, event.customData);
      }
    },
    
    // Loyalty system integration
    loyalty: {
      // Get visitor's loyalty points
      getPoints: function(callback) {
        if (!Analytics.config.loyaltyEnabled) {
          callback(null, 0);
          return;
        }
        
        fetch(Analytics.config.apiUrl + '/api/loyalty/points/' + Analytics.state.visitorId)
          .then(function(response) { return response.json(); })
          .then(function(data) {
            callback(null, data.points || 0);
          })
          .catch(function(error) {
            callback(error, 0);
          });
      },
      
      // Get available rewards
      getRewards: function(callback) {
        if (!Analytics.config.loyaltyEnabled) {
          callback(null, []);
          return;
        }
        
        fetch(Analytics.config.apiUrl + '/api/loyalty/rewards/' + Analytics.config.trackingId)
          .then(function(response) { return response.json(); })
          .then(function(data) {
            callback(null, data.rewards || []);
          })
          .catch(function(error) {
            callback(error, []);
          });
      },
      
      // Redeem a reward
      redeemReward: function(rewardId, callback) {
        if (!Analytics.config.loyaltyEnabled) {
          callback(new Error('Loyalty system not enabled'));
          return;
        }
        
        fetch(Analytics.config.apiUrl + '/api/loyalty/redeem', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            visitorId: Analytics.state.visitorId,
            rewardId: rewardId
          })
        })
        .then(function(response) { return response.json(); })
        .then(function(data) {
          callback(null, data);
        })
        .catch(function(error) {
          callback(error);
        });
      }
    },
    
    // Debug logging
    log: function() {
      if (this.config.debug && console && console.log) {
        console.log.apply(console, ['[Analytics]'].concat(Array.prototype.slice.call(arguments)));
      }
    }
  };
  
  // Auto-initialize if tracking ID is provided
  if (window.ANALYTICS_TRACKING_ID) {
    Analytics.init(window.ANALYTICS_TRACKING_ID);
  }
  
  // Expose Analytics object globally
  window.Analytics = Analytics;
  
  // Support for Google Analytics-like syntax
  window.gtag = function() {
    var args = Array.prototype.slice.call(arguments);
    var command = args[0];
    
    if (command === 'config' && args[1]) {
      Analytics.init(args[1]);
    } else if (command === 'event') {
      Analytics.trackEvent(args[1], args[2]);
    }
  };
  
})();
