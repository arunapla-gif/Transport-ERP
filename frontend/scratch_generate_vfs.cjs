const fs = require('fs');
const path = require('path');

const fonts = [
  { path: '/System/Library/Fonts/Supplemental/Times New Roman.ttf', name: 'Times New Roman.ttf' },
  { path: '/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf', name: 'Times New Roman Bold.ttf' },
  { path: '/System/Library/Fonts/Supplemental/Times New Roman Italic.ttf', name: 'Times New Roman Italic.ttf' },
  { path: '/System/Library/Fonts/Supplemental/Times New Roman Bold Italic.ttf', name: 'Times New Roman Bold Italic.ttf' }
];

let vfsObject = {};

fonts.forEach(font => {
  try {
    const fontData = fs.readFileSync(font.path);
    const base64Data = fontData.toString('base64');
    vfsObject[font.name] = base64Data;
    console.log(`Processed ${font.name}`);
  } catch (err) {
    console.error(`Failed to read ${font.path}:`, err.message);
  }
});

const fileContent = `
window.pdfMake = window.pdfMake || {};
window.pdfMake.vfs = window.pdfMake.vfs || {};
Object.assign(window.pdfMake.vfs, ${JSON.stringify(vfsObject)});
`;

const outputPath = path.join(__dirname, './public/vfs_fonts_times.js');
fs.writeFileSync(outputPath, fileContent);

console.log('Successfully generated vfs_fonts_times.js at:', outputPath);
