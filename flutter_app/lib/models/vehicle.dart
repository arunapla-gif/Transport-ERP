class Vehicle {
  final int id;
  final String vehicleNumber;
  final String? type;
  final String? ladenType;
  
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerPhone2;
  final String? makeModel;
  final DateTime? fitnessExpiry;
  final DateTime? insuranceExpiry;
  final DateTime? npExpiry;
  final int? grossWeight;
  final String? rcStatus;
  final bool rcVerified;

  Vehicle({
    required this.id,
    required this.vehicleNumber,
    this.type,
    this.ladenType,
    this.ownerName,
    this.ownerPhone,
    this.ownerPhone2,
    this.makeModel,
    this.fitnessExpiry,
    this.insuranceExpiry,
    this.npExpiry,
    this.grossWeight,
    this.rcStatus,
    this.rcVerified = false,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      vehicleNumber: (json['vehicleNumber'] ?? json['vehicleNo'])?.toString() ?? '',
      type: (json['type'] ?? json['vehicleType'])?.toString(),
      ladenType: json['ladenType']?.toString(),
      ownerName: json['ownerName']?.toString(),
      ownerPhone: json['ownerPhone']?.toString(),
      ownerPhone2: json['ownerPhone2']?.toString(),
      makeModel: json['makeModel']?.toString(),
      fitnessExpiry: json['fitnessExpiry'] != null ? DateTime.tryParse(json['fitnessExpiry'].toString()) : null,
      insuranceExpiry: json['insuranceExpiry'] != null ? DateTime.tryParse(json['insuranceExpiry'].toString()) : null,
      npExpiry: json['npExpiry'] != null ? DateTime.tryParse(json['npExpiry'].toString()) : null,
      grossWeight: json['grossWeight'] != null ? int.tryParse(json['grossWeight'].toString()) : null,
      rcStatus: json['rcStatus']?.toString(),
      rcVerified: json['rcVerified'] == true || json['rcVerified'] == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleNumber': vehicleNumber,
      'type': type,
      'ladenType': ladenType,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'ownerPhone2': ownerPhone2,
      'makeModel': makeModel,
      'fitnessExpiry': fitnessExpiry?.toIso8601String(),
      'insuranceExpiry': insuranceExpiry?.toIso8601String(),
      'npExpiry': npExpiry?.toIso8601String(),
      'grossWeight': grossWeight,
      'rcStatus': rcStatus,
      'rcVerified': rcVerified,
    };
  }
}

