const pdfMake = require('pdfmake');
const fs = require('fs');
const fonts = {
  Roboto: {
    normal: 'Helvetica',
    bold: 'Helvetica-Bold',
    italics: 'Helvetica-Oblique',
    bolditalics: 'Helvetica-BoldOblique'
  }
};

const printer = new pdfMake(fonts);

const gc = {
  gcNumber: '123', date: '2023-01-01',
  consignor: { name: 'A', address: 'B', city: 'C', gstin: 'D' },
  consignee: { name: 'A', address: 'B', city: 'C', gstin: 'D' },
  goods: [{articles: 1, units: 'BOX'}],
  freightTotal: 100, advance: 10,
  vehicleNo: 'TN-01-AA-1111'
};

// Copy the logic from pdfGenerator.js
const generate = () => {
    const content = [];
    const gcs = [gc];
    const copies = ['CONSIGNEE COPY'];
    
    gcs.forEach((gc, index) => {
        const isAp = gc.gcNumber?.startsWith('AP-');
        const companyName = isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
        const companyTamil = isAp ? 'TAMIL' : 'TAMIL';
        const address = 'ADDRESS';
        const phone = 'PHONE';
        const origin = 'ORIGIN';
        const logoText = 'AP';
        
        copies.forEach((copyType, copyIndex) => {
          const paddedGoods = [...(gc.goods || [])];
          while (paddedGoods.length < 3) paddedGoods.push(null);
          const displayGoods = paddedGoods.slice(0, 3);
    
          const isLast = index === gcs.length - 1 && copyIndex === copies.length - 1;
    
          const advance = parseFloat(gc.advance || 0);
          const totalFreight = parseFloat(gc.freightTotal || 0);
          const balance = totalFreight - advance;
          
          content.push({
            margin: [0, 0, 0, isLast ? 0 : 20],
            pageBreak: isLast ? undefined : 'after',
            stack: [
              {
                columns: [
                  { width: '65%', columns: [ { width: 55, text: logoText, fontSize: 24, bold: true, alignment: 'center', margin: [0, 8, 0, 8], border: [true, true, true, true] }, { width: '*', margin: [10, 0, 0, 0], stack: [ { text: companyTamil, fontSize: 9, bold: true, color: '#475569' }, { text: companyName, fontSize: 22, bold: true, color: '#1e40af', margin: [0, 1, 0, 1] }, { text: address, fontSize: 10, bold: true, color: '#334155' } ] } ] },
                  { width: '35%', stack: [ { text: 'LORRY RECEIPT', fontSize: 16, bold: true, alignment: 'right' }, { text: copyType, fontSize: 10, bold: true, alignment: 'center', margin: [50, 4, 0, 4], fillColor: '#f1f5f9' }, { columns: [ { text: 'GC No', fontSize: 11, bold: true, color: '#64748b', width: '30%' }, { text: gc.gcNumber || '-', fontSize: 16, bold: true, width: '70%', alignment: 'right' } ], margin: [0, 4, 0, 0] }, { columns: [ { text: 'Date', fontSize: 11, bold: true, color: '#64748b', width: '30%' }, { text: gc.date, fontSize: 13, bold: true, width: '70%', alignment: 'right' } ], margin: [0, 4, 0, 0] } ] }
                ],
                margin: [0, 0, 0, 4]
              },
              { table: { widths: ['33%', '34%', '33%'], body: [ [ { stack: [{ text: 'ORIGIN', fontSize: 9, bold: true, color: '#64748b' }, { text: origin, fontSize: 12, bold: true }], border: [true, true, false, true], margin: [6, 6, 6, 6] }, { text: '➔', fontSize: 18, alignment: 'center', color: '#94a3b8', margin: [0, 8, 0, 0], border: [false, true, false, true] }, { stack: [{ text: 'DESTINATION', fontSize: 9, bold: true, color: '#64748b', alignment: 'right' }, { text: 'C', fontSize: 12, bold: true, alignment: 'right' }], border: [false, true, true, true], margin: [6, 6, 6, 6] } ] ] }, layout: { hLineColor: () => '#cbd5e1', vLineColor: () => '#cbd5e1' }, margin: [0, 0, 0, 4] },
              { columns: [ { width: '49%', table: { widths: ['100%'], body: [[{ stack: [ { text: 'CONSIGNOR', fontSize: 9, bold: true, color: '#64748b', margin: [0, 0, 0, 2] }, { text: 'A', fontSize: 12, bold: true, margin: [0, 0, 0, 2] }, { text: 'B', fontSize: 10, margin: [0, 0, 0, 1] }, { text: 'C', fontSize: 10, margin: [0, 0, 0, 4] }, { text: 'D', fontSize: 10, bold: true, margin: [0, 2, 0, 0] } ], margin: [4, 4, 4, 4], border: [true, true, true, true] }]] }, layout: { hLineColor: () => '#cbd5e1', vLineColor: () => '#cbd5e1' } }, { width: '2%', text: '' }, { width: '49%', table: { widths: ['100%'], body: [[{ stack: [ { text: 'CONSIGNEE', fontSize: 9, bold: true, color: '#64748b', margin: [0, 0, 0, 2] }, { text: 'A', fontSize: 12, bold: true, margin: [0, 0, 0, 2] }, { text: 'B', fontSize: 10, margin: [0, 0, 0, 1] }, { text: 'C', fontSize: 10, margin: [0, 0, 0, 4] }, { text: 'D', fontSize: 10, bold: true, margin: [0, 2, 0, 0] } ], margin: [4, 4, 4, 4], border: [true, true, true, true] }]] }, layout: { hLineColor: () => '#cbd5e1', vLineColor: () => '#cbd5e1' } } ], margin: [0, 0, 0, 4] },
              { columns: [ { width: '65%', table: { widths: ['25%', '75%'], heights: [15, 18, 18, 18], body: [ [ { text: 'ARTICLES', fontSize: 9, bold: true, alignment: 'center', fillColor: '#f8fafc', margin: [0, 4, 0, 4], border: [true, true, true, true] }, { text: 'DESCRIPTION', fontSize: 9, bold: true, fillColor: '#f8fafc', margin: [4, 4, 0, 4], border: [true, true, true, true] } ], ...displayGoods.map(g => [ { text: '1', fontSize: 14, bold: true, alignment: 'center', margin: [0, 4, 0, 4], border: [true, false, true, false] }, { text: 'BOX', fontSize: 12, bold: true, margin: [4, 6, 0, 4], border: [true, false, true, false] } ]) ] }, layout: { hLineColor: () => '#cbd5e1', vLineColor: () => '#cbd5e1' } }, { width: '2%', text: '' }, { width: '33%', table: { widths: ['50%', '50%'], heights: [15, 15, 15, 15, 20], body: [ [ { text: 'FREIGHT', colSpan: 2, fontSize: 10, bold: true, alignment: 'center', fillColor: '#f8fafc', margin: [0, 4, 0, 4], border: [true, true, true, true] }, {} ], [ { text: 'FIXED', fontSize: 10, bold: true, color: '#64748b', margin: [4, 4, 0, 4], border: [true, false, false, true] }, { text: '100', fontSize: 11, bold: true, alignment: 'right', margin: [0, 4, 4, 4], border: [false, false, true, true] } ], [ { text: 'ADVANCE', fontSize: 10, bold: true, color: '#64748b', margin: [4, 4, 0, 4], border: [true, false, false, true] }, { text: '10', fontSize: 11, bold: true, alignment: 'right', margin: [0, 4, 4, 4], border: [false, false, true, true] } ], [ { text: 'BALANCE', fontSize: 10, bold: true, color: '#64748b', margin: [4, 4, 0, 4], border: [true, false, false, true] }, { text: '90', fontSize: 11, bold: true, alignment: 'right', margin: [0, 4, 4, 4], border: [false, false, true, true] } ], [ { text: 'TOTAL', fontSize: 12, bold: true, margin: [4, 6, 0, 4], fillColor: '#f1f5f9', border: [true, true, false, true] }, { text: '100', fontSize: 12, bold: true, alignment: 'right', margin: [0, 6, 4, 4], fillColor: '#f1f5f9', border: [false, true, true, true] } ] ] }, layout: { hLineColor: () => '#cbd5e1', vLineColor: () => '#cbd5e1' } } ], margin: [0, 0, 0, 4] },
              { table: { widths: ['15%', '18%', '15%', '20%', '15%', '17%'], body: [ [ { text: 'INV NO:', fontSize: 9, bold: true, color: '#64748b', border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: '-', fontSize: 11, bold: true, border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: 'INV DATE:', fontSize: 9, bold: true, color: '#64748b', border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: '-', fontSize: 11, bold: true, border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: 'VALUE:', fontSize: 9, bold: true, color: '#64748b', border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: '-', fontSize: 11, bold: true, border: [false, false, false, false], margin: [0, 4, 0, 4] } ], [ { text: 'LORRY NO:', fontSize: 9, bold: true, color: '#64748b', border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: 'TN', fontSize: 11, bold: true, border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: 'EWAY BILL:', fontSize: 9, bold: true, color: '#64748b', border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: '-', fontSize: 11, bold: true, border: [false, false, false, false], margin: [0, 4, 0, 4] }, { text: '', border: [false, false, false, false] }, { text: '', border: [false, false, false, false] } ] ] }, layout: { hLineWidth: function (i, node) { return (i === 0 || i === node.table.body.length) ? 1 : 0; }, vLineWidth: function () { return 0; }, hLineColor: function () { return '#cbd5e1'; }, }, margin: [0, 0, 0, 6] },
              { columns: [ { width: '60%', stack: [ { text: 'NOTE', fontSize: 8, bold: true, color: '#64748b' }, { text: 'BREAKAGE.', fontSize: 8, bold: true, color: '#64748b' } ] }, { width: '40%', stack: [ { text: `FOR COMPANY`, fontSize: 11, bold: true, alignment: 'right', margin: [0, 0, 0, 25] }, { text: 'Authorized Signatory', fontSize: 10, color: '#64748b', alignment: 'right' } ] } ] },
              { text: 'RCM PAYABLE BY CONSIGNEE', fontSize: 11, bold: true, alignment: 'right', margin: [0, 5, 0, 0] }
            ]
          });
        });
      });
      return { content, pageSize: { width: 595.28, height: 420 }, pageOrientation: 'landscape', pageMargins: [10, 5, 10, 5], defaultStyle: { font: 'Roboto', color: '#0f172a' } };
}

const doc = printer.createPdfKitDocument(generate());
doc.pipe(fs.createWriteStream('test.pdf'));
doc.end();
console.log("Generated test.pdf");
