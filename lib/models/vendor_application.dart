import 'enums.dart';

class VendorApplication {
  const VendorApplication({
    required this.businessName,
    required this.status,
    this.phone,
    this.serviceArea,
  });

  final String businessName;
  final ApprovalStatus status;
  final String? phone;
  final String? serviceArea;

  factory VendorApplication.fromMap(Map<String, dynamic> map) =>
      VendorApplication(
        businessName: map['business_name'] as String,
        status: enumByName(
            ApprovalStatus.values, map['status'], ApprovalStatus.pending),
        phone: map['phone'] as String?,
        serviceArea: map['service_area'] as String?,
      );
}
