import { getPdfMake } from './pdfGenerator';

const chunkArray = (array, size) => {
  if (!array || array.length === 0) return [[]];
  const chunks = [];
  for (let i = 0; i < array.length; i += size) {
    chunks.push(array.slice(i, i + size));
  }
  return chunks;
};

const buildGdmPage = (gdm, allUnitOptions, forcePageBreak) => {
  let globalCases = 0, globalCartons = 0, globalBundles = 0;
  
  const rows = [];
  // Header Row 1
  rows.push([
    { text: 'S.NO', rowSpan: 2, fontSize: 9, bold: true, alignment: 'center', margin: [0, 10, 0, 2], fillColor: '#e2e8f0' },
    { text: 'GC.NO', rowSpan: 2, fontSize: 9, bold: true, alignment: 'center', margin: [0, 10, 0, 2], fillColor: '#e2e8f0' },
    { text: 'CONSIGNOR', rowSpan: 2, fontSize: 9, bold: true, alignment: 'center', margin: [0, 10, 0, 2], fillColor: '#e2e8f0' },
    { text: 'CONSIGNEE', rowSpan: 2, fontSize: 9, bold: true, alignment: 'center', margin: [0, 10, 0, 2], fillColor: '#e2e8f0' },
    { text: 'ARTICLES', colSpan: 3, fontSize: 9, bold: true, alignment: 'center', margin: [0, 2, 0, 2], fillColor: '#e2e8f0' },
    {},
    {},
    { text: 'FREIGHT', rowSpan: 2, fontSize: 9, bold: true, alignment: 'center', margin: [0, 10, 0, 2], fillColor: '#e2e8f0' }
  ]);
  // Header Row 2
  rows.push([
    {}, {}, {}, {},
    { text: 'C/S', fontSize: 9, bold: true, alignment: 'center', fillColor: '#e2e8f0' },
    { text: 'C/N', fontSize: 9, bold: true, alignment: 'center', fillColor: '#e2e8f0' },
    { text: 'BDL/S', fontSize: 9, bold: true, alignment: 'center', fillColor: '#e2e8f0' },
    {}
  ]);

  const formatDocNumber = (numStr) => numStr ? numStr.replace('-', ' - ') : '-';

  gdm.gcs?.forEach((gc, index) => {
    let rowCases = 0, rowCartons = 0, rowBundles = 0;
    gc.goods?.forEach(g => {
       const c = parseInt(g.articleCount) || 0;
       const unitStr = (g.units || '').toLowerCase().trim();
       const match = allUnitOptions.find(o => 
         (o.label || '').toLowerCase().trim() === unitStr || 
         (o.code || '').toLowerCase().trim() === unitStr ||
         (o.category || '').toLowerCase().trim() === unitStr
       );
       const cat = match ? (match.category || '').toLowerCase() : null;
       
       if (cat === 'cases') rowCases += c;
       else if (cat === 'cartons') rowCartons += c;
       else if (cat === 'bundles') rowBundles += c;
       else rowCases += c;
    });
    globalCases += rowCases;
    globalCartons += rowCartons;
    globalBundles += rowBundles;

    rows.push([
      { text: (index + 1).toString(), fontSize: 10, bold: true, alignment: 'center', margin: [2, 6, 2, 6] },
      {
        stack: [
          { text: formatDocNumber(gc.gcNumber), fontSize: 11, bold: true, alignment: 'center' }
        ],
        margin: [2, 6, 2, 6]
      },
      { text: (gc.consignor?.name || '').toUpperCase(), fontSize: 9, bold: true, margin: [2, 6, 2, 6] },
      { 
        stack: [
          { text: (gc.consignee?.name || '').toUpperCase(), fontSize: 9, bold: true, margin: [0, 0, 0, 2] },
          { text: `(${(gc.consignee?.city || '').toUpperCase()})`, fontSize: 9, bold: false }
        ],
        margin: [2, 6, 2, 6] 
      },
      { text: rowCases > 0 ? rowCases : '-', fontSize: 11, bold: true, alignment: 'center', margin: [2, 6, 2, 6] },
      { text: rowCartons > 0 ? rowCartons : '-', fontSize: 11, bold: true, alignment: 'center', margin: [2, 6, 2, 6] },
      { text: rowBundles > 0 ? rowBundles : '-', fontSize: 11, bold: true, alignment: 'center', margin: [2, 6, 2, 6] },
      { text: gc.freightTotal || '-', fontSize: 11, bold: true, alignment: 'right', margin: [2, 6, 2, 6] }
    ]);
  });

  // Totals Row
  const totalFreight = gdm.gcs?.reduce((sum, gc) => sum + (parseFloat(gc.freightTotal) || 0), 0) || '-';
  rows.push([
    { text: 'TOTAL', colSpan: 4, fontSize: 11, bold: true, alignment: 'right', margin: [4, 8, 4, 8], fillColor: '#f8fafc' },
    {}, {}, {},
    { text: globalCases > 0 ? globalCases : '-', fontSize: 12, bold: true, alignment: 'center', margin: [2, 8, 2, 8], fillColor: '#f8fafc' },
    { text: globalCartons > 0 ? globalCartons : '-', fontSize: 12, bold: true, alignment: 'center', margin: [2, 8, 2, 8], fillColor: '#f8fafc' },
    { text: globalBundles > 0 ? globalBundles : '-', fontSize: 12, bold: true, alignment: 'center', margin: [2, 8, 2, 8], fillColor: '#f8fafc' },
    { text: totalFreight, fontSize: 12, bold: true, alignment: 'right', margin: [4, 8, 4, 8], fillColor: '#f8fafc' }
  ]);

  const firstGc = gdm.gcs?.[0];
  const isAp = firstGc?.gcNumber?.startsWith('AP-');
  const companyName = isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
  const address = '359, THIRUTHAGAL ROAD, SIVAKASI-626123';
  const phone = isAp ? '9876543210' : '04562-221253';
  const gstin = isAp ? '33AADHP9192F1Z0' : '33AGKPK2374D1ZN';

  return {
    stack: [
      // Header
      {
        columns: [
          { 
            text: isAp ? 'AP' : 'BL', 
            width: '15%', 
            fontSize: 24, 
            bold: true, 
            alignment: 'center', 
            margin: [0, 10, 0, 0],
            color: 'black'
          },
          {
            width: '65%',
            stack: [
              { text: companyName, fontSize: 22, bold: true, alignment: 'center', margin: [0, 0, 0, 2], color: 'black' },
              { text: address, fontSize: 10, bold: true, alignment: 'center', color: 'black' }
            ]
          },
          {
            width: '20%',
            stack: [
              { text: `GSTIN: ${gstin}`, fontSize: 9, bold: true, alignment: 'right', color: 'black', margin: [0, 0, 0, 4] },
              { text: `CELL: ${phone}`, fontSize: 9, bold: true, alignment: 'right', color: 'black' }
            ],
            margin: [0, 10, 0, 0]
          }
        ],
        margin: [0, 0, 0, 10]
      },
      // Meta Info Grid
      {
        table: {
          widths: ['33%', '34%', '33%'],
          body: [
            [
              {
                stack: [
                  { text: 'Lorry No: ' + (gdm.vehicle?.vehicleNumber || gdm.vehicleNumber || '-'), fontSize: 10, bold: true, margin: [0, 0, 0, 4] },
                  { text: 'Owner: ' + (gdm.vehicle?.ownerName || '-'), fontSize: 9, bold: true },
                  { text: 'PH: ' + (gdm.vehicle?.ownerPhone || '-'), fontSize: 9, bold: true, margin: [0, 0, 0, 4] },
                  { text: 'Driver: ' + (gdm.vehicle?.driverName || '-'), fontSize: 9, bold: true },
                  { text: 'PH: ' + (gdm.vehicle?.driverPhone || '-'), fontSize: 9, bold: true }
                ],
                margin: [4, 4, 4, 4]
              },
              {
                stack: [
                  { text: 'TO', fontSize: 11, bold: true, alignment: 'center', margin: [0, 0, 0, 4], color: 'black' },
                  { text: (gdm.toName || 'AS PER BILLS').toUpperCase(), fontSize: 14, bold: true, alignment: 'center', margin: [0, 0, 0, 4] },
                  { text: `DELIVERY AT ${(gdm.deliveryAt || gdm.destination || 'N/A')}`.toUpperCase(), fontSize: 11, bold: true, alignment: 'center' }
                ],
                margin: [4, 4, 4, 4]
              },
              {
                stack: [
                  { text: 'GDM No: ' + formatDocNumber(gdm.gdmNumber), fontSize: 10, bold: true, margin: [0, 0, 0, 4] },
                  { text: 'Date: ' + new Date(gdm.date).toLocaleDateString('en-GB'), fontSize: 10, bold: true }
                ],
                alignment: 'right',
                margin: [4, 4, 4, 4]
              }
            ]
          ]
        },
        layout: {
          hLineWidth: function(i, node) { return 1; },
          vLineWidth: function(i, node) { return 1; },
          hLineColor: function(i, node) { return 'black'; },
          vLineColor: function(i, node) { return 'black'; },
        },
        margin: [0, 0, 0, 10]
      },
      // Table
      {
        table: {
          headerRows: 2,
          widths: ['6%', '14%', '22%', '23%', '7%', '7%', '7%', '14%'],
          body: rows
        },
        layout: {
          hLineWidth: function(i, node) { return 1; },
          vLineWidth: function(i, node) { return 1; },
          hLineColor: function(i, node) { return 'black'; },
          vLineColor: function(i, node) { return 'black'; },
        },
        margin: [0, 0, 0, 30]
      },
      // Signatures
      {
        columns: [
          {
            width: '50%',
            stack: [
              { text: '____________________', alignment: 'center', margin: [0, 0, 0, 4] },
              { text: 'Driver Signature', fontSize: 10, bold: true, alignment: 'center', color: 'black' }
            ]
          },
          {
            width: '50%',
            stack: [
              { text: '____________________', alignment: 'center', margin: [0, 0, 0, 4] },
              { text: 'For BELL LOGISTICS', fontSize: 10, bold: true, alignment: 'center', color: 'black' }
            ]
          }
        ]
      }
    ],
    pageBreak: forcePageBreak ? 'after' : undefined
  };
};

