const pdfMake = require('pdfmake/build/pdfmake.js');
const pdfFonts = require('pdfmake/build/vfs_fonts.js');
pdfMake.vfs = pdfFonts.pdfMake.vfs;

const doc = { content: 'Test' };
const generator = pdfMake.createPdf(doc);
generator.getBase64((b) => { console.log("Base64 worked:", b.substring(0,20)); });
