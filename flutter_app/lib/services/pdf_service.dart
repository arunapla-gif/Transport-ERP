import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static String _numberToWords(num number) {
    if (number == 0) return 'ZERO ONLY';
    final int n = number.round();
    const List<String> a = [
      '',
      'ONE ',
      'TWO ',
      'THREE ',
      'FOUR ',
      'FIVE ',
      'SIX ',
      'SEVEN ',
      'EIGHT ',
      'NINE ',
      'TEN ',
      'ELEVEN ',
      'TWELVE ',
      'THIRTEEN ',
      'FOURTEEN ',
      'FIFTEEN ',
      'SIXTEEN ',
      'SEVENTEEN ',
      'EIGHTEEN ',
      'NINETEEN '
    ];
    const List<String> b = [
      '',
      '',
      'TWENTY',
      'THIRTY',
      'FORTY',
      'FIFTY',
      'SIXTY',
      'SEVENTY',
      'EIGHTY',
      'NINETY'
    ];

    final String numStr = n.toString().padLeft(9, '0');
    if (numStr.length > 9) return 'AMOUNT TOO LARGE';

    final int crores = int.parse(numStr.substring(0, 2));
    final int lakhs = int.parse(numStr.substring(2, 4));
    final int thousands = int.parse(numStr.substring(4, 6));
    final int hundreds = int.parse(numStr.substring(6, 7));
    final int tensUnits = int.parse(numStr.substring(7, 9));

    String str = '';

    if (crores != 0) {
      if (crores < 20) {
        str += a[crores];
      } else {
        str += '${b[(crores / 10).floor()]} ${a[crores % 10]}';
      }
      str += 'CRORE ';
    }
    if (lakhs != 0) {
      if (lakhs < 20) {
        str += a[lakhs];
      } else {
        str += '${b[(lakhs / 10).floor()]} ${a[lakhs % 10]}';
      }
      str += 'LAKH ';
    }
    if (thousands != 0) {
      if (thousands < 20) {
        str += a[thousands];
      } else {
        str += '${b[(thousands / 10).floor()]} ${a[thousands % 10]}';
      }
      str += 'THOUSAND ';
    }
    if (hundreds != 0) {
      str += '${a[hundreds]}HUNDRED ';
    }
    if (tensUnits != 0) {
      if (str.isNotEmpty) str += 'AND ';
      if (tensUnits < 20) {
        str += a[tensUnits];
      } else {
        str += '${b[(tensUnits / 10).floor()]} ${a[tensUnits % 10]}';
      }
    }
    return '${str.trim()} ONLY';
  }

  static String _formatDdMmYyyy(dynamic rawDate) {
    if (rawDate == null) return '-';
    final s = rawDate.toString().trim();
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s);
    if (dt != null) {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
    return s.split(' ').first;
  }

  /// Generates Multi-Copy GC PDF:
  /// - LORRY COPY: Crimson border/header with full numeric Freight, Advance, Balance & Rupees in words.
  /// - CONSIGNOR COPY & CONSIGNEE COPY: Black border/header with numeric freight masked as 'FIXED'
  ///   (matching React's buildPremiumLayout), plus RCM & AT OWNER'S RISK legal clauses.
  static Future<Uint8List> generateGcPdf(
    List<Map<String, dynamic>> gcs,
    List<String> copies,
  ) async {
    final pdf = pw.Document();

    for (final gc in gcs) {
      for (final copyType in copies) {
        final isLorryCopy = copyType == 'LORRY COPY';
        final borderColor =
            isLorryCopy ? PdfColor.fromHex('#BE123C') : PdfColors.black;

        final isAp = gc['gcNumber']?.toString().startsWith('AP') ?? false;
        final companyName =
            isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
        const companyAddress = '359, THIRUTHANGAL ROAD, SIVAKASI - 626123';
        final companyGstin =
            isAp ? '33AADHP9192F1Z0' : '33AGKPK2374D1ZN';

        final boldText = pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 9.5,
          color: borderColor,
        );
        const normText = pw.TextStyle(fontSize: 9);
        const smallText = pw.TextStyle(fontSize: 7.5);

        final double totalFreight =
            double.tryParse(gc['freightTotal']?.toString() ?? '0') ?? 0;
        final double advance = double.tryParse(
              (gc['advancePaid'] ?? gc['advance'] ?? '0').toString(),
            ) ??
            0;
        final double balance =
            double.tryParse(gc['balanceFreight']?.toString() ?? '') ??
                (totalFreight - advance);
        final String freightType =
            (gc['freightType'] ?? 'To Pay').toString().toUpperCase();

        final cnor = gc['consignor'] as Map<String, dynamic>? ?? {};
        final cnee = gc['consignee'] as Map<String, dynamic>? ?? {};

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Container(
                height: PdfPageFormat.a4.height / 2,
                padding: const pw.EdgeInsets.all(12),
                child: pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: borderColor, width: 1.5),
                  ),
                  child: pw.Column(
                    children: [
                      // Header
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: borderColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: pw.Column(
                          children: [
                            pw.Row(
                              mainAxisAlignment:
                                  pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text(
                                  'AT OWNER\'S RISK | Subject to Sivakasi Jurisdiction',
                                  style: smallText,
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    color: borderColor,
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                  child: pw.Text(
                                    copyType,
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 3),
                            pw.Center(
                              child: pw.Text(
                                companyName,
                                style: pw.TextStyle(
                                  fontSize: 19,
                                  fontWeight: pw.FontWeight.bold,
                                  color: borderColor,
                                ),
                              ),
                            ),
                            pw.Center(
                              child: pw.Text(
                                '$companyAddress | GSTIN: $companyGstin',
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Meta Grid
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: borderColor,
                              width: 1.2,
                            ),
                          ),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Expanded(
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    _kvRow('GC No:', '${gc['gcNumber'] ?? ''}', normText, boldText),
                                    pw.SizedBox(height: 2),
                                    _kvRow('Date:', _formatDdMmYyyy(gc['date']), normText, boldText),
                                    pw.SizedBox(height: 2),
                                    _kvRow('Terms:', freightType, normText, boldText),
                                  ],
                                ),
                              ),
                            ),
                            pw.Container(width: 1.2, height: 46, color: borderColor),
                            pw.Expanded(
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    _kvRow('Invoice No:', '${gc['invoiceNumber'] ?? '-'}', normText, boldText),
                                    pw.SizedBox(height: 2),
                                    _kvRow('Inv Value:', 'Rs. ${gc['invoiceValue'] ?? '0'}', normText, boldText),
                                    pw.SizedBox(height: 2),
                                    _kvRow('EWB / Mark:', '${gc['ewbNumber'] ?? gc['privateMark'] ?? '-'}', normText, boldText),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Parties
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            bottom: pw.BorderSide(
                              color: borderColor,
                              width: 1.2,
                            ),
                          ),
                        ),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'CONSIGNOR:',
                                      style: pw.TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: borderColor,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text('${cnor['name'] ?? gc['consignorName'] ?? ''}', style: boldText, maxLines: 1),
                                    if ((cnor['address'] ?? '').toString().isNotEmpty)
                                      pw.Text('${cnor['address']}', style: smallText, maxLines: 1),
                                    pw.Text(
                                      '${cnor['city'] ?? 'SIVAKASI'} | GSTIN: ${cnor['gstin'] ?? 'URP'}',
                                      style: smallText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            pw.Container(width: 1.2, height: 56, color: borderColor),
                            pw.Expanded(
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text(
                                      'CONSIGNEE:',
                                      style: pw.TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: borderColor,
                                      ),
                                    ),
                                    pw.SizedBox(height: 2),
                                    pw.Text('${cnee['name'] ?? gc['consigneeName'] ?? ''}', style: boldText, maxLines: 1),
                                    if ((cnee['address'] ?? '').toString().isNotEmpty)
                                      pw.Text('${cnee['address']}', style: smallText, maxLines: 1),
                                    pw.Text(
                                      '${cnee['city'] ?? ''} | GSTIN: ${cnee['gstin'] ?? 'URP'}',
                                      style: smallText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Goods Table
                      pw.Expanded(
                        child: pw.TableHelper.fromTextArray(
                          headers: [
                            'ARTICLES',
                            'PACKING & DESCRIPTION',
                            'HSN',
                            'WEIGHT',
                            'RATE',
                            'AMOUNT'
                          ],
                          data: (gc['goods'] as List? ?? []).map((g) {
                            final qty = g['articleCount']?.toString() ??
                                g['articles']?.toString() ??
                                '0';
                            final unitDesc = [
                              g['units']?.toString() ?? '',
                              g['description']?.toString() ?? '',
                            ].where((s) => s.isNotEmpty).join(' - ');
                            final wt = g['weight']?.toString() ?? '-';
                            final rt = isLorryCopy
                                ? (g['rate']?.toString() ?? '-')
                                : 'FIXED';
                            final amt = isLorryCopy
                                ? (g['amount']?.toString() ?? '-')
                                : 'FIXED';
                            return [
                              qty,
                              unitDesc,
                              g['hsn']?.toString() ?? '3604',
                              wt,
                              rt,
                              amt,
                            ];
                          }).toList(),
                          border: pw.TableBorder(
                            verticalInside:
                                pw.BorderSide(width: 0.8, color: borderColor),
                            bottom:
                                pw.BorderSide(width: 1.2, color: borderColor),
                          ),
                          headerStyle: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 8,
                            color: borderColor,
                          ),
                          cellStyle: const pw.TextStyle(fontSize: 8.5),
                          cellPadding: const pw.EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 5,
                          ),
                          headerDecoration: pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(
                                width: 1.2,
                                color: borderColor,
                              ),
                            ),
                          ),
                          cellAlignments: {
                            0: pw.Alignment.center,
                            1: pw.Alignment.centerLeft,
                            2: pw.Alignment.center,
                            3: pw.Alignment.centerRight,
                            4: pw.Alignment.centerRight,
                            5: pw.Alignment.centerRight,
                          },
                        ),
                      ),

                      // Financial Summary (Masked on Consignor / Consignee copies)
                      pw.SizedBox(
                        height: 54,
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                          children: [
                            pw.Expanded(
                              flex: 2,
                              child: pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.spaceBetween,
                                  children: [
                                    pw.Text(
                                      'Rupees (In Words): ${isLorryCopy ? _numberToWords(totalFreight) : "***"}',
                                      style: pw.TextStyle(
                                        fontSize: 8,
                                        fontWeight: pw.FontWeight.bold,
                                      ),
                                    ),
                                    pw.Text(
                                      'GST RCM PAYABLE BY CONSIGNEE / CONSIGNOR',
                                      style: pw.TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: pw.FontWeight.bold,
                                        color: borderColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            pw.Container(width: 1.2, color: borderColor),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Column(
                                children: [
                                  _finSummaryCell(
                                    'Freight',
                                    isLorryCopy
                                        ? totalFreight.toStringAsFixed(2)
                                        : 'FIXED',
                                    borderColor,
                                    hasBottomBorder: true,
                                  ),
                                  _finSummaryCell(
                                    'Advance',
                                    isLorryCopy
                                        ? advance.toStringAsFixed(2)
                                        : '-',
                                    borderColor,
                                    hasBottomBorder: true,
                                  ),
                                  _finSummaryCell(
                                    'Balance ($freightType)',
                                    isLorryCopy
                                        ? balance.toStringAsFixed(2)
                                        : 'FIXED',
                                    borderColor,
                                    hasBottomBorder: false,
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Signatures
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(
                            top: pw.BorderSide(color: borderColor, width: 1.2),
                          ),
                        ),
                        padding: const pw.EdgeInsets.only(
                          top: 16,
                          bottom: 5,
                          left: 10,
                          right: 10,
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Consignee / Receiver Signature', style: smallText),
                            pw.Text('Driver Signature', style: smallText),
                            pw.Text('For $companyName', style: boldText),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    }
    return pdf.save();
  }

  static pw.Widget _kvRow(
    String k,
    String v,
    pw.TextStyle ks,
    pw.TextStyle vs,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(k, style: ks),
        pw.Flexible(child: pw.Text(v, style: vs, maxLines: 1)),
      ],
    );
  }

  static pw.Widget _finSummaryCell(
    String label,
    String value,
    PdfColor borderColor, {
    required bool hasBottomBorder,
    bool bold = false,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5),
        decoration: hasBottomBorder
            ? pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderColor, width: 0.8),
                ),
              )
            : null,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Backward-compatible single GDM Standard PDF generator.
  static Future<Uint8List> generateGdmPreview(Map<String, dynamic> gdm) async {
    return generateGdmsPdf([gdm], format: 'gdm');
  }

  /// Generates Standard GDM ('gdm'), Official NIC CEWB ('cewb'), or Combined ('gdm-combined')
  /// across one or multiple GDMs in a single batch PDF.
  static Future<Uint8List> generateGdmsPdf(
    List<Map<String, dynamic>> gdms, {
    String format = 'gdm',
  }) async {
    final pdf = pw.Document();

    for (final gdm in gdms) {
      if (format == 'gdm' || format == 'gdm-combined') {
        _addStandardGdmPages(pdf, gdm);
      }
      if (format == 'cewb' || format == 'gdm-combined') {
        _addOfficialCewbPages(pdf, gdm);
      }
    }

    return pdf.save();
  }

  static void _addStandardGdmPages(pw.Document pdf, Map<String, dynamic> gdm) {
    final gcs = gdm['gcs'] as List? ?? [];
    final firstGcNo =
        gcs.isNotEmpty ? (gcs.first['gcNumber']?.toString() ?? '') : '';
    final isAp = firstGcNo.startsWith('AP') ||
        (gdm['gdmNumber']?.toString().startsWith('AP') ?? false);

    final companyName = isAp ? 'A.P. ROADLINES' : 'THE BELL LORRY AGENCIES';
    const address = '359, THIRUTHANGAL ROAD, SIVAKASI-626123';
    final phone = isAp ? '9876543210' : '04562-221253';
    final gstin = isAp ? '33AADHP9192F1Z0' : '33AGKPK2374D1ZN';

    final boldText = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5);
    const normText = pw.TextStyle(fontSize: 9);

    int globalCases = 0;
    int globalCartons = 0;
    int globalBundles = 0;
    double totalFreight = 0.0;

    final List<List<String>> rows = [];
    for (int i = 0; i < gcs.length; i++) {
      final gc = gcs[i] as Map<String, dynamic>;
      int rowCases = 0, rowCartons = 0, rowBundles = 0;

      final goodsList = gc['goods'] as List? ?? [];
      if (goodsList.isNotEmpty) {
        for (final g in goodsList) {
          final int count = int.tryParse(
                (g['articleCount'] ?? g['articles'] ?? '0').toString(),
              ) ??
              0;
          final unitStr = (g['units'] ?? '').toString().toLowerCase();
          if (unitStr.contains('carton') || unitStr.contains('ctn')) {
            rowCartons += count;
          } else if (unitStr.contains('bundle') || unitStr.contains('bdl')) {
            rowBundles += count;
          } else {
            rowCases += count;
          }
        }
      } else {
        rowCases +=
            int.tryParse((gc['articles'] ?? '0').toString()) ?? 0;
      }

      globalCases += rowCases;
      globalCartons += rowCartons;
      globalBundles += rowBundles;

      final freight =
          double.tryParse(gc['freightTotal']?.toString() ?? '0') ?? 0.0;
      totalFreight += freight;

      final cneeName = (gc['consignee']?['name'] ?? '').toString().toUpperCase();
      final cneeCity = (gc['consignee']?['city'] ?? '').toString().toUpperCase();

      rows.add([
        '${i + 1}',
        (gc['gcNumber'] ?? '').toString(),
        (gc['consignor']?['name'] ?? '').toString().toUpperCase(),
        cneeCity.isNotEmpty ? '$cneeName\n($cneeCity)' : cneeName,
        rowCases > 0 ? '$rowCases' : '-',
        rowCartons > 0 ? '$rowCartons' : '-',
        rowBundles > 0 ? '$rowBundles' : '-',
        freight > 0 ? freight.toStringAsFixed(2) : '-',
      ]);
    }

    rows.add([
      '',
      '',
      '',
      'TOTAL',
      globalCases > 0 ? '$globalCases' : '-',
      globalCartons > 0 ? '$globalCartons' : '-',
      globalBundles > 0 ? '$globalBundles' : '-',
      totalFreight.toStringAsFixed(2),
    ]);

    final vehicle = gdm['vehicle'] as Map<String, dynamic>? ?? {};

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
              ),
              child: pw.Column(
                children: [
                  // Header
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                      ),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          isAp ? 'AP' : 'BL',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Column(
                          children: [
                            pw.Text(
                              companyName,
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              address,
                              style: pw.TextStyle(
                                fontSize: 9.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('GSTIN: $gstin', style: boldText),
                            pw.Text('CELL: $phone', style: boldText),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Meta Grid
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(color: PdfColors.black, width: 1.5),
                      ),
                    ),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Lorry No: ${vehicle['vehicleNumber'] ?? gdm['vehicleNumber'] ?? '-'}',
                                  style: boldText,
                                ),
                                pw.Text(
                                  'Owner: ${vehicle['ownerName'] ?? '-'} (${vehicle['ownerPhone'] ?? '-'})',
                                  style: normText,
                                ),
                                pw.Text(
                                  'Driver: ${gdm['driverName'] ?? vehicle['driverName'] ?? '-'} (${gdm['driverPhone'] ?? vehicle['driverPhone'] ?? '-'})',
                                  style: normText,
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.Container(width: 1.2, height: 54, color: PdfColors.black),
                        pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              children: [
                                pw.Text('TO', style: boldText),
                                pw.Text(
                                  (gdm['toName'] ?? 'AS PER BILLS').toString().toUpperCase(),
                                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                                ),
                                pw.Text(
                                  'DELIVERY AT ${(gdm['deliveryAt'] ?? gdm['destination'] ?? 'N/A').toString().toUpperCase()}',
                                  style: boldText,
                                ),
                              ],
                            ),
                          ),
                        ),
                        pw.Container(width: 1.2, height: 54, color: PdfColors.black),
                        pw.Expanded(
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text('GDM No: ${gdm['gdmNumber'] ?? ''}', style: boldText),
                                pw.SizedBox(height: 2),
                                pw.Text('Date: ${_formatDdMmYyyy(gdm['date'])}', style: boldText),
                                if ((gdm['cewbNumber'] ?? '').toString().isNotEmpty)
                                  pw.Text('CEWB: ${gdm['cewbNumber']}', style: normText),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 8-Column Split Table (C/S | C/N | BDL/S)
                  pw.TableHelper.fromTextArray(
                    headers: [
                      'S.NO',
                      'GC.NO',
                      'CONSIGNOR',
                      'CONSIGNEE',
                      'C/S',
                      'C/N',
                      'BDL/S',
                      'FREIGHT'
                    ],
                    data: rows,
                    border: const pw.TableBorder(
                      horizontalInside:
                          pw.BorderSide(width: 0.8, color: PdfColors.grey500),
                      verticalInside:
                          pw.BorderSide(width: 1, color: PdfColors.black),
                    ),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 8.5,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#E2E8F0'),
                      border: const pw.Border(
                        bottom: pw.BorderSide(width: 1.5, color: PdfColors.black),
                      ),
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 8.5),
                    cellPadding: const pw.EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 4,
                    ),
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.center,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.centerLeft,
                      4: pw.Alignment.center,
                      5: pw.Alignment.center,
                      6: pw.Alignment.center,
                      7: pw.Alignment.centerRight,
                    },
                  ),

                  // Signatures
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        top: pw.BorderSide(width: 1.5, color: PdfColors.black),
                      ),
                    ),
                    padding: const pw.EdgeInsets.only(
                      top: 28,
                      bottom: 8,
                      left: 16,
                      right: 16,
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Driver Signature', style: boldText),
                        pw.Text('For $companyName', style: boldText),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );
  }

  /// Official NIC Consolidated E-Way Bill (Form GST EWB-02) with QR Code
  static void _addOfficialCewbPages(pw.Document pdf, Map<String, dynamic> gdm) {
    final gcs = gdm['gcs'] as List? ?? [];
    final List<List<dynamic>> chunks = [];
    if (gcs.isEmpty) {
      chunks.add([]);
    } else {
      for (int i = 0; i < gcs.length; i += 10) {
        chunks.add(gcs.sublist(i, (i + 10 > gcs.length) ? gcs.length : i + 10));
      }
    }

    final firstGc = gcs.isNotEmpty ? gcs.first as Map<String, dynamic> : {};
    final isBell = (firstGc['gcNumber']?.toString().startsWith('BELL') ?? false) ||
        (gdm['gdmNumber']?.toString().startsWith('BELL') ?? false);
    final transporterGstin = firstGc['ewbRawData']?['transporterId']?.toString() ??
        (isBell ? '33AGKPK2374D1ZN' : '33AADHP9192F1Z0');
    final cewbNo = (gdm['cewbNumber'] ?? '').toString().trim();
    final formattedDate = _formatDdMmYyyy(gdm['date']);
    final vehicleNo =
        (gdm['vehicle']?['vehicleNumber'] ?? gdm['vehicleNumber'] ?? '-').toString();

    for (int chunkIdx = 0; chunkIdx < chunks.length; chunkIdx++) {
      final chunk = chunks[chunkIdx];
      final List<List<String>> itemRows = [];

      for (int i = 0; i < chunk.length; i++) {
        final gc = chunk[i] as Map<String, dynamic>;
        final rawEwb = gc['ewbRawData'] as Map<String, dynamic>? ?? {};
        final ewbNo = (gc['ewbNumber'] ?? gc['privateMark'] ?? '-').toString();
        final ewbDate = _formatDdMmYyyy(rawEwb['ewayBillDate'] ?? gc['date']);
        final ewbBy = (rawEwb['genGstin'] ?? gc['consignor']?['gstin'] ?? '-').toString();
        final docNo = (gc['invoiceNumber'] ?? gc['gcNumber'] ?? '-').toString();
        final docDate = _formatDdMmYyyy(gc['invoiceDate'] ?? gc['date']);
        final validTill = _formatDdMmYyyy(rawEwb['validUpto']);

        final cnee = gc['consignee'] as Map<String, dynamic>? ?? {};
        final toPlace = [cnee['city'], cnee['state']]
            .where((e) => e != null && e.toString().trim().isNotEmpty)
            .join(' - ')
            .toUpperCase();
        final toPin = (cnee['pincode'] ?? '').toString();
        final toCol = toPlace.isNotEmpty
            ? (toPin.isNotEmpty ? '$toPlace\n$toPin' : toPlace)
            : '-';

        final invVal = double.tryParse(gc['invoiceValue']?.toString() ?? '');
        itemRows.add([
          '${chunkIdx * 10 + i + 1}',
          '$ewbNo\n$ewbDate',
          ewbBy,
          '$docNo\n$docDate',
          invVal != null ? invVal.toStringAsFixed(2) : '-',
          toCol,
          validTill,
        ]);
      }

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 8),
                  color: PdfColor.fromHex('#E5E7EB'),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    'Consolidated E-Way Bill (Form GST EWB-02)',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  '1. Consolidated E-Way Bill Details',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.TableHelper.fromTextArray(
                        headers: const [],
                        data: [
                          ['Consolidated E-Way Bill No', cewbNo.isNotEmpty ? cewbNo : 'PENDING'],
                          ['Date', formattedDate],
                          ['Transporter ID', transporterGstin],
                          ['Vehicle No', vehicleNo],
                          ['From', 'SIVAKASI-TAMIL NADU'],
                          ['Mode', 'Road'],
                        ],
                        border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        cellPadding: const pw.EdgeInsets.all(5),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Container(
                        height: 115,
                        alignment: pw.Alignment.center,
                        child: cewbNo.isNotEmpty
                            ? pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: cewbNo,
                                width: 95,
                                height: 95,
                              )
                            : pw.Text(
                                'PENDING\nCEWB QR',
                                textAlign: pw.TextAlign.center,
                                style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  '2. Item Details',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'S.No.',
                    'E-WayBill No. & Date',
                    'E-WayBill By',
                    'Document No. & Date',
                    'Value',
                    'To',
                    'Valid Till Date',
                  ],
                  data: itemRows.isEmpty
                      ? [
                          ['-', 'No Consignments Attached', '-', '-', '-', '-', '-']
                        ]
                      : itemRows,
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8.5,
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#F3F4F6'),
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellPadding: const pw.EdgeInsets.all(4),
                  cellAlignments: {
                    0: pw.Alignment.center,
                    4: pw.Alignment.centerRight,
                  },
                ),
              ],
            );
          },
        ),
      );
    }
  }
}
