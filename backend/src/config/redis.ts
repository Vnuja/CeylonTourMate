// CeylonTourMate — Redis Client
import Redis from 'ioredis';

let redisClient: Redis | null = null;

export function createRedisClient(): Redis {
  if (redisClient) return redisClient;

  const host = process.env.REDIS_HOST || 'localhost';
  const port = parseInt(process.env.REDIS_PORT || '6379');
  const password = process.env.REDIS_PASSWORD || undefined;

  redisClient = new Redis({
    host,
    port,
    password,
    maxRetriesPerRequest: 3,
    retryStrategy: (times) => {
      if (times > 5) {
        console.warn('⚠️  Redis retry limit reached');
        return null; // stop retrying
      }
      return Math.min(times * 200, 2000);
    },
    lazyConnect: true,
  });

  redisClient.on('connect', () => console.log('✅ Redis connected'));
  redisClient.on('error', (err) => console.warn('⚠️  Redis error:', err.message));

  return redisClient;
}

export function getRedisClient(): Redis | null {
  return redisClient;
}
