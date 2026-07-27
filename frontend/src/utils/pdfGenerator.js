// Use pdfMake from the global window object (loaded via CDN in index.html)
// to bypass Vite/Rollup bundler corruption of the VFS fonts file.
export const getPdfMake = () => {
  if (typeof window !== 'undefined' && window.pdfMake) {
    return window.pdfMake;
  }
  throw new Error("pdfMake is not loaded from CDN.");
};

const numberToWords = (num) => {
  if (num === 0) return 'ZERO ONLY';
  const a = ['', 'ONE ', 'TWO ', 'THREE ', 'FOUR ', 'FIVE ', 'SIX ', 'SEVEN ', 'EIGHT ', 'NINE ', 'TEN ', 'ELEVEN ', 'TWELVE ', 'THIRTEEN ', 'FOURTEEN ', 'FIFTEEN ', 'SIXTEEN ', 'SEVENTEEN ', 'EIGHTEEN ', 'NINETEEN '];
  const b = ['', '', 'TWENTY', 'THIRTY', 'FORTY', 'FIFTY', 'SIXTY', 'SEVENTY', 'EIGHTY', 'NINETY'];
  const n = ('000000000' + num).substr(-9).match(/^(\d{2})(\d{2})(\d{2})(\d{1})(\d{2})$/);
  if (!n) return '';
  let str = '';
  str += (n[1] != 0) ? (a[Number(n[1])] || b[n[1][0]] + ' ' + a[n[1][1]]) + 'CRORE ' : '';
  str += (n[2] != 0) ? (a[Number(n[2])] || b[n[2][0]] + ' ' + a[n[2][1]]) + 'LAKH ' : '';
  str += (n[3] != 0) ? (a[Number(n[3])] || b[n[3][0]] + ' ' + a[n[3][1]]) + 'THOUSAND ' : '';
  str += (n[4] != 0) ? (a[Number(n[4])] || b[n[4][0]] + ' ' + a[n[4][1]]) + 'HUNDRED ' : '';
  str += (n[5] != 0) ? ((str != '') ? 'AND ' : '') + (a[Number(n[5])] || b[n[5][0]] + ' ' + a[n[5][1]]) : '';
  return str.trim() + ' ONLY';
};

