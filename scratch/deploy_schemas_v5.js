const { execSync } = require('child_process');

// Push Transport ERP Schema
console.log("Pushing Transport ERP schema...");
try {
  execSync('npx -y prisma@5.22.0 db push --schema="./backend/prisma/schema.prisma"', { stdio: 'inherit' });
  console.log("Transport ERP schema pushed successfully.");
} catch (e) {
  console.error("Error pushing Transport schema");
}

// Push Crackers ERP Schema
console.log("Pushing Crackers ERP schema...");
try {
  execSync('export DATABASE_URL="postgresql://postgres.gqfpfnqepdkletbbhwcx:IevuJqEtZ8V1eKhz@aws-1-ap-south-1.pooler.supabase.com:5432/postgres" && npx -y prisma@5.22.0 db push --schema="/Users/arun_ap/Desktop/crackers erp/backend/prisma/schema.prisma"', { stdio: 'inherit' });
  console.log("Crackers ERP schema pushed successfully.");
} catch (e) {
  console.error("Error pushing Crackers schema");
}
