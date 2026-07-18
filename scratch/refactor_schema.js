const fs = require('fs');
const path = '/Users/arun_ap/Desktop/crackers erp/backend/prisma/schema.prisma';

try {
  let content = fs.readFileSync(path, 'utf8');

  // 1. Update generator
  content = content.replace(/generator client\s*{[^}]+}/, `generator client {\n  provider = "prisma-client-js"\n  previewFeatures = ["multiSchema"]\n}`);

  // 2. Update datasource
  content = content.replace(/datasource db\s*{[^}]+}/, `datasource db {\n  provider = "postgresql"\n  url      = env("DATABASE_URL")\n  schemas  = ["public", "crackers"]\n}`);

  // 3. Add @@schema("crackers") to all models
  content = content.replace(/model\s+\w+\s*{([^}]+)}/g, (match, body) => {
    if (body.includes('@@schema')) return match; // Skip if already there
    
    // Find the last line before the closing brace
    const trimmedBody = body.trimEnd();
    return match.replace(trimmedBody, trimmedBody + '\n  @@schema("crackers")\n');
  });

  fs.writeFileSync(path, content);
  console.log("Schema refactored successfully!");
} catch (e) {
  console.error("Error:", e);
}
