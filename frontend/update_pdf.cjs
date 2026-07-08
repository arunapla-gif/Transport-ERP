const fs = require('fs');
let content = fs.readFileSync('src/utils/pdfGenerator.js', 'utf8');

// Reduce margins
content = content.replace(/margin: \[0, 0, 0, 8\]/g, "margin: [0, 0, 0, 4]");
content = content.replace(/margin: \[0, 0, 0, 15\]/g, "margin: [0, 0, 0, 6]");

// Reduce row heights
content = content.replace(/heights: \[20, 25, 25, 25\]/g, "heights: [15, 20, 20, 20]");
content = content.replace(/heights: \[20, 20, 20, 20, 25\]/g, "heights: [15, 18, 18, 18, 20]");

// Reduce specific fonts that are too large
content = content.replace(/fontSize: 26/g, "fontSize: 24");
content = content.replace(/fontSize: 24/g, "fontSize: 22");
content = content.replace(/fontSize: 16/g, "fontSize: 14");
content = content.replace(/fontSize: 14/g, "fontSize: 12");
content = content.replace(/margin: \[0, 12, 0, 12\]/g, "margin: [0, 6, 0, 6]"); // Articles padding
content = content.replace(/margin: \[6, 14, 0, 12\]/g, "margin: [6, 8, 0, 6]"); // Desc padding
content = content.replace(/margin: \[0, 0, 0, 35\]/g, "margin: [0, 0, 0, 25]"); // Signature padding

fs.writeFileSync('src/utils/pdfGenerator.js', content);
console.log("pdfGenerator.js shrunk to fit 1 page.");
