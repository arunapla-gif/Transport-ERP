import 'vehicle.dart';
import 'gdm.dart';

class Trip {
  final int id;
  final String tripNumber;
  final DateTime? date;
  final String? status;
  
  final int? vehicleId;
  final Vehicle? vehicle;
  
  final String? driverName;
  final String? driverPhone;
  
  final double? lorryHire;
  final double? advancePaid;
  final double? balanceAmount;
  
  final String? sourcedBy;
  final String? brokerName;
  final String? loadingPayer;
  final double? loadingCharge;
  final double? commissionAmount;
  final String? commissionDetails;
  
  final double? additions;
  final double? deductions;
  final String? remarks;
  
  final double? crossingAmount;
  final double? returnAmount;
  final DateTime? settledDate;
  
  final List<Gdm>? gdms;
  final String? branch;

  Trip({
    required this.id,
    required this.tripNumber,
    this.date,
    this.status,
    this.vehicleId,
    this.vehicle,
    this.driverName,
    this.driverPhone,
    this.lorryHire,
    this.advancePaid,
    this.balanceAmount,
    this.sourcedBy,
    this.brokerName,
    this.loadingPayer,
    this.loadingCharge,
    this.commissionAmount,
    this.commissionDetails,
    this.additions,
    this.deductions,
    this.remarks,
    this.crossingAmount,
    this.returnAmount,
    this.settledDate,
    this.gdms,
    this.branch,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      tripNumber: json['tripNumber']?.toString() ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'].toString()) : null,
      status: json['status']?.toString(),
      vehicleId: json['vehicleId'] != null ? int.tryParse(json['vehicleId'].toString()) : null,
      vehicle: json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      driverName: json['driverName']?.toString(),
      driverPhone: json['driverPhone']?.toString(),
      lorryHire: json['lorryHire'] != null ? double.tryParse(json['lorryHire'].toString()) : null,
      advancePaid: json['advancePaid'] != null ? double.tryParse(json['advancePaid'].toString()) : null,
      balanceAmount: json['balanceAmount'] != null ? double.tryParse(json['balanceAmount'].toString()) : null,
      sourcedBy: json['sourcedBy']?.toString(),
      brokerName: json['brokerName']?.toString(),
      loadingPayer: json['loadingPayer']?.toString(),
      loadingCharge: json['loadingCharge'] != null ? double.tryParse(json['loadingCharge'].toString()) : null,
      commissionAmount: json['commissionAmount'] != null ? double.tryParse(json['commissionAmount'].toString()) : null,
      commissionDetails: json['commissionDetails']?.toString(),
      additions: json['additions'] != null ? double.tryParse(json['additions'].toString()) : null,
      deductions: json['deductions'] != null ? double.tryParse(json['deductions'].toString()) : null,
      remarks: json['remarks']?.toString(),
      crossingAmount: json['crossingAmount'] != null ? double.tryParse(json['crossingAmount'].toString()) : null,
      returnAmount: json['returnAmount'] != null ? double.tryParse(json['returnAmount'].toString()) : null,
      settledDate: json['settledDate'] != null ? DateTime.tryParse(json['settledDate'].toString()) : null,
      gdms: json['gdms'] != null ? (json['gdms'] as List).map((e) => Gdm.fromJson(e)).toList() : null,
      branch: json['branch']?.toString(),
    );
  }
}