const buildLegacyLayout = (gc, copyType, companyName, companyTamil, address, phone, origin, gcDate, invoiceDate, invoiceValue, displayGoods, advance, totalFreight, balance, isAp) => {
  const formColor = '#e11d48'; // Red ink color of the old physical form
  const inputColor = '#000000'; // Black ink for the actual printed data
  
  const formLayout = {
    hLineWidth: function(i, node) { return 0.5; },
    vLineWidth: function(i, node) { return 0.5; },
    hLineColor: function(i) { return formColor; },
    vLineColor: function(i) { return formColor; },
    paddingLeft: function(i, node) { return 4; },
    paddingRight: function(i, node) { return 4; },
    paddingTop: function(i, node) { return 3; },
    paddingBottom: function(i, node) { return 3; }
  };

  return {
    margin: [0, 0, 0, 0],
    stack: [
      // Top row (no borders)
      {
        columns: [
          { text: 'Subject to Sivakasi Jurisdiction', fontSize: 8, color: formColor, alignment: 'left' },
          { text: companyTamil, fontSize: 8, color: formColor, alignment: 'center' },
          { text: 'LORRY COPY', fontSize: 10, bold: true, color: formColor, alignment: 'right' }
        ],
        margin: [0, 0, 0, 2]
      },
      // Main Grid
      {
        table: {
          widths: ['12%', '30%', '13%', '25%', '20%'],
          body: [
            // Row 1: Company Header | GC Note
            [
              {
                colSpan: 4,
                stack: [
                  { text: companyName, fontSize: 24, bold: true, color: formColor, alignment: 'center', margin: [0, 2, 0, 2] },
                  { text: `${address} | PH : ${phone}`, fontSize: 9, bold: true, color: formColor, alignment: 'center' }
                ],
                border: [true, true, true, true]
              },
              {}, {}, {},
              {
                stack: [
                  { text: 'G.C. Note No. :   ', fontSize: 8, color: formColor, margin: [0, 0, 0, 0] },
                  { text: (gc.gcNumber || ''), fontSize: 11, bold: true, color: inputColor, alignment: 'right', margin: [0, 0, 0, 4] },
                  { text: 'Date                 :   ', fontSize: 8, color: formColor, margin: [0, 0, 0, 0] },
                  { text: gcDate, fontSize: 10, bold: true, color: inputColor, alignment: 'right' }
                ],
                border: [false, true, true, true]
              }
            ],
            // Row 2: Lorry Owner Address
            [
              { text: 'Lorry Owner Address :  ' + (gc.vehicle?.vehicleNumber || gc.vehicleNo || '-').toUpperCase(), colSpan: 5, fontSize: 9, bold: true, color: formColor, border: [true, false, true, true] },
              {}, {}, {}, {}
            ],
            // Row 3: Parties
            [
              {
                colSpan: 2,
                stack: [
                  { text: 'Consignor M/s.', fontSize: 9, bold: true, color: formColor, margin: [0, 0, 0, 2] },
                  { text: (gc.consignor?.name || '-').toUpperCase(), fontSize: 10, bold: true, color: inputColor },
                  { text: (gc.consignor?.city || '').toUpperCase(), fontSize: 9, color: inputColor },
                  { text: `GSTIN: ${gc.consignor?.gstin || '-'}`, fontSize: 8, bold: true, color: inputColor }
                ],
                border: [true, false, true, true]
              },
              {},
              { text: 'Freight', fontSize: 9, bold: true, color: formColor, alignment: 'center', margin: [0, 0, 0, 0], border: [false, false, true, true] },
              {
                colSpan: 2,
                stack: [
                  { text: 'Consignee M/s.', fontSize: 9, bold: true, color: formColor, margin: [0, 0, 0, 2] },
                  { text: (gc.consignee?.name || '-').toUpperCase(), fontSize: 10, bold: true, color: inputColor },
                  { text: (gc.consignee?.city || '').toUpperCase(), fontSize: 9, color: inputColor },
                  { text: `GSTIN: ${gc.consignee?.gstin || '-'}`, fontSize: 8, bold: true, color: inputColor }
                ],
                border: [false, false, true, true]
              },
              {}
            ],
            // Row 4: Grid Headers
            [
              { text: 'No. of\nArticles', fontSize: 9, bold: true, color: formColor, alignment: 'center', border: [true, false, true, true] },
              { text: 'Description', colSpan: 3, fontSize: 10, bold: true, color: formColor, alignment: 'center', border: [false, false, true, true] },
              {}, {},
              { 
                table: {
                  widths: ['60%', '40%'],
                  body: [
                    [{ text: 'Amount', colSpan: 2, fontSize: 9, bold: true, color: formColor, alignment: 'center', border: [false,false,false,true] }, {}],
                    [{ text: 'Rs.', fontSize: 8, color: formColor, alignment: 'center', border: [false,false,true,false] }, { text: 'Ps.', fontSize: 8, color: formColor, alignment: 'center', border: [false,false,false,false] }]
                  ]
                },
                layout: formLayout,
                margin: [-4, -3, -4, -3],
                border: [false, false, true, true] 
              }
            ],
            // Row 5: Goods Data
            [
              {
                stack: [
                  { text: displayGoods[0] ? (displayGoods[0].articles || displayGoods[0].articleCount || '0') : ' ', fontSize: 11, bold: true, color: inputColor, alignment: 'center', margin: [0, 6, 0, 6] },
                  { text: displayGoods[1] ? (displayGoods[1].articles || displayGoods[1].articleCount || '0') : ' ', fontSize: 11, bold: true, color: inputColor, alignment: 'center', margin: [0, 6, 0, 6] },
                  { text: displayGoods[2] ? (displayGoods[2].articles || displayGoods[2].articleCount || '0') : ' ', fontSize: 11, bold: true, color: inputColor, alignment: 'center', margin: [0, 6, 0, 6] }
                ],
                border: [true, false, true, true]
              },
              {
                colSpan: 3,
                stack: [
                  { text: 'Said to Concern', fontSize: 8, bold: true, color: formColor, margin: [0, 0, 0, 2] },
                  { text: displayGoods[0] ? (displayGoods[0].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, color: inputColor, alignment: 'center', margin: [0, 6, 0, 6] },
                  { text: displayGoods[1] ? (displayGoods[1].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, color: inputColor, alignment: 'center', margin: [0, 6, 0, 6] },
                  { text: displayGoods[2] ? (displayGoods[2].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, color: inputColor, alignment: 'center', margin: [0, 6, 0, 16] },
                  {
                    table: {
                      widths: ['25%', '25%', '25%', '25%'],
                      body: [
                        [
                          { stack: [ {text: 'Bill No. & Date', fontSize: 8, color: formColor}, {text: `${gc.invoiceNumber || '-'}`, fontSize: 9, bold: true, color: inputColor, margin: [0,4,0,0]} ], border: [false, true, true, false] },
                          { stack: [ {text: 'Private Mark', fontSize: 8, color: formColor}, {text: (gc.privateMark||'-').toUpperCase(), fontSize: 9, bold: true, color: inputColor, margin: [0,4,0,0]} ], border: [false, true, true, false] },
                          { text: "AT\nOWNER'S\nRISK", fontSize: 9, bold: true, color: formColor, alignment: 'center', margin: [0,2,0,0], border: [false, true, true, false] },
                          { stack: [ {text: 'Goods Value Rs.', fontSize: 8, color: formColor}, {text: invoiceValue, fontSize: 9, bold: true, color: inputColor, margin:[0,2,0,2]}, {text: '(Uploading Charges\npayable by Party)', fontSize: 6, color: formColor, alignment: 'center'} ], border: [false, true, false, false] }
                        ]
                      ]
                    },
                    layout: formLayout,
                    margin: [-4, 4, -4, -3]
                  }
                ],
                border: [false, false, true, true]
              },
              {}, {},
              {
                table: {
                  widths: ['60%', '40%'],
                  body: [
                    [{ text: 'Freight Fixed', fontSize: 8, color: formColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,true,true] }, { text: totalFreight.toFixed(2), fontSize: 9, bold: true, color: inputColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,false,true] }],
                    [{ text: 'Advance Paid', fontSize: 8, color: formColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,true,true] }, { text: advance.toFixed(2), fontSize: 9, bold: true, color: inputColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,false,true] }],
                    [{ text: 'Balance', fontSize: 8, color: formColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,true,true] }, { text: balance.toFixed(2), fontSize: 9, bold: true, color: inputColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,false,true] }],
                    [{ text: 'Statistical Charges', fontSize: 8, color: formColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,true,true] }, { text: (gc.statisticalCharges || '-').toString(), fontSize: 9, bold: true, color: inputColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,false,true] }],
                    [{ text: 'Total To-pay', fontSize: 8, color: formColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,true,false] }, { text: balance.toFixed(2), fontSize: 9, bold: true, color: inputColor, alignment: 'right', margin: [2,6,2,6], border: [false,false,false,false] }]
                  ]
                },
                layout: formLayout,
                margin: [-4, -3, -4, -3],
                border: [false, false, true, true]
              }
            ],
            // Row 6: Rupees in words
            [
              { text: 'Rupees', fontSize: 9, color: formColor, border: [true, false, false, true] },
              { text: numberToWords(Math.round(totalFreight)), colSpan: 4, fontSize: 9, bold: true, italics: true, color: inputColor, border: [false, false, true, true], margin: [0, 2, 0, 2] },
              {}, {}, {}
            ],
            // Row 7: Footer
            [
              {
                colSpan: 3,
                stack: [
                  { text: 'OUR SERVICE TAX REGN NO.', fontSize: 8, color: formColor },
                  { text: 'GSTIN: 33AALCB1234C1Z5', fontSize: 9, bold: true, color: inputColor } // Replace with actual company GSTIN if available
                ],
                border: [true, false, true, true]
              },
              {}, {},
              {
                colSpan: 2,
                stack: [
                  { text: 'For ' + companyName, fontSize: 10, bold: true, color: formColor, alignment: 'center', margin: [0, 2, 0, 24] },
                  { text: 'Authorized Signatory', fontSize: 8, color: formColor, alignment: 'right' }
                ],
                border: [false, false, true, true]
              },
              {}
            ]
          ]
        },
        layout: formLayout
      }
    ]
  };
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
                      { text: displayGoods[0] ? (displayGoods[0].articles || displayGoods[0].articleCount || '0') : ' ', fontSize: 12, bold: true, alignment: 'center', margin: [0, 4, 0, 4] },
                      { text: displayGoods[0] ? (displayGoods[0].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, alignment: 'center', margin: [0, 4, 0, 4] }
                    ],
                    [
                      { text: displayGoods[1] ? (displayGoods[1].articles || displayGoods[1].articleCount || '0') : ' ', fontSize: 12, bold: true, alignment: 'center', margin: [0, 4, 0, 4] },
                      { text: displayGoods[1] ? (displayGoods[1].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, alignment: 'center', margin: [0, 4, 0, 4] }
                    ],
                    [
                      { text: displayGoods[2] ? (displayGoods[2].articles || displayGoods[2].articleCount || '0') : ' ', fontSize: 12, bold: true, alignment: 'center', margin: [0, 4, 0, 4] },
                      { text: displayGoods[2] ? (displayGoods[2].units || '').toUpperCase() : ' ', fontSize: 10, bold: true, alignment: 'center', margin: [0, 4, 0, 4] }
                    ],
                    [
                      { text: 'PVT. MARK:', fontSize: 8, bold: true, alignment: 'center', margin: [0, 6, 0, 2] },
                      { text: (gc.privateMark || '-').toUpperCase(), fontSize: 9, bold: true, margin: [4, 6, 4, 2] }
                    ],
                    [
                      { colSpan: 2, stack: [
                          { text: 'RUPEES (IN WORDS):', fontSize: 8, bold: true },
                          { text: copyType === 'LORRY COPY' ? numberToWords(Math.round(totalFreight)) : '***', fontSize: 8, bold: true, italics: true, margin: [0, 2, 0, 0] }
                        ], margin: [4, 4, 4, 4] 
                      },
                      {}
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
                      { text: gc.actualWeight || 'FIXED', rowSpan: 5, fontSize: 11, bold: true, alignment: 'center', margin: [0, 30, 0, 0] },
                      { text: 'FIXED FREIGHT', fontSize: 9, margin: [4, 4, 4, 4] },
                      { text: copyType === 'LORRY COPY' ? totalFreight.toFixed(2) : 'FIXED', fontSize: 10, bold: true, alignment: 'right', margin: [4, 4, 4, 4] }
                    ],
                    [
                      {},
                      { text: 'STATISTICAL CHG.', fontSize: 9, margin: [4, 4, 4, 4] },
                      { text: copyType === 'LORRY COPY' ? (gc.statisticalCharges || '-').toString() : 'FIXED', fontSize: 10, bold: true, alignment: 'right', margin: [4, 4, 4, 4] }
                    ],
                    [
                      {},
                      { text: 'UNLOADING CHG.', fontSize: 9, margin: [4, 4, 4, 4] },
                      { text: copyType === 'LORRY COPY' ? (gc.unloadingCharges || '-').toString() : 'FIXED', fontSize: 10, bold: true, alignment: 'right', margin: [4, 4, 4, 4] }
                    ],
                    [
                      {},
                      { text: 'LESS: ADVANCE', fontSize: 9, margin: [4, 4, 4, 4] },
                      { text: copyType === 'LORRY COPY' ? advance.toFixed(2) : 'FIXED', fontSize: 10, bold: true, alignment: 'right', margin: [4, 4, 4, 4] }
                    ],
                    [
                      {},
                      { 
                        stack: [
                          { text: 'BALANCE TO PAY', fontSize: 9, bold: true },
                          { text: copyType === 'LORRY COPY' ? (balance > 0 ? 'STATUS: TO PAY' : 'STATUS: PAID') : 'STATUS: FIXED', fontSize: 10, bold: true, margin: [0, 6, 0, 0] }
                        ],
                        margin: [4, 4, 4, 6] 
                      },
                      { text: copyType === 'LORRY COPY' ? balance.toFixed(2) : 'FIXED', fontSize: 11, bold: true, alignment: 'right', margin: [4, 4, 4, 6] }
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

      const layoutObj = (copyType === 'LORRY COPY') 
        ? buildLegacyLayout(gc, copyType, companyName, companyTamil, address, phone, origin, gcDate, invoiceDate, invoiceValue, displayGoods, advance, totalFreight, balance, isAp)
        : buildPremiumLayout(gc, copyType, companyName, companyTamil, address, phone, origin, gcDate, invoiceDate, invoiceValue, displayGoods, advance, totalFreight, balance, isAp);

      content.push({
        ...layoutObj,
        pageBreak: isLast ? undefined : 'after'
      });
    });
  });

  return {
    content,
    pageSize: 'A4',
    pageOrientation: 'portrait',
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
