const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const os = require('os');

const startHealthLogger = () => {
  // Run every 15 minutes (900000 ms)
  setInterval(async () => {
    try {
      const start = Date.now();
      await prisma.$queryRaw`SELECT 1`;
      const dbLatency = Date.now() - start;

      const memoryUsage = process.memoryUsage();
      const memoryMb = Math.round(memoryUsage.rss / 1024 / 1024);
      const cpuLoad = os.loadavg()[0]; // 1-minute load average
      const uptime = Math.floor(process.uptime());

      await prisma.systemHealthLog.create({
        data: {
          memoryMb,
          cpuLoad,
          dbPing: dbLatency,
          uptime
        }
      });
      
      // Cleanup logs older than 7 days to prevent DB bloat
      const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      await prisma.systemHealthLog.deleteMany({
        where: {
          createdAt: {
            lt: sevenDaysAgo
          }
        }
      });
      
      console.log('Health snapshot logged successfully.');
    } catch (err) {
      console.error('Failed to log system health snapshot:', err);
    }
  }, 15 * 60 * 1000);
};

module.exports = { startHealthLogger };
