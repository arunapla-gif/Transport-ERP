class Gdm {
  final int? id;
  final String gdmNumber;
  final String date;
  final String time;
  final int? vehicleId;
  final String? driverName;
  final String? driverPhone;
  final int? startKm;
  final String? fromLocation;
  final String? toName;
  final String? deliveryAt;
  final double memoAmount;
  final String? cewbNumber;
  final String status;
  final String branch;
  // Related
  final dynamic vehicle; // Can type later if needed
  final List<dynamic>? gcs; // Gc list

  Gdm({
    this.id,
    required this.gdmNumber,
    required this.date,
    required this.time,
    this.vehicleId,
    this.driverName,
    this.driverPhone,
    this.startKm,
    this.fromLocation,
    this.toName,
    this.deliveryAt,
    required this.memoAmount,
    this.cewbNumber,
    required this.status,
    required this.branch,
    this.vehicle,
    this.gcs,
  });

  factory Gdm.fromJson(Map<String, dynamic> json) {
    return Gdm(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      gdmNumber: json['gdmNumber']?.toString() ?? '',
      date: json['date']?.toString() ?? DateTime.now().toIso8601String(),
      time: json['time']?.toString() ?? '',
      vehicleId: json['vehicleId'] != null ? int.tryParse(json['vehicleId'].toString()) : null,
      driverName: json['driverName']?.toString(),
      driverPhone: json['driverPhone']?.toString(),
      startKm: json['startKm'] != null ? int.tryParse(json['startKm'].toString()) : null,
      fromLocation: json['fromLocation']?.toString(),
      toName: json['toName']?.toString(),
      deliveryAt: json['deliveryAt']?.toString(),
      memoAmount: json['memoAmount'] != null ? double.parse(json['memoAmount'].toString()) : 0.0,
      cewbNumber: json['cewbNumber']?.toString(),
      status: json['status']?.toString() ?? 'Created',
      branch: json['branch']?.toString() ?? 'MAIN',
      vehicle: json['vehicle'],
      gcs: json['gcs'] as List?,
    );
  }
}
