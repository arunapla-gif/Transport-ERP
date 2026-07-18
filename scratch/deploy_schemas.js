const fs = require('fs');
const { execSync } = require('child_process');

// 1. Update Crackers ERP .env
const crackersEnvPath = '/Users/arun_ap/Desktop/crackers erp/backend/.env';
let crackersEnv = fs.readFileSync(crackersEnvPath, 'utf8');
crackersEnv = crackersEnv.replace(/DATABASE_URL="[^"]+"/, 'DATABASE_URL="postgresql://postgres:IevuJqEtZ8V1eKhz@db.gqfpfnqepdkletbbhwcx.supabase.co:5432/postgres"');
fs.writeFileSync(crackersEnvPath, crackersEnv);
console.log("Updated Crackers ERP .env");

// 2. Push Transport ERP Schema
console.log("Pushing Transport ERP schema...");
try {
  execSync('npx prisma db push --schema="./backend/prisma/schema.prisma"', { stdio: 'inherit' });
  console.log("Transport ERP schema pushed successfully.");
} catch (e) {
  console.error("Error pushing Transport schema");
}

// 3. Push Crackers ERP Schema
console.log("Pushing Crackers ERP schema...");
try {
  // We need to set the DATABASE_URL in the environment for prisma to pick it up properly if we run from outside
  execSync('export DATABASE_URL="postgresql://postgres:IevuJqEtZ8V1eKhz@db.gqfpfnqepdkletbbhwcx.supabase.co:5432/postgres" && npx prisma db push --schema="/Users/arun_ap/Desktop/crackers erp/backend/prisma/schema.prisma"', { stdio: 'inherit' });
  console.log("Crackers ERP schema pushed successfully.");
} catch (e) {
  console.error("Error pushing Crackers schema");
}
