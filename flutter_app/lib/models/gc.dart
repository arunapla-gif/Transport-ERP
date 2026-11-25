class GcItem {
  final int? id;
  final int? articleCount;
  final String? units;
  final String? hsn;
  final String? godown;
  final String description;
  final double? weight;
  final double? rate;
  final double? amount;

  GcItem({
    this.id,
    this.articleCount,
    this.units,
    this.hsn,
    this.godown,
    required this.description,
    this.weight,
    this.rate,
    this.amount,
  });

  factory GcItem.fromJson(Map<String, dynamic> json) {
    return GcItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      articleCount: json['articleCount'] != null ? int.tryParse(json['articleCount'].toString()) : null,
      units: json['units']?.toString(),
      hsn: json['hsn']?.toString(),
      godown: json['godown']?.toString(),
      description: json['description']?.toString() ?? '',
      weight: json['weight'] != null ? double.tryParse(json['weight'].toString()) : null,
      rate: json['rate'] != null ? double.tryParse(json['rate'].toString()) : null,
      amount: json['amount'] != null ? double.tryParse(json['amount'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'articles': articleCount,
      'units': units,
      'hsn': hsn,
      'godown': godown,
      'description': description,
      'weight': weight,
      'rate': rate,
      'amount': amount,
    };
  }
}

class Gc {
  final int? id;
  final String gcNumber;
  final String date;
  final int? consignorId;
  final String consignorName;
  final String? consignorGstin;
  final String? senderPhone;
  final int? consigneeId;
  final String consigneeName;
  final String? consigneeGstin;
  final String? receiverPhone;
  final String fromLocation;
  final String toLocation;
  final String? vehicleNumber;
  final String? driverName;
  final String paymentType; // 'PAID', 'TO_PAY', 'ACCOUNT'
  final double freightTotal;
  final double advancePaid;
  final double balanceFreight;
  final String? ewbNumber;
  final String? branch;
  final String? status;
  final int? gdmId;
  final String? privateMark;
  final List<GcItem> goods;

  Gc({
    this.id,
    required this.gcNumber,
    required this.date,
    this.consignorId,
    required this.consignorName,
    this.consignorGstin,
    this.senderPhone,
    this.consigneeId,
    required this.consigneeName,
    this.consigneeGstin,
    this.receiverPhone,
    required this.fromLocation,
    required this.toLocation,
    this.vehicleNumber,
    this.driverName,
    required this.paymentType,
    required this.freightTotal,
    this.advancePaid = 0.0,
    required this.balanceFreight,
    this.ewbNumber,
    this.branch,
    this.status,
    this.gdmId,
    this.privateMark,
    this.goods = const [],
  });

  factory Gc.fromJson(Map<String, dynamic> json) {
    List<GcItem> items = [];
    if (json['goods'] is List) {
      items = (json['goods'] as List).map((i) => GcItem.fromJson(i as Map<String, dynamic>)).toList();
    }

    final rawFreightType = (json['paymentType'] ?? json['freightType'] ?? 'To Pay').toString();
    final upperType = rawFreightType.toUpperCase();
    final String normalizedPaymentType;
    if (upperType == 'PAID') {
      normalizedPaymentType = 'PAID';
    } else if (upperType.contains('BILL') || upperType.contains('T.B.B') || upperType == 'ACCOUNT') {
      normalizedPaymentType = 'ACCOUNT';
    } else {
      normalizedPaymentType = 'TO_PAY';
    }

    return Gc(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      gcNumber: json['gcNumber']?.toString() ?? '',
      date: json['date']?.toString() ?? DateTime.now().toIso8601String(),
      consignorId: json['consignorId'] != null ? int.tryParse(json['consignorId'].toString()) : null,
      consignorName: json['consignorName']?.toString() ?? json['consignor']?['name']?.toString() ?? 'N/A',
      consignorGstin: json['consignorGstin']?.toString() ?? json['consignor']?['gstin']?.toString(),
      senderPhone: json['senderContactPhone']?.toString() ?? json['senderPhone']?.toString() ?? json['consignor']?['phone']?.toString(),
      consigneeId: json['consigneeId'] != null ? int.tryParse(json['consigneeId'].toString()) : null,
      consigneeName: json['consigneeName']?.toString() ?? json['consignee']?['name']?.toString() ?? 'N/A',
      consigneeGstin: json['consigneeGstin']?.toString() ?? json['consignee']?['gstin']?.toString(),
      receiverPhone: json['receiverContactPhone']?.toString() ?? json['receiverPhone']?.toString() ?? json['consignee']?['phone']?.toString(),
      fromLocation: json['fromLocation']?.toString() ?? json['consignor']?['city']?.toString() ?? 'SIVAKASI',
      toLocation: json['toLocation']?.toString() ?? json['consignee']?['city']?.toString() ?? 'DESTINATION',
      vehicleNumber: json['vehicleNumber']?.toString() ?? json['vehicle']?['vehicleNumber']?.toString() ?? json['vehicle']?['registrationNumber']?.toString(),
      driverName: json['driverName']?.toString(),
      paymentType: normalizedPaymentType,
      freightTotal: (json['freightTotal'] != null)
          ? double.parse(json['freightTotal'].toString())
          : 0.0,
      advancePaid: (json['advancePaid'] != null)
          ? double.parse(json['advancePaid'].toString())
          : 0.0,
      balanceFreight: (json['balanceFreight'] != null)
          ? double.parse(json['balanceFreight'].toString())
          : 0.0,
      ewbNumber: json['ewbNumber']?.toString(),
      branch: json['branch']?.toString() ?? 'MAIN',
      status: json['status']?.toString(),
      gdmId: json['gdmId'] != null ? int.tryParse(json['gdmId'].toString()) : null,
      privateMark: json['privateMark']?.toString(),
      goods: items,
    );
  }
}
