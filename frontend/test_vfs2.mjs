import * as pdfFonts from 'pdfmake/build/vfs_fonts.js';
console.log(Object.keys(pdfFonts.default));
if (pdfFonts.default.pdfMake) {
  console.log("Found pdfMake inside default!");
}
