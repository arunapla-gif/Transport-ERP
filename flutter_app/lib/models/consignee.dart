class Consignee {
  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? gstin;
  final String? phone;
  final String? branch;

  Consignee({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.gstin,
    this.phone,
    this.branch,
  });

  factory Consignee.fromJson(Map<String, dynamic> json) {
    String? cityVal = json['city'] as String?;
    String? gstinVal = json['gstin'] as String?;
    String? addrVal = json['address'] as String?;
    
    if (json['addresses'] != null && json['addresses'] is List && (json['addresses'] as List).isNotEmpty) {
      final firstAddr = (json['addresses'] as List).first;
      if (firstAddr is Map) {
        cityVal ??= firstAddr['city']?.toString();
        gstinVal ??= firstAddr['gstin']?.toString();
        addrVal ??= firstAddr['address']?.toString();
      }
    }

    return Consignee(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? json['displayName']?.toString() ?? 'Unnamed Consignee',
      address: addrVal,
      city: cityVal,
      gstin: gstinVal,
      phone: json['phone']?.toString(),
      branch: json['branch']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'gstin': gstin,
      'phone': phone,
      'branch': branch,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Consignee && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
