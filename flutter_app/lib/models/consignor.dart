class Consignor {
  final int id;
  final String name;
  final String? legalName;
  final String? address;
  final String? city;
  final String? gstin;
  final String? phone;
  final String? branch;
  final String? panNumber;
  final String? email;
  final String? district;
  final String? state;
  final String? stateCode;
  final String? pincode;
  final String? group;
  final String? migrationType;
  final bool isActive;
  final List<Map<String, dynamic>> addresses;
  final List<String> tradeNames;
  final int? parentId;

  Consignor({
    required this.id,
    required this.name,
    this.legalName,
    this.address,
    this.city,
    this.gstin,
    this.phone,
    this.branch,
    this.panNumber,
    this.email,
    this.district,
    this.state,
    this.stateCode,
    this.pincode,
    this.group,
    this.migrationType,
    this.isActive = true,
    this.addresses = const [],
    this.tradeNames = const [],
    this.parentId,
  });

  factory Consignor.fromJson(Map<String, dynamic> json) {
    String? cityVal = json['city']?.toString();
    String? gstinVal = json['gstin']?.toString();
    String? addrVal = json['address']?.toString();

    final List<Map<String, dynamic>> parsedAddresses = [];
    if (json['addresses'] is List) {
      for (final item in (json['addresses'] as List)) {
        if (item is Map) {
          parsedAddresses.add(Map<String, dynamic>.from(item));
        }
      }
      if (parsedAddresses.isNotEmpty) {
        final firstAddr = parsedAddresses.first;
        if (cityVal == null || cityVal.isEmpty) cityVal = firstAddr['city']?.toString();
        if (gstinVal == null || gstinVal.isEmpty) gstinVal = firstAddr['gstin']?.toString();
        if (addrVal == null || addrVal.isEmpty) addrVal = firstAddr['address']?.toString();
      }
    }

    final List<String> parsedTradeNames = [];
    if (json['tradeNames'] is List) {
      for (final t in (json['tradeNames'] as List)) {
        if (t != null && t.toString().trim().isNotEmpty) {
          parsedTradeNames.add(t.toString().trim());
        }
      }
    }

    return Consignor(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? json['displayName']?.toString() ?? 'Unnamed Consignor',
      legalName: json['legalName']?.toString(),
      address: addrVal,
      city: cityVal,
      gstin: gstinVal,
      phone: json['phone']?.toString(),
      branch: json['branch']?.toString(),
      panNumber: json['panNumber']?.toString() ?? json['pan']?.toString(),
      email: json['email']?.toString(),
      district: json['district']?.toString(),
      state: json['state']?.toString(),
      stateCode: json['stateCode']?.toString(),
      pincode: json['pincode']?.toString() ?? json['pin']?.toString(),
      group: json['group']?.toString() ?? json['partyGroup']?.toString(),
      migrationType: json['migrationType']?.toString(),
      isActive: json['isActive'] != false,
      addresses: parsedAddresses,
      tradeNames: parsedTradeNames,
      parentId: json['parentId'] != null ? int.tryParse(json['parentId'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'legalName': legalName,
      'address': address,
      'city': city,
      'gstin': gstin,
      'phone': phone,
      'branch': branch,
      'panNumber': panNumber,
      'email': email,
      'district': district,
      'state': state,
      'stateCode': stateCode,
      'pincode': pincode,
      'group': group,
      'migrationType': migrationType,
      'isActive': isActive,
      'addresses': addresses,
      'tradeNames': tradeNames,
      'parentId': parentId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Consignor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
