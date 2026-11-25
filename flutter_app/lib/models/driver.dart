class Driver {
  final int id;
  final String name;
  final String licenseNumber;
  final String? phone;
  final String? dob;
  final String? bloodGroup;
  final String? rto;
  final String? status;
  final String? validityNt;
  final String? validityTr;

  Driver({
    required this.id,
    required this.name,
    required this.licenseNumber,
    this.phone,
    this.dob,
    this.bloodGroup,
    this.rto,
    this.status,
    this.validityNt,
    this.validityTr,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Unnamed Driver',
      licenseNumber: json['licenseNumber']?.toString() ?? json['licenseNo']?.toString() ?? '',
      phone: json['phone']?.toString(),
      dob: json['dob']?.toString(),
      bloodGroup: json['bloodGroup']?.toString(),
      rto: json['rto']?.toString(),
      status: json['status']?.toString(),
      validityNt: json['validityNt']?.toString(),
      validityTr: json['validityTr']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != 0) 'id': id,
      'name': name,
      'licenseNumber': licenseNumber,
      'phone': phone,
      'dob': dob,
      'bloodGroup': bloodGroup,
      'rto': rto,
      'status': status,
      'validityNt': validityNt,
      'validityTr': validityTr,
    };
  }
}
