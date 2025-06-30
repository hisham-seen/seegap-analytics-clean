import { Router, Request, Response } from 'express';
import { Pool } from 'pg';
import Redis from 'redis';

const router = Router();

// Health check endpoint
router.get('/health', async (_req: Request, res: Response) => {
  const healthCheck = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: process.env.NODE_ENV || 'development',
    version: process.env.npm_package_version || '1.0.0',
    services: {
      database: 'unknown',
      redis: 'unknown',
      memory: {
        used: process.memoryUsage().heapUsed,
        total: process.memoryUsage().heapTotal,
        external: process.memoryUsage().external,
        rss: process.memoryUsage().rss
      },
      cpu: process.cpuUsage()
    }
  };

  try {
    // Check database connection
    const dbConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'analytics_db',
      user: process.env.DB_USER || 'analytics_user',
      password: process.env.DB_PASSWORD || 'secure_password_123',
    };

    const pool = new Pool(dbConfig);
    await pool.query('SELECT NOW()');
    healthCheck.services.database = 'healthy';
    await pool.end();
  } catch (error) {
    healthCheck.services.database = 'unhealthy';
    healthCheck.status = 'degraded';
  }

  try {
    // Check Redis connection
    const redisClient = Redis.createClient({
      socket: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
      }
    });

    await redisClient.connect();
    await redisClient.ping();
    healthCheck.services.redis = 'healthy';
    await redisClient.disconnect();
  } catch (error) {
    healthCheck.services.redis = 'unhealthy';
    healthCheck.status = 'degraded';
  }

  // Set appropriate status code
  const statusCode = healthCheck.status === 'ok' ? 200 : 503;
  
  res.status(statusCode).json(healthCheck);
});

// Readiness check endpoint
router.get('/ready', async (_req: Request, res: Response) => {
  try {
    // Check if all critical services are available
    const dbConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_NAME || 'analytics_db',
      user: process.env.DB_USER || 'analytics_user',
      password: process.env.DB_PASSWORD || 'secure_password_123',
    };

    const pool = new Pool(dbConfig);
    await pool.query('SELECT 1');
    await pool.end();

    const redisClient = Redis.createClient({
      socket: {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379'),
      }
    });

    await redisClient.connect();
    await redisClient.ping();
    await redisClient.disconnect();

    res.status(200).json({
      status: 'ready',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
      error: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// Liveness check endpoint
router.get('/live', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'alive',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

export default router;
