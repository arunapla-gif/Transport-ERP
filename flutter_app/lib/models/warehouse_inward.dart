class WarehouseInward {
  final int? id;
  final int? receiptNo;
  final DateTime? createdAt;
  final String? ewayBillNo;
  final String consignorName;
  final String consigneeName;
  final String? consigneeCity;
  final int articles;
  final String godownNo;
  final String? remarks;
  final String branch;
  final String? consignorPhone; // Kept for UI state if needed, though backend might drop it

  WarehouseInward({
    this.id,
    this.receiptNo,
    this.createdAt,
    this.ewayBillNo,
    required this.consignorName,
    required this.consigneeName,
    this.consigneeCity,
    required this.articles,
    required this.godownNo,
    this.remarks,
    this.branch = 'MAIN',
    this.consignorPhone,
  });

  factory WarehouseInward.fromJson(Map<String, dynamic> json) {
    return WarehouseInward(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      receiptNo: json['receiptNo'] != null ? int.tryParse(json['receiptNo'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      ewayBillNo: json['ewayBillNo']?.toString(),
      consignorName: json['consignorName']?.toString() ?? '',
      consigneeName: json['consigneeName']?.toString() ?? '',
      consigneeCity: json['consigneeCity']?.toString(),
      articles: json['articles'] != null ? int.parse(json['articles'].toString()) : 0,
      godownNo: json['godownNo']?.toString() ?? '',
      remarks: json['remarks']?.toString(),
      branch: json['branch']?.toString() ?? 'MAIN',
      consignorPhone: json['consignorPhone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (ewayBillNo != null) 'ewayBillNo': ewayBillNo,
      'consignorName': consignorName,
      'consigneeName': consigneeName,
      if (consigneeCity != null) 'consigneeCity': consigneeCity,
      'articles': articles,
      'godownNo': godownNo,
      if (remarks != null) 'remarks': remarks,
      'branch': branch,
      if (consignorPhone != null) 'consignorPhone': consignorPhone,
    };
  }
}
