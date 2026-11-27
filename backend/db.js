const { PrismaClient } = require('@prisma/client');
const { invalidateCache } = require('./middleware/cache');

const prisma = new PrismaClient();

// Auto-invalidate caches on any CUD operation for Master Data
prisma.$use(async (params, next) => {
  const result = await next(params);

  if (['create', 'update', 'delete', 'createMany', 'updateMany', 'deleteMany'].includes(params.action)) {
    if (params.model === 'Consignor') invalidateCache('/api/consignors*');
    if (params.model === 'Consignee') invalidateCache('/api/consignees*');
    if (params.model === 'Vehicle') invalidateCache('/api/vehicles*');
    if (params.model === 'Godown') invalidateCache('/api/godowns*');
    if (params.model === 'UnitMaster') invalidateCache('/api/units*');
  }

  return result;
});

module.exports = prisma;