const buildCewbPage = (gdm, forcePageBreakAtEnd) => {
  const pages = [];
  const gcChunks = chunkArray(gdm.gcs || [], 10);
  
  if (gcChunks.length === 0) gcChunks.push([]);

  gcChunks.forEach((chunk, chunkIndex) => {
    const isLastChunk = chunkIndex === gcChunks.length - 1;
    const firstGc = gdm.gcs?.[0];
    const transporterGstin = firstGc?.ewbRawData?.transporterId || (firstGc?.companyString === 'BELL' ? '33AGKPK2374D1ZN' : '33AADHP9192F1Z0');
    const formattedDate = gdm.date ? new Date(gdm.date).toLocaleDateString('en-GB') : '-';
    
    const itemRows = [
      [
        { text: 'S.No.', bold: true, alignment: 'center', margin: [0, 4, 0, 4] },
        { text: 'E-WayBill No. & Date', bold: true, margin: [0, 4, 0, 4] },
        { text: 'E-WayBill By', bold: true, margin: [0, 4, 0, 4] },
        { text: 'Document No. & Date', bold: true, margin: [0, 4, 0, 4] },
        { text: 'Value', bold: true, alignment: 'right', margin: [0, 4, 0, 4] },
        { text: 'To', bold: true, margin: [0, 4, 0, 4] },
        { text: 'Valid Till Date', bold: true, margin: [0, 4, 0, 4] }
      ]
    ];

    chunk.forEach((gc, i) => {
      const ewbNo = gc.ewbNumber || gc.privateMark || '-';
      const ewbDate = gc.ewbRawData?.ewayBillDate || (gc.date ? new Date(gc.date).toLocaleDateString('en-GB') : '-');
      const ewbBy = gc.ewbRawData?.genGstin || gc.consignor?.gstin || '-';
      const docNo = gc.invoiceNumber || gc.gcNumber || '-';
      const docDate = gc.invoiceDate ? new Date(gc.invoiceDate).toLocaleDateString('en-GB') : (gc.date ? new Date(gc.date).toLocaleDateString('en-GB') : '-');
      const validTill = gc.ewbRawData?.validUpto || '-';

      itemRows.push([
        { text: (chunkIndex * 10 + i + 1).toString(), alignment: 'center', margin: [0, 4, 0, 4] },
        { text: `${ewbNo}\n${ewbDate}`, margin: [0, 4, 0, 4] },
        { text: ewbBy, margin: [0, 4, 0, 4] },
        { text: `${docNo}\n${docDate}`, margin: [0, 4, 0, 4] },
        { text: gc.invoiceValue ? parseFloat(gc.invoiceValue).toFixed(2) : '-', alignment: 'right', margin: [0, 4, 0, 4] },
        { text: `${gc.consignee?.name || ''}\n${gc.consignee?.city || ''}\nGST: ${gc.consignee?.gstin || ''}`, margin: [0, 4, 0, 4] },
        { text: validTill, margin: [0, 4, 0, 4] }
      ]);
    });

    if (chunk.length === 0) {
      itemRows.push([{ text: 'No Consignments Attached', colSpan: 7, alignment: 'center', margin: [0, 10, 0, 10] }, {}, {}, {}, {}, {}, {}]);
    }

    const pageContent = [
      {
        table: {
          widths: ['100%'],
          body: [
            [{ text: 'Consolidated E-Way Bill', alignment: 'center', bold: true, fontSize: 12, fillColor: '#e5e7eb', margin: [0, 6, 0, 6] }]
          ]
        },
        layout: 'headerLineOnly',
        margin: [0, 0, 0, 10]
      },
      { text: '1. Consolidated E-Way Bill Details', bold: true, fontSize: 10, margin: [0, 0, 0, 5] },
      {
        columns: [
          {
            width: '75%',
            table: {
              widths: ['40%', '60%'],
              body: [
                [{ text: 'Consolidated E-Way Bill No', fillColor: '#f9fafb', margin: [4, 4, 4, 4] }, { text: gdm.cewbNumber || 'PENDING', bold: true, margin: [4, 4, 4, 4] }],
                [{ text: 'Date', fillColor: '#f9fafb', margin: [4, 4, 4, 4] }, { text: formattedDate, bold: true, margin: [4, 4, 4, 4] }],
                [{ text: 'Generated By', fillColor: '#f9fafb', margin: [4, 4, 4, 4] }, { text: transporterGstin, bold: true, margin: [4, 4, 4, 4] }],
                [{ text: 'Transporter ID', fillColor: '#f9fafb', margin: [4, 4, 4, 4] }, { text: transporterGstin, bold: true, margin: [4, 4, 4, 4] }],
                [{ text: 'Vehicle No', fillColor: '#f9fafb', margin: [4, 4, 4, 4] }, { text: gdm.vehicle?.vehicleNumber || gdm.vehicleNumber || '-', bold: true, margin: [4, 4, 4, 4] }],
                [{ text: 'From', fillColor: '#f9fafb', margin: [4, 4, 4, 4] }, { text: 'SIVAKASI-TAMIL NADU', bold: true, margin: [4, 4, 4, 4] }],
                [{ text: 'Mode', fillColor: '#f9fafb', margin: [4, 4, 4, 4] }, { text: 'Road', bold: true, margin: [4, 4, 4, 4] }]
              ]
            },
            layout: {
              hLineWidth: function (i, node) { return 1; },
              vLineWidth: function (i, node) { return 1; },
            }
          },
          {
            width: '25%',
            stack: gdm.cewbNumber 
              ? [ { qr: gdm.cewbNumber, fit: 100, alignment: 'center', margin: [0, 10, 0, 0] } ]
              : [ { text: 'PENDING\nCEWB', alignment: 'center', margin: [0, 40, 0, 0], color: 'gray' } ]
          }
        ],
        margin: [0, 0, 0, 15]
      },
      { text: '2. Item Details', bold: true, fontSize: 10, margin: [0, 0, 0, 5] },
      {
        table: {
          headerRows: 1,
          widths: ['auto', '18%', '16%', '16%', 'auto', '20%', 'auto'],
          body: itemRows
        },
        layout: {
          hLineWidth: function (i, node) { return 1; },
          vLineWidth: function (i, node) { return 1; },
        },
        fontSize: 9
      }
    ];

    let pageBreak = undefined;
    if (!isLastChunk) {
      pageBreak = 'after';
    } else if (forcePageBreakAtEnd) {
      pageBreak = 'after';
    }

    pages.push({
      stack: pageContent,
      pageBreak
    });
  });

  return pages;
};

