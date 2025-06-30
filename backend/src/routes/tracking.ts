import { Router, Request, Response } from 'express';
import { trackingRateLimiter } from '@/middleware/rateLimiter';
import { asyncHandler } from '@/middleware/errorHandler';
import { logger } from '@/utils/logger';

const router = Router();

// Apply rate limiting to tracking endpoints
router.use(trackingRateLimiter);

// Track page view or custom event
router.post('/track', asyncHandler(async (req: Request, res: Response) => {
  try {
    const {
      trackingId,
      eventType = 'page_view',
      pageUrl,
      pageTitle,
      referrer,
      sessionId,
      visitorId,
      customData = {}
    } = req.body;

    // Basic validation
    if (!trackingId || !pageUrl || !sessionId || !visitorId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: trackingId, pageUrl, sessionId, visitorId'
      });
    }

    // Extract user agent and IP information
    const userAgent = req.get('User-Agent') || '';
    const ipAddress = req.ip || req.connection.remoteAddress || '';

    // Log the tracking event for now (will be processed by background worker)
    logger.info('Tracking event received:', {
      trackingId,
      eventType,
      pageUrl,
      pageTitle,
      referrer,
      sessionId,
      visitorId,
      userAgent,
      ipAddress,
      customData
    });

    // TODO: Queue this event for processing
    // await trackingQueue.add('process-event', eventData);

    res.status(200).json({
      success: true,
      message: 'Event tracked successfully'
    });

  } catch (error) {
    logger.error('Tracking error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to track event'
    });
  }
}));

// Health check for tracking service
router.get('/track/health', (_req: Request, res: Response) => {
  res.status(200).json({
    success: true,
    service: 'tracking',
    timestamp: new Date().toISOString()
  });
});

export default router;
