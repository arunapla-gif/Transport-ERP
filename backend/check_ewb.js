const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function run() {
  const gcs = await prisma.gC.findMany({
    where: { ewbNumber: { not: null, not: "" } },
    orderBy: { id: 'desc' },
    take: 1
  });
  gcs.forEach(gc => {
    if (gc.ewbRawData) {
      console.log(Object.keys(gc.ewbRawData));
      console.log(gc.ewbRawData.company);
    }
  });
}
run();
