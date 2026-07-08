// Use pdfMake from the global window object (loaded via CDN in index.html)
// to bypass Vite/Rollup bundler corruption of the VFS fonts file.
export const getPdfMake = () => {
  if (typeof window !== 'undefined' && window.pdfMake) {
    return window.pdfMake;
  }
  throw new Error("pdfMake is not loaded from CDN.");
};

const buildPremiumLayout = (gc, copyType, companyName, companyTamil, address, phone, origin, gcDate, invoiceDate, invoiceValue, displayGoods, advance, totalFreight, balance, isAp) => {
  const noPaddingLayout = {
    paddingLeft: function(i, node) { return 0; },
    paddingRight: function(i, node) { return 0; },
    paddingTop: function(i, node) { return 0; },
    paddingBottom: function(i, node) { return 0; }
  };

  const innerTableLayout = {
    hLineWidth: function (i, node) { 
      if (i === 0 || i === node.table.body.length) return 0;
      
      // Hide horizontal lines for empty padded rows in the Goods table (2 columns)
      if (node.table.widths.length === 2 && node.table.body[i] && node.table.body[i][0] && node.table.body[i][0].text === ' ') {
        return 0;
      }

      // Hide horizontal lines between Freight Details rows (3 columns)
      if (node.table.widths.length === 3 && i > 1) {
        return 0;
      }

      return 0.5;
    },
    vLineWidth: function (i, node) { return (i === 0 || i === node.table.widths.length) ? 0 : 0.5; },
    hLineColor: function (i) { return '#000000'; },
    vLineColor: function (i) { return '#000000'; }
  };

  return {
    margin: [0, 0, 0, 0],
    stack: [
      // 1. TOP BRANDING ROW
      {
        table: {
          widths: ['100%'],
          body: [
            [
              {
                stack: [
                  { text: companyName, fontSize: 18, bold: true, alignment: 'center', margin: [0, 2, 0, 2] },
                  { text: `${address} | Phone: ${phone}`, fontSize: 9, alignment: 'center' },
                  { text: `LORRY RECEIPT - ${copyType}`, fontSize: 10, bold: true, alignment: 'center', margin: [0, 4, 0, 0] }
                ],
                margin: [4, 4, 4, 4],
                border: [true, true, true, true]
              }
            ]
          ]
        },
        margin: [0, 0, 0, 0]
      },

      // 2. META DATA ROW
      {
        table: {
          widths: ['25%', '25%', '25%', '25%'],
          body: [
            [
              { text: [ { text: 'GC No: ', fontSize: 8 }, { text: gc.gcNumber || '-', fontSize: 10, bold: true } ], margin: [4, 4, 4, 4], border: [true, false, true, true] },
              { text: [ { text: 'Date: ', fontSize: 8 }, { text: gcDate, fontSize: 10, bold: true } ], margin: [4, 4, 4, 4], border: [false, false, true, true] },
              { text: [ { text: 'Origin: ', fontSize: 8 }, { text: origin, fontSize: 10, bold: true } ], margin: [4, 4, 4, 4], border: [false, false, true, true] },
              { text: [ { text: 'Destination: ', fontSize: 8 }, { text: (gc.consignee?.city || '-').toUpperCase(), fontSize: 10, bold: true } ], margin: [4, 4, 4, 4], border: [false, false, true, true] }
            ],
            [
              { text: [ { text: 'Vehicle No: ', fontSize: 8 }, { text: (gc.vehicle?.vehicleNumber || gc.vehicleNo || '-').toUpperCase(), fontSize: 10, bold: true } ], colSpan: 2, margin: [4, 4, 4, 4], border: [true, false, true, true] },
              {},
              { text: [ { text: 'Invoice No: ', fontSize: 8 }, { text: gc.invoiceNumber || '-', fontSize: 10, bold: true } ], margin: [4, 4, 4, 4], border: [false, false, true, true] },
              { text: [ { text: 'Inv Value: ', fontSize: 8 }, { text: `Rs. ${invoiceValue}`, fontSize: 10, bold: true } ], margin: [4, 4, 4, 4], border: [false, false, true, true] }
            ]
          ]
        },
        margin: [0, 0, 0, 0]
      },

      // 3. PARTIES ROW
      {
        table: {
          widths: ['50%', '50%'],
          body: [
            [
              // Consignor
              {
                margin: [4, 4, 4, 4],
                border: [true, false, true, true],
                stack: [
                  { text: 'CONSIGNOR:', fontSize: 8, bold: true, decoration: 'underline', margin: [0, 0, 0, 4] },
                  { text: (gc.consignor?.name || '-').toUpperCase(), fontSize: 10, bold: true, margin: [0, 0, 0, 2] },
                  { text: (gc.consignor?.address || '').toUpperCase(), fontSize: 9, margin: [0, 0, 0, 2] },
                  { text: (gc.consignor?.city || '').toUpperCase(), fontSize: 9, margin: [0, 0, 0, 4] },
                  { text: `GSTIN: ${gc.consignor?.gstin || '-'}`, fontSize: 9, bold: true }
                ]
              },
              // Consignee
              {
                margin: [4, 4, 4, 4],
                border: [false, false, true, true],
                stack: [
                  { text: 'CONSIGNEE:', fontSize: 8, bold: true, decoration: 'underline', margin: [0, 0, 0, 4] },
                  { text: (gc.consignee?.name || '-').toUpperCase(), fontSize: 10, bold: true, margin: [0, 0, 0, 2] },
                  { text: (gc.consignee?.address || '').toUpperCase(), fontSize: 9, margin: [0, 0, 0, 2] },
                  { text: (gc.consignee?.city || '').toUpperCase(), fontSize: 9, margin: [0, 0, 0, 4] },
                  { text: `GSTIN: ${gc.consignee?.gstin || '-'}`, fontSize: 9, bold: true }
                ]
              }
            ]
          ]
        },
        margin: [0, 0, 0, 0]
      },

      // 4. MAIN DATA (Goods, Weight, Freight)
      {
        table: {
          widths: ['50%', '50%'],
          body: [
            [
              // Column 1: Goods (50%)
              {
                border: [true, false, true, true],
                table: {
                  widths: ['30%', '70%'],
                  body: [
                    [
                      { text: 'ARTICLES', fontSize: 9, bold: true, alignment: 'center', margin: [2, 2, 2, 2] },
                      { text: 'DESCRIPTION OF GOODS', fontSize: 9, bold: true, alignment: 'center', margin: [2, 2, 2, 2] }
                    ],
                    [
                      { text: displayGoods[0] ? (displayGoods[0].articles || displayGoods[0].articleCount || '0') : ' ', fontSize: 12, bold: true, alignment: 'center', margin: [0, 8, 0, 8] },
                      { text: displayGoods[0] ? (displayGoods[0].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, alignment: 'center', margin: [0, 8, 0, 8] }
                    ],
                    [
                      { text: displayGoods[1] ? (displayGoods[1].articles || displayGoods[1].articleCount || '0') : ' ', fontSize: 12, bold: true, alignment: 'center', margin: [0, 8, 0, 8] },
                      { text: displayGoods[1] ? (displayGoods[1].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, alignment: 'center', margin: [0, 8, 0, 8] }
                    ],
                    [
                      { text: displayGoods[2] ? (displayGoods[2].articles || displayGoods[2].articleCount || '0') : ' ', fontSize: 12, bold: true, alignment: 'center', margin: [0, 8, 0, 8] },
                      { text: displayGoods[2] ? (displayGoods[2].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, alignment: 'center', margin: [0, 8, 0, 8] }
                    ]
                  ]
                },
                layout: innerTableLayout,
                margin: [0, 0, 0, 0]
              },
              // Column 2: Weight + Freight (50%)
              {
                border: [false, false, true, true],
                table: {
                  widths: ['30%', '40%', '30%'],
                  body: [
                    [
                      { text: 'WEIGHT', fontSize: 9, bold: true, alignment: 'center', margin: [2, 2, 2, 2] },
                      { text: 'FREIGHT DETAILS', colSpan: 2, fontSize: 9, bold: true, alignment: 'center', margin: [2, 2, 2, 2] },
                      {}
                    ],
                    [
                      { text: gc.actualWeight || 'FIXED', rowSpan: 3, fontSize: 11, bold: true, alignment: 'center', margin: [0, 30, 0, 0] },
                      { text: 'FIXED FREIGHT', fontSize: 9, margin: [4, 6, 4, 6] },
                      { text: totalFreight.toFixed(2), fontSize: 10, bold: true, alignment: 'right', margin: [4, 6, 4, 6] }
                    ],
                    [
                      {},
                      { text: 'LESS: ADVANCE', fontSize: 9, margin: [4, 6, 4, 6] },
                      { text: advance.toFixed(2), fontSize: 10, bold: true, alignment: 'right', margin: [4, 6, 4, 6] }
                    ],
                    [
                      {},
                      { 
                        stack: [
                          { text: 'BALANCE TO PAY', fontSize: 9, bold: true },
                          { text: balance > 0 ? 'STATUS: TO PAY' : 'STATUS: PAID', fontSize: 10, bold: true, margin: [0, 8, 0, 0] }
                        ],
                        margin: [4, 6, 4, 8] 
                      },
                      { text: balance.toFixed(2), fontSize: 11, bold: true, alignment: 'right', margin: [4, 6, 4, 8] }
                    ]
                  ]
                },
                layout: innerTableLayout,
                margin: [0, 0, 0, 0]
              }
            ]
          ]
        },
        layout: noPaddingLayout,
        margin: [0, 0, 0, 0]
      },

      // 5. FOOTER
      {
        table: {
          widths: ['70%', '30%'],
          body: [
            [
              {
                margin: [4, 4, 4, 4],
                border: [true, false, true, true],
                stack: [
                  { text: "AT OWNER'S RISK", fontSize: 11, bold: true, margin: [0, 0, 0, 4] },
                  { text: 'Note: We are not responsible for fire, theft, leakage, damage & breakage. | Subject to Sivakasi Jurisdiction.', fontSize: 8 },
                  { text: 'RCM PAYABLE BY CONSIGNEE', fontSize: 9, bold: true, decoration: 'underline', margin: [0, 4, 0, 0] }
                ]
              },
              {
                margin: [4, 4, 4, 4],
                border: [false, false, true, true],
                stack: [
                  { text: `For ${companyName}`, fontSize: 9, bold: true, alignment: 'center', margin: [0, 0, 0, 20] },
                  { text: 'Authorized Signatory', fontSize: 8, alignment: 'center' }
                ]
              }
            ]
          ]
        },
        margin: [0, 0, 0, 0]
      }
    ]
  };
};

export const generateGcPdf = (gcs, copies) => {
  const content = [];

  gcs.forEach((gc, index) => {
    const isAp = gc.gcNumber?.startsWith('AP-');
    const companyName = isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
    const companyTamil = isAp ? 'ஸ்ரீ அய்யனார் துணை' : 'ஸ்ரீ திருச்செந்தூர் முருகன் துணை';
    const address = isAp ? '359, THIRUTHAGAL ROAD, SIVAKASI-626123' : '359, THIRUTHAGAL ROAD, SIVAKASI-626123';
    const phone = isAp ? '9876543210' : '04562-221253';
    const origin = isAp ? 'SIVAKASI' : 'SIVAKASI';
    
    copies.forEach((copyType, copyIndex) => {
      const paddedGoods = [...(gc.goods || [])];
      while (paddedGoods.length < 3) paddedGoods.push(null);
      const displayGoods = paddedGoods.slice(0, 3);

      const isLast = index === gcs.length - 1 && copyIndex === copies.length - 1;

      const advance = parseFloat(gc.advance || 0);
      const totalFreight = parseFloat(gc.freightTotal || 0);
      const balance = totalFreight - advance;
      
      const invoiceValue = gc.invoiceValue ? parseFloat(gc.invoiceValue).toFixed(2) : '-';
      const invoiceDate = gc.invoiceDate ? new Date(gc.invoiceDate).toLocaleDateString('en-GB').replace(/\//g, '-') : '-';
      const gcDate = gc.date ? new Date(gc.date).toLocaleDateString('en-GB').replace(/\//g, '-') : '-';

      const layoutObj = buildPremiumLayout(gc, copyType, companyName, companyTamil, address, phone, origin, gcDate, invoiceDate, invoiceValue, displayGoods, advance, totalFreight, balance, isAp);

      content.push({
        ...layoutObj,
        pageBreak: isLast ? undefined : 'after'
      });
    });
  });

  return {
    content,
    pageSize: 'A5',
    pageOrientation: 'landscape',
    pageMargins: [10, 10, 10, 10],
    defaultStyle: {
      font: 'Times',
      color: 'black'
    }
  };
};

export const generateGcPdfBlob = async (gcs, copies) => {
  return new Promise((resolve, reject) => {
    let timeoutId = setTimeout(() => {
      reject(new Error("PDF generation timed out after 10 seconds. Layout might be complex or fonts missing."));
    }, 10000);

    try {
      console.log('Creating docDefinition...');
      const docDefinition = generateGcPdf(gcs, copies);
      console.log('docDefinition created. Initializing pdfMake...');
      const pdf = getPdfMake();

      pdf.fonts = {
        Roboto: {
          normal: 'Roboto-Regular.ttf',
          bold: 'Roboto-Medium.ttf',
          italics: 'Roboto-Italic.ttf',
          bolditalics: 'Roboto-MediumItalic.ttf'
        },
        Times: {
          normal: 'Times New Roman.ttf',
          bold: 'Times New Roman Bold.ttf',
          italics: 'Times New Roman Italic.ttf',
          bolditalics: 'Times New Roman Bold Italic.ttf'
        }
      };

      const pdfDocGenerator = pdf.createPdf(docDefinition);
      
      console.log('Calling getDataUrl...');
      pdfDocGenerator.getDataUrl((dataUrl) => {
        console.log('DataUrl successfully generated!');
        clearTimeout(timeoutId);
        resolve(dataUrl);
      });
    } catch (error) {
      clearTimeout(timeoutId);
      console.error('Error during PDF creation:', error);
      reject(error);
    }
  });
};

export const downloadGcPdf = (gcs, copies) => {
  const docDefinition = generateGcPdf(gcs, copies);
  const pdf = getPdfMake();
  const pdfDocGenerator = pdf.createPdf(docDefinition);
  pdfDocGenerator.download(`GC_${gcs[0]?.gcNumber || 'Print'}.pdf`);
};
