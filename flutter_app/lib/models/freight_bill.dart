class FreightBill {
  final int id;
  final String billNumber;
  final DateTime? date;
  final String? transporterName;
  final String? lorryNumber;
  final String? fromLocation;
  final String? toLocation;
  final String? gcNumbers;
  
  final double? grossFreight;
  final double? advancePaid;
  final double? commission;
  final double? shortage;
  final double? tds;
  final double? netBalance;
  
  final String? paymentMode;
  final String? remarks;
  final String? status;
  final String? branch;

  FreightBill({
    required this.id,
    required this.billNumber,
    this.date,
    this.transporterName,
    this.lorryNumber,
    this.fromLocation,
    this.toLocation,
    this.gcNumbers,
    this.grossFreight,
    this.advancePaid,
    this.commission,
    this.shortage,
    this.tds,
    this.netBalance,
    this.paymentMode,
    this.remarks,
    this.status,
    this.branch,
  });

  factory FreightBill.fromJson(Map<String, dynamic> json) {
    return FreightBill(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      billNumber: json['billNumber']?.toString() ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      transporterName: json['transporterName']?.toString(),
      lorryNumber: json['lorryNumber']?.toString(),
      fromLocation: json['fromLocation']?.toString(),
      toLocation: json['toLocation']?.toString(),
      gcNumbers: json['gcNumbers']?.toString(),
      grossFreight: json['grossFreight'] != null ? double.tryParse(json['grossFreight'].toString()) : null,
      advancePaid: json['advancePaid'] != null ? double.tryParse(json['advancePaid'].toString()) : null,
      commission: json['commission'] != null ? double.tryParse(json['commission'].toString()) : null,
      shortage: json['shortage'] != null ? double.tryParse(json['shortage'].toString()) : null,
      tds: json['tds'] != null ? double.tryParse(json['tds'].toString()) : null,
      netBalance: json['netBalance'] != null ? double.tryParse(json['netBalance'].toString()) : null,
      paymentMode: json['paymentMode']?.toString(),
      remarks: json['remarks']?.toString(),
      status: json['status']?.toString(),
      branch: json['branch']?.toString(),
    );
  }
}
