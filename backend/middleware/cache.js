const Redis = require('ioredis');

// Initialize Redis Client gracefully
let redis = null;
let redisConnected = false;

if (process.env.REDIS_URL) {
  redis = new Redis(process.env.REDIS_URL, {
    maxRetriesPerRequest: 1, // Don't hang forever if Redis is down
    retryStrategy(times) {
      if (times > 3) {
        console.warn('Redis connection failed after 3 retries. Skipping cache.');
        return null; // Stop retrying
      }
      return Math.min(times * 50, 2000);
    }
  });

  redis.on('connect', () => {
    redisConnected = true;
    console.log('✅ Connected to Redis successfully');
  });

  redis.on('error', (err) => {
    redisConnected = false;
    console.error('❌ Redis Connection Error:', err.message);
  });
} else {
  console.log('⚠️ No REDIS_URL found. Running without caching (Graceful Fallback).');
}

/**
 * Middleware to cache GET requests
 * @param {number} ttlSeconds - Time to live in seconds (default 3600 = 1 hour)
 */
const cacheMiddleware = (ttlSeconds = 3600) => async (req, res, next) => {
  if (!redisConnected || !redis) return next();

  // Only cache GET requests
  if (req.method !== 'GET') return next();

  const key = `cache:${req.originalUrl || req.url}`;
  
  try {
    const cachedData = await redis.get(key);
    
    if (cachedData) {
      // Serve from cache
      return res.json(JSON.parse(cachedData));
    }
    
    // Intercept res.json to save data in cache before sending
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      // Only cache 2xx successful responses
      if (res.statusCode >= 200 && res.statusCode < 300) {
        redis.set(key, JSON.stringify(body), 'EX', ttlSeconds).catch(err => {
          console.error(`Redis Set Error for key ${key}:`, err);
        });
      }
      return originalJson(body);
    };
    
    next();
  } catch (err) {
    console.error(`Redis Get Error for key ${key}:`, err);
    next(); // Fallback to DB if Redis fails
  }
};

/**
 * Helper function to invalidate cache by pattern (e.g. on POST/PUT/DELETE)
 * @param {string} pattern - e.g. '/api/consignors*'
 */
const invalidateCache = async (pattern) => {
  if (!redisConnected || !redis) return;
  
  try {
    const keys = await redis.keys(`cache:${pattern}`);
    if (keys.length > 0) {
      await redis.del(keys);
    }
  } catch (err) {
    console.error(`Redis Invalidate Error for pattern ${pattern}:`, err);
  }
};

module.exports = {
  redis,
  redisConnected,
  cacheMiddleware,
  invalidateCache
};