export const generateGdmPdfBlob = async (gdms, allUnitOptions, format = 'gdm') => {
  return new Promise((resolve, reject) => {
    let timeoutId = setTimeout(() => {
      reject(new Error("PDF generation timed out after 10 seconds."));
    }, 10000);

    try {
      const pdf = getPdfMake();

      pdf.fonts = {
        Times: {
          normal: 'Times New Roman.ttf',
          bold: 'Times New Roman Bold.ttf',
          italics: 'Times New Roman Italic.ttf',
          bolditalics: 'Times New Roman Bold Italic.ttf'
        }
      };

      const content = [];

      gdms.forEach((gdm, index) => {
        const isLastGdm = index === gdms.length - 1;
        
        if (format === 'gdm') {
          content.push(buildGdmPage(gdm, allUnitOptions, !isLastGdm));
        } else if (format === 'cewb') {
          const cewbPages = buildCewbPage(gdm, !isLastGdm);
          content.push(...cewbPages);
        } else if (format === 'gdm-combined') {
          content.push(buildGdmPage(gdm, allUnitOptions, true));
          const cewbPages = buildCewbPage(gdm, !isLastGdm);
          content.push(...cewbPages);
        }
      });

      const docDefinition = {
        content,
        pageSize: 'A4',
        pageOrientation: 'portrait',
        pageMargins: [20, 40, 20, 40], // Reduced left and right margins from 40 to 20
        defaultStyle: {
          font: 'Times',
          color: 'black'
        }
      };

      const pdfDocGenerator = pdf.createPdf(docDefinition);
      
      pdfDocGenerator.getDataUrl((dataUrl) => {
        clearTimeout(timeoutId);
        resolve(dataUrl);
      });
    } catch (error) {
      clearTimeout(timeoutId);
      console.error('Error during GDM PDF creation:', error);
      reject(error);
    }
  });
};
