const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcryptjs');

const prisma = new PrismaClient();

async function run() {
  console.log('--- STARTING BCRYPT PIN MIGRATION ---');
  
  try {
    const users = await prisma.user.findMany();
    let migratedCount = 0;
    
    for (const user of users) {
      if (!user.pin.startsWith('$2a$') && !user.pin.startsWith('$2b$')) {
        // Plaintext PIN, let's hash it
        console.log(`Hashing PIN for user: ${user.username}`);
        const hashedPin = bcrypt.hashSync(user.pin, 10);
        
        await prisma.user.update({
          where: { id: user.id },
          data: { pin: hashedPin }
        });
        migratedCount++;
      } else {
        console.log(`User ${user.username} is already hashed. Skipping.`);
      }
    }
    
    console.log(`--- MIGRATION COMPLETE: Migrated ${migratedCount} users ---`);
  } catch (error) {
    console.error('Migration failed:', error);
  } finally {
    await prisma.$disconnect();
    process.exit(0);
  }
}

run();
