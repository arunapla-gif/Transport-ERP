const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function fixGdms() {
  const gdms = await prisma.gDM.findMany({
    include: {
      gcs: true
    }
  });

  let updatedCount = 0;
  for (const gdm of gdms) {
    if (!gdm.gdmNumber.startsWith('AP-') && !gdm.gdmNumber.startsWith('BELL-')) {
      let inferredPrefix = 'AP-'; // Default
      if (gdm.gcs.length > 0) {
        if (gdm.gcs[0].gcNumber.startsWith('AP-')) inferredPrefix = 'AP-';
        if (gdm.gcs[0].gcNumber.startsWith('BELL-')) inferredPrefix = 'BELL-';
      }
      
      const newGdmNumber = `${inferredPrefix}${gdm.gdmNumber}`;
      console.log(`Fixing GDM ${gdm.id}: ${gdm.gdmNumber} -> ${newGdmNumber}`);
      
      await prisma.gDM.update({
        where: { id: gdm.id },
        data: { gdmNumber: newGdmNumber }
      });
      updatedCount++;
    }
  }

  console.log(`Successfully fixed ${updatedCount} GDMs.`);
}

fixGdms().catch(console.error).finally(() => prisma.$disconnect());
