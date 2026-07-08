import { getPdfMake } from './pdfGenerator';

export const generateGdmPdfBlob = async (gdms, allUnitOptions) => {
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
        let globalCases = 0, globalCartons = 0, globalBundles = 0;
        
        const rows = [];
        // Header Row 1
        rows.push([
          { text: 'GC.NO / EWB', rowSpan: 2, fontSize: 10, bold: true, alignment: 'center', margin: [2, 10, 2, 2] },
          { text: 'CONSIGNOR', rowSpan: 2, fontSize: 10, bold: true, alignment: 'center', margin: [2, 10, 2, 2] },
          { text: 'CONSIGNEE', rowSpan: 2, fontSize: 10, bold: true, alignment: 'center', margin: [2, 10, 2, 2] },
          { text: 'ARTICLES', colSpan: 3, fontSize: 10, bold: true, alignment: 'center', margin: [2, 2, 2, 2] },
          {},
          {},
          { text: 'FREIGHT', rowSpan: 2, fontSize: 10, bold: true, alignment: 'center', margin: [2, 10, 2, 2] }
        ]);
        // Header Row 2
        rows.push([
          {}, {}, {},
          { text: 'C/S', fontSize: 9, bold: true, alignment: 'center' },
          { text: 'C/N', fontSize: 9, bold: true, alignment: 'center' },
          { text: 'BDL/S', fontSize: 9, bold: true, alignment: 'center' },
          {}
        ]);

        gdm.gcs?.forEach(gc => {
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
            {
              stack: [
                { text: gc.gcNumber.replace('BELL-', '').replace('AP-', ''), fontSize: 11, bold: true, alignment: 'center' },
                ...(gc.privateMark ? [{ text: gc.privateMark, fontSize: 8, alignment: 'center', margin: [0, 2, 0, 0] }] : [])
              ],
              margin: [2, 4, 2, 4]
            },
            { text: (gc.consignor?.name || '').toUpperCase(), fontSize: 9, bold: true, margin: [2, 4, 2, 4] },
            { text: (gc.consignee?.name || '').toUpperCase(), fontSize: 9, bold: true, margin: [2, 4, 2, 4] },
            { text: rowCases > 0 ? rowCases : '-', fontSize: 11, bold: true, alignment: 'center', margin: [2, 4, 2, 4] },
            { text: rowCartons > 0 ? rowCartons : '-', fontSize: 11, bold: true, alignment: 'center', margin: [2, 4, 2, 4] },
            { text: rowBundles > 0 ? rowBundles : '-', fontSize: 11, bold: true, alignment: 'center', margin: [2, 4, 2, 4] },
            { text: gc.freightTotal || '-', fontSize: 11, bold: true, alignment: 'right', margin: [2, 4, 2, 4] }
          ]);
        });


        // Totals Row
        const totalFreight = gdm.gcs?.reduce((sum, gc) => sum + (parseFloat(gc.freightTotal) || 0), 0) || '-';
        rows.push([
          { text: 'TOTAL', colSpan: 3, fontSize: 11, bold: true, alignment: 'right', margin: [4, 6, 4, 6] },
          {}, {},
          { text: globalCases > 0 ? globalCases : '-', fontSize: 12, bold: true, alignment: 'center', margin: [2, 6, 2, 6] },
          { text: globalCartons > 0 ? globalCartons : '-', fontSize: 12, bold: true, alignment: 'center', margin: [2, 6, 2, 6] },
          { text: globalBundles > 0 ? globalBundles : '-', fontSize: 12, bold: true, alignment: 'center', margin: [2, 6, 2, 6] },
          { text: totalFreight, fontSize: 12, bold: true, alignment: 'right', margin: [4, 6, 4, 6] }
        ]);

        const pageBreak = index < gdms.length - 1 ? 'after' : undefined;

        // Dynamic Company Profile
        const firstGc = gdm.gcs?.[0];
        const isAp = firstGc?.gcNumber?.startsWith('AP-');
        const companyName = isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
        const companyTamil = isAp ? 'ஸ்ரீ அய்யனார் துணை' : 'ஸ்ரீ திருச்செந்தூர் முருகன் துணை';
        const address = '359, THIRUTHAGAL ROAD, SIVAKASI-626123';
        const phone = isAp ? '9876543210' : '04562-221253';
        const gstin = isAp ? '33AADHP9192F1Z0' : '33AGKPK2374D1ZN';

        content.push({
          stack: [
            // Header
            {
              columns: [
                { text: isAp ? 'AP' : 'BL', width: '15%', fontSize: 24, bold: true, alignment: 'center', margin: [0, 10, 0, 0] },
                {
                  width: '55%',
                  stack: [
                    { text: companyTamil, fontSize: 10, bold: true, margin: [0, 0, 0, 2] },
                    { text: companyName, fontSize: 24, bold: true, margin: [0, 0, 0, 2] },
                    { text: address, fontSize: 10, bold: true }
                  ]
                },
                {
                  width: '30%',
                  stack: [
                    { text: `GSTIN: ${gstin}`, fontSize: 10, bold: true, alignment: 'right', margin: [0, 0, 0, 4] },
                    { text: `CELL: ${phone}`, fontSize: 10, bold: true, alignment: 'right' }
                  ],
                  margin: [0, 10, 0, 0]
                }
              ],
              margin: [0, 0, 0, 10]
            },
            // Divider
            { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 515, y2: 0, lineWidth: 2 }], margin: [0, 0, 0, 10] },
            // Meta Info
            {
              table: {
                widths: ['33%', '34%', '33%'],
                body: [
                  [
                    {
                      stack: [
                        { text: 'GDM No: ' + (gdm.gdmNumber || '-'), fontSize: 10, bold: true, margin: [0, 0, 0, 4] },
                        { text: 'Date: ' + new Date(gdm.date).toLocaleDateString('en-GB') + ' - ' + (gdm.time || ''), fontSize: 10, bold: true, margin: [0, 0, 0, 4] },
                        { text: 'Lorry No: ' + (gdm.vehicle?.vehicleNumber || gdm.vehicleNumber || '-'), fontSize: 12, bold: true }
                      ],
                      margin: [4, 4, 4, 4]
                    },
                    {
                      stack: [
                        { text: 'MASTER CEWB NUMBER', fontSize: 9, bold: true, alignment: 'center', margin: [0, 0, 0, 4] },
                        { text: gdm.cewbNumber || 'PENDING', fontSize: 16, bold: true, alignment: 'center' }
                      ],
                      margin: [4, 8, 4, 4]
                    },
                    {
                      stack: [
                        { text: 'Destination: ' + (gdm.destination || 'N/A'), fontSize: 10, bold: true, margin: [0, 0, 0, 4] },
                        { text: 'Driver: ' + (gdm.vehicle?.driverName || '-') + ' (' + (gdm.vehicle?.driverPhone || '-') + ')', fontSize: 10, bold: true }
                      ],
                      margin: [4, 4, 4, 4]
                    }
                  ]
                ]
              },
              margin: [0, 0, 0, 10]
            },
            // Table
            {
              table: {
                headerRows: 2,
                widths: ['15%', '27.5%', '27.5%', '6%', '6%', '6%', '12%'],
                body: rows
              },
              layout: {
                hLineWidth: function(i, node) { return 1; },
                vLineWidth: function(i, node) { return 1; }
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
                    { text: 'Driver Signature', fontSize: 10, bold: true, alignment: 'center' }
                  ]
                },
                {
                  width: '50%',
                  stack: [
                    { text: '____________________', alignment: 'center', margin: [0, 0, 0, 4] },
                    { text: 'For BELL LOGISTICS', fontSize: 10, bold: true, alignment: 'center' }
                  ]
                }
              ]
            }
          ],
          pageBreak
        });
      });

      const docDefinition = {
        content,
        pageSize: 'A4',
        pageOrientation: 'portrait',
        pageMargins: [40, 40, 40, 40],
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
