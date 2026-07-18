const fs = require('fs');
const babel = require('@babel/core');

const content = fs.readFileSync('/Users/arun_ap/Desktop/TRANSPORT ERP/frontend/src/pages/GdmEntry.jsx', 'utf8');

try {
  babel.parseSync(content, {
    presets: ['@babel/preset-react'],
    filename: 'GdmEntry.jsx'
  });
  console.log("Parse successful!");
} catch (e) {
  console.log("Parse failed:", e.message);
}
