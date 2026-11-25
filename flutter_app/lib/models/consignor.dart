class Consignor {
  final int id;
  final String name;
  final String? address;
  final String? city;
  final String? gstin;
  final String? phone;
  final String? branch;
  final String? panNumber;
  final String? email;
  final String? district;
  final String? state;
  final String? pincode;
  final String? group;

  Consignor({
    required this.id,
    required this.name,
    this.address,
    this.city,
    this.gstin,
    this.phone,
    this.branch,
    this.panNumber,
    this.email,
    this.district,
    this.state,
    this.pincode,
    this.group,
  });

  factory Consignor.fromJson(Map<String, dynamic> json) {
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

    return Consignor(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? json['displayName']?.toString() ?? 'Unnamed Consignor',
      address: addrVal,
      city: cityVal,
      gstin: gstinVal,
      phone: json['phone']?.toString(),
      branch: json['branch']?.toString(),
      panNumber: json['panNumber']?.toString() ?? json['pan']?.toString(),
      email: json['email']?.toString(),
      district: json['district']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString() ?? json['pin']?.toString(),
      group: json['group']?.toString() ?? json['partyGroup']?.toString(),
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
      'panNumber': panNumber,
      'email': email,
      'district': district,
      'state': state,
      'pincode': pincode,
      'group': group,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Consignor && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
