const pdfMake = require('pdfmake/build/pdfmake');
const pdfFonts = require('pdfmake/build/vfs_fonts');
pdfMake.vfs = pdfFonts.pdfMake ? pdfFonts.pdfMake.vfs : pdfFonts.vfs;

const { generateGcPdf } = require('./src/utils/pdfGenerator.js');

const gcs = [{
  gcNumber: 'TEST-123',
  date: '2023-01-01',
  consignor: { name: 'SENDER', city: 'SIVAKASI', gstin: '123' },
  consignee: { name: 'RECEIVER', city: 'CHENNAI', gstin: '456' },
  goods: [{ articles: 10, units: 'BOXES' }],
  advance: 100,
  freightTotal: 1000,
  invoiceValue: '50000',
  invoiceDate: '2023-01-01',
  vehicle: { vehicleNumber: 'TN-12-1234' }
}];

const copies = ['CONSIGNOR COPY'];

try {
  console.log('Generating doc definition...');
  const docDefinition = generateGcPdf(gcs, copies);
  console.log('Creating pdf doc...');
  const doc = pdfMake.createPdf(docDefinition);
  
  console.log('Getting base64...');
  doc.getBase64((data) => {
    console.log('SUCCESS! Base64 length:', data.length);
  });
} catch (e) {
  console.error('ERROR CAUGHT:', e);
}
