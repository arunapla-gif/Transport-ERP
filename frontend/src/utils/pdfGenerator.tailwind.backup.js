import pdfMake from 'pdfmake/build/pdfmake';
import pdfFonts from 'pdfmake/build/vfs_fonts';

if (pdfFonts && pdfFonts.pdfMake) {
  pdfMake.vfs = pdfFonts.pdfMake.vfs;
} else if (pdfFonts && pdfFonts.vfs) {
  pdfMake.vfs = pdfFonts.vfs;
} else if (window.pdfMake && window.pdfMake.vfs) {
  pdfMake.vfs = window.pdfMake.vfs;
}

export const generateGcPdf = (gcs, copies) => {
  const content = [];

  gcs.forEach((gc, index) => {
    const isAp = gc.gcNumber?.startsWith('AP-');
    const companyName = isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
    const companyTamil = isAp ? 'ஸ்ரீ அய்யனார் துணை' : 'ஸ்ரீ திருச்செந்தூர் முருகன் துணை';
    const address = isAp ? 'SIVAKASI' : '359, THIRUTHAGAL ROAD, SIVAKASI-626123';
    const phone = isAp ? '9876543210' : '221253';
    const origin = isAp ? 'SIVAKASI' : 'SIVAKASI';
    const logoText = isAp ? 'AP' : 'BL';
    
    copies.forEach((copyType, copyIndex) => {
      const paddedGoods = [...(gc.goods || [])];
      while (paddedGoods.length < 3) paddedGoods.push(null);
      const displayGoods = paddedGoods.slice(0, 3);

      const isLast = index === gcs.length - 1 && copyIndex === copies.length - 1;

      // Ensure safe freight calculations
      const advance = parseFloat(gc.advance || 0);
      const totalFreight = parseFloat(gc.freightTotal || 0);
      const balance = totalFreight - advance;
      
      const invoiceValue = gc.invoiceValue ? parseFloat(gc.invoiceValue).toFixed(2) : '-';
      const invoiceDate = gc.invoiceDate ? new Date(gc.invoiceDate).toLocaleDateString('en-GB').replace(/\//g, '-') : '-';
      const gcDate = gc.date ? new Date(gc.date).toLocaleDateString('en-GB').replace(/\//g, '-') : '-';

      content.push({
        margin: [0, 0, 0, 0],
        pageBreak: isLast ? undefined : 'after',
        table: {
          widths: ['60%', '40%'],
          body: [
            // ROW 1: HEADER
            [
              {
                border: [false, false, false, true],
                stack: [
                  { text: companyTamil, fontSize: 10, bold: true, color: '#475569' },
                  { text: companyName, fontSize: 22, bold: true, color: '#1e40af', margin: [0, 2, 0, 2] },
                  { text: `${address} | Ph: ${phone}`, fontSize: 11, bold: true }
                ]
              },
              {
                border: [false, false, false, true],
                alignment: 'right',
                stack: [
                  { text: 'LORRY RECEIPT', fontSize: 14, bold: true },
                  { text: copyType, fontSize: 10, bold: true, fillColor: '#f1f5f9', margin: [0, 4, 0, 4] },
                  { text: `GC No: ${gc.gcNumber || '-'}`, fontSize: 14, bold: true },
                  { text: `Date: ${gcDate}`, fontSize: 11, bold: true, margin: [0, 2, 0, 0] }
                ]
              }
            ],
            // ROW 2: ROUTE
            [
              {
                colSpan: 2,
                border: [false, false, false, true],
                margin: [0, 4, 0, 4],
                columns: [
                  { width: '40%', text: `ORIGIN: ${origin}`, fontSize: 12, bold: true },
                  { width: '20%', text: '➔', fontSize: 14, alignment: 'center' },
                  { width: '40%', text: `DESTINATION: ${(gc.consignee?.city || '-').toUpperCase()}`, fontSize: 12, bold: true, alignment: 'right' }
                ]
              },
              {}
            ],
            // ROW 3: CONSIGNOR & CONSIGNEE
            [
              {
                border: [false, false, true, true],
                margin: [0, 4, 0, 4],
                stack: [
                  { text: 'CONSIGNOR:', fontSize: 9, color: '#64748b' },
                  { text: (gc.consignor?.name || '-').toUpperCase(), fontSize: 11, bold: true, margin: [0, 2, 0, 2] },
                  { text: (gc.consignor?.address || '').toUpperCase(), fontSize: 10 },
                  { text: (gc.consignor?.city || '').toUpperCase(), fontSize: 10, margin: [0, 0, 0, 2] },
                  { text: `GSTIN: ${gc.consignor?.gstin || '-'}`, fontSize: 10, bold: true }
                ]
              },
              {
                border: [false, false, false, true],
                margin: [4, 4, 0, 4],
                stack: [
                  { text: 'CONSIGNEE:', fontSize: 9, color: '#64748b' },
                  { text: (gc.consignee?.name || '-').toUpperCase(), fontSize: 11, bold: true, margin: [0, 2, 0, 2] },
                  { text: (gc.consignee?.address || '').toUpperCase(), fontSize: 10 },
                  { text: (gc.consignee?.city || '').toUpperCase(), fontSize: 10, margin: [0, 0, 0, 2] },
                  { text: `GSTIN: ${gc.consignee?.gstin || '-'}`, fontSize: 10, bold: true }
                ]
              }
            ],
            // ROW 4: GOODS & FREIGHT
            [
              {
                border: [false, false, true, true],
                margin: [0, 4, 0, 4],
                table: {
                  widths: ['25%', '75%'],
                  body: [
                    [ { text: 'ARTICLES', fontSize: 10, bold: true, fillColor: '#f8fafc' }, { text: 'DESCRIPTION', fontSize: 10, bold: true, fillColor: '#f8fafc' } ],
                    ...displayGoods.map(g => [
                      { text: g ? (g.articles || g.articleCount || '0') : ' ', fontSize: 12, bold: true, alignment: 'center', margin: [0, 4, 0, 4] },
                      { text: g ? (g.units || '').toUpperCase() : ' ', fontSize: 12, bold: true, margin: [0, 4, 0, 4] }
                    ])
                  ]
                },
                layout: 'lightHorizontalLines'
              },
              {
                border: [false, false, false, true],
                margin: [4, 4, 0, 4],
                table: {
                  widths: ['50%', '50%'],
                  body: [
                    [ { text: 'FREIGHT', colSpan: 2, fontSize: 10, bold: true, fillColor: '#f8fafc', alignment: 'center' }, {} ],
                    [ { text: 'FIXED', fontSize: 10 }, { text: totalFreight.toFixed(2), fontSize: 11, bold: true, alignment: 'right' } ],
                    [ { text: 'ADVANCE', fontSize: 10 }, { text: advance.toFixed(2), fontSize: 11, bold: true, alignment: 'right' } ],
                    [ { text: 'BALANCE', fontSize: 10 }, { text: balance.toFixed(2), fontSize: 11, bold: true, alignment: 'right' } ],
                    [ { text: 'TOTAL', fontSize: 12, bold: true, fillColor: '#f1f5f9' }, { text: totalFreight.toFixed(2), fontSize: 14, bold: true, alignment: 'right', fillColor: '#f1f5f9' } ]
                  ]
                },
                layout: 'lightHorizontalLines'
              }
            ],
            // ROW 5: INVOICE DETAILS
            [
              {
                colSpan: 2,
                border: [false, false, false, true],
                margin: [0, 4, 0, 4],
                columns: [
                  { width: '25%', text: `INV NO: ${gc.invoiceNumber || '-'}`, fontSize: 10, bold: true },
                  { width: '25%', text: `INV DATE: ${invoiceDate}`, fontSize: 10, bold: true },
                  { width: '25%', text: `VALUE: ${invoiceValue}`, fontSize: 10, bold: true },
                  { width: '25%', text: `LORRY: ${(gc.vehicle?.vehicleNumber || gc.vehicleNo || '-').toUpperCase()}`, fontSize: 10, bold: true }
                ]
              },
              {}
            ],
            // ROW 6: FOOTER
            [
              {
                border: [false, false, false, false],
                margin: [0, 4, 0, 0],
                stack: [
                  { text: 'NOTE: WE ARE NOT RESPONSIBLE FOR FIRE, THEFT, LEAKAGE, DAMAGE & BREAKAGE.', fontSize: 8, color: '#64748b' },
                  { text: 'SUBJECT TO SIVAKASI JURISDICTION.', fontSize: 8, color: '#64748b' },
                  { text: 'RCM PAYABLE BY CONSIGNEE', fontSize: 11, bold: true, margin: [0, 10, 0, 0] }
                ]
              },
              {
                border: [false, false, false, false],
                alignment: 'right',
                margin: [0, 4, 0, 0],
                stack: [
                  { text: `FOR ${companyName}`, fontSize: 11, bold: true, margin: [0, 0, 0, 25] },
                  { text: 'Authorized Signatory', fontSize: 9, color: '#64748b' }
                ]
              }
            ]
          ]
        },
        layout: {
          hLineColor: () => '#cbd5e1',
          vLineColor: () => '#cbd5e1'
        }
      });
    });
  });

  return {
    content,
    pageSize: 'A5',
    pageOrientation: 'landscape',
    pageMargins: [15, 15, 15, 15],
    defaultStyle: {
      font: 'Roboto',
      color: '#0f172a'
    }
  };
};

export const generateGcPdfBlob = async (gcs, copies) => {
  return new Promise((resolve, reject) => {
    try {
      const docDefinition = generateGcPdf(gcs, copies);
      const pdfDocGenerator = pdfMake.createPdf(docDefinition);
      
      pdfDocGenerator.getBlob((blob) => {
        resolve(blob);
      });
    } catch (error) {
      reject(error);
    }
  });
};

export const downloadGcPdf = (gcs, copies) => {
  const docDefinition = generateGcPdf(gcs, copies);
  const pdfDocGenerator = pdfMake.createPdf(docDefinition);
  pdfDocGenerator.download(`GC_${gcs[0]?.gcNumber || 'Print'}.pdf`);
};
