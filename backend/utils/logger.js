const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

const logApiUsage = async (provider, apiName, status, cost = 0) => {
  try {
    await prisma.apiUsageLog.create({
      data: { provider, apiName, status, cost }
    });
  } catch (err) {
    console.error('Failed to log API usage:', err);
  }
};

module.exports = {
  logApiUsage
};
