import * as pdfFonts from 'pdfmake/build/vfs_fonts.js';
console.log(Object.keys(pdfFonts));
console.log("pdfMake in pdfFonts:", !!pdfFonts.pdfMake);
console.log("default in pdfFonts:", !!pdfFonts.default);
