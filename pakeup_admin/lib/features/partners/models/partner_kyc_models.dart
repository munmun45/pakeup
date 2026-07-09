class PartnerKycOverviewRecord {
  const PartnerKycOverviewRecord({
    required this.partnerId,
    required this.businessName,
    required this.ownerName,
    this.phone,
    this.profileId,
    this.accountId,
    this.storeCount = 1,
    this.primaryImage,
    this.images = const [],
    this.isActive = true,
    this.kycStatus = 'pending',
    this.createdAt,
    this.panNumber,
    this.aadhaarNumber,
    this.hasAadhaarDoc = false,
    this.hasPanDoc = false,
    this.hasAgreementDoc = false,
    this.hasGstDoc = false,
    this.hasOtherDoc = false,
    this.hasPassbookDoc = false,
  });

  final String partnerId;
  final String businessName;
  final String ownerName;
  final String? phone;
  final String? profileId;
  final String? accountId;
  final int storeCount;
  final String? primaryImage;
  final List<String> images;
  final bool isActive;
  final String kycStatus;
  final DateTime? createdAt;
  final String? panNumber;
  final String? aadhaarNumber;
  final bool hasAadhaarDoc;
  final bool hasPanDoc;
  final bool hasAgreementDoc;
  final bool hasGstDoc;
  final bool hasOtherDoc;
  final bool hasPassbookDoc;

  static const totalDocSlots = 5;

  int get uploadedDocCount => documentStatuses.where((d) => d.uploaded).length;

  List<KycDocStatusItem> get documentStatuses => [
        KycDocStatusItem(
          shortLabel: 'AD',
          fullLabel: 'Aadhaar',
          uploaded: hasAadhaarDoc,
        ),
        KycDocStatusItem(
          shortLabel: 'PAN',
          fullLabel: 'PAN',
          uploaded: hasPanDoc,
        ),
        KycDocStatusItem(
          shortLabel: 'AGR',
          fullLabel: 'Agreement',
          uploaded: hasAgreementDoc,
        ),
        KycDocStatusItem(
          shortLabel: 'GST',
          fullLabel: 'GST',
          uploaded: hasGstDoc,
        ),
        KycDocStatusItem(
          shortLabel: 'OTH',
          fullLabel: 'Other',
          uploaded: hasOtherDoc,
        ),
      ];

  String get displayPan {
    final v = panNumber?.trim();
    if (v == null || v.isEmpty) return '—';
    return v.toUpperCase();
  }

  String get displayAadhaar {
    final v = aadhaarNumber?.trim();
    if (v == null || v.isEmpty) return '—';
    return v;
  }

  PartnerKycOverviewRecord copyWith({
    String? partnerId,
    String? businessName,
    String? profileId,
    String? accountId,
    int? storeCount,
    String? kycStatus,
    String? panNumber,
    String? aadhaarNumber,
    bool? hasAadhaarDoc,
    bool? hasPanDoc,
    bool? hasAgreementDoc,
    bool? hasGstDoc,
    bool? hasOtherDoc,
    bool? hasPassbookDoc,
  }) {
    return PartnerKycOverviewRecord(
      partnerId: partnerId ?? this.partnerId,
      businessName: businessName ?? this.businessName,
      ownerName: ownerName,
      phone: phone,
      profileId: profileId ?? this.profileId,
      accountId: accountId ?? this.accountId,
      storeCount: storeCount ?? this.storeCount,
      primaryImage: primaryImage,
      images: images,
      isActive: isActive,
      kycStatus: kycStatus ?? this.kycStatus,
      createdAt: createdAt,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      hasAadhaarDoc: hasAadhaarDoc ?? this.hasAadhaarDoc,
      hasPanDoc: hasPanDoc ?? this.hasPanDoc,
      hasAgreementDoc: hasAgreementDoc ?? this.hasAgreementDoc,
      hasGstDoc: hasGstDoc ?? this.hasGstDoc,
      hasOtherDoc: hasOtherDoc ?? this.hasOtherDoc,
      hasPassbookDoc: hasPassbookDoc ?? this.hasPassbookDoc,
    );
  }

  factory PartnerKycOverviewRecord.fromJson(Map<String, dynamic> json) {
    return PartnerKycOverviewRecord(
      partnerId: json['partner_id'] as String? ?? '',
      businessName: json['business_name'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      phone: json['phone'] as String?,
      profileId: json['profile_id'] as String?,
      accountId: json['account_id'] as String?,
      storeCount: json['store_count'] as int? ?? 1,
      primaryImage: json['primary_image'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isActive: json['is_active'] as bool? ?? true,
      kycStatus: json['kyc_status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      panNumber: json['pan_number'] as String?,
      aadhaarNumber: json['aadhaar_number'] as String?,
      hasAadhaarDoc: json['has_aadhaar_doc'] as bool? ?? false,
      hasPanDoc: json['has_pan_doc'] as bool? ?? false,
      hasAgreementDoc: json['has_agreement_doc'] as bool? ?? false,
      hasGstDoc: json['has_gst_doc'] as bool? ?? false,
      hasOtherDoc: json['has_other_doc'] as bool? ?? false,
      hasPassbookDoc: json['has_passbook_doc'] as bool? ?? false,
    );
  }
}

class KycDocStatusItem {
  const KycDocStatusItem({
    required this.shortLabel,
    required this.fullLabel,
    required this.uploaded,
  });

  final String shortLabel;
  final String fullLabel;
  final bool uploaded;
}

class PartnerAccountRecord {
  const PartnerAccountRecord({
    required this.accountId,
    required this.ownerName,
    this.profileId,
    this.phone,
    this.email,
    this.primaryImage,
    this.isActive = true,
    this.storeCount = 0,
    this.accountStatus = 'pending',
    this.bankAccountHolder,
    this.bankName,
    this.ifscCode,
    this.accountNumber,
    this.passbookDocUrl,
    this.accountType,
    this.upiId,
    this.createdAt,
    this.accountUpdatedAt,
  });

  final String accountId;
  final String ownerName;
  final String? profileId;
  final String? phone;
  final String? email;
  final String? primaryImage;
  final bool isActive;
  final int storeCount;
  final String accountStatus;
  final String? bankAccountHolder;
  final String? bankName;
  final String? ifscCode;
  final String? accountNumber;
  final String? passbookDocUrl;
  final String? accountType;
  final String? upiId;
  final DateTime? createdAt;
  final DateTime? accountUpdatedAt;

  String get shortAccountId {
    final profile = profileId?.trim();
    if (profile != null && profile.isNotEmpty) return profile;
    if (accountId.length <= 12) return accountId;
    return '${accountId.substring(0, 8)}…';
  }

  String get displayAccountType {
    final value = accountType?.trim();
    if (value == null || value.isEmpty) return '—';
    return value[0].toUpperCase() + value.substring(1);
  }

  String get displayUpiId {
    final value = upiId?.trim();
    if (value == null || value.isEmpty) return '—';
    return value;
  }

  bool get hasBankDetails =>
      bankName?.trim().isNotEmpty == true &&
      ifscCode?.trim().isNotEmpty == true &&
      accountNumber?.trim().isNotEmpty == true;

  bool get hasPassbook => passbookDocUrl?.trim().isNotEmpty == true;

  bool get isComplete => hasBankDetails && hasPassbook;

  String get maskedAccount {
    final ac = accountNumber?.trim();
    if (ac == null || ac.isEmpty) return '—';
    if (ac.length <= 4) return ac;
    return '****${ac.substring(ac.length - 4)}';
  }

  factory PartnerAccountRecord.fromJson(Map<String, dynamic> json) {
    return PartnerAccountRecord(
      accountId: json['account_id'] as String? ?? '',
      profileId: json['profile_id'] as String?,
      ownerName: json['owner_name'] as String? ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      primaryImage: json['primary_image'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      storeCount: json['store_count'] as int? ?? 0,
      accountStatus: json['account_status'] as String? ?? 'pending',
      bankAccountHolder: json['bank_account_holder'] as String?,
      bankName: json['bank_name'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      accountNumber: json['account_number'] as String?,
      passbookDocUrl: json['passbook_doc_url'] as String?,
      accountType: json['account_type'] as String?,
      upiId: json['upi_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      accountUpdatedAt: json['account_updated_at'] != null
          ? DateTime.tryParse(json['account_updated_at'] as String)
          : null,
    );
  }
}

class PartnerBankAccountRecord {
  const PartnerBankAccountRecord({
    required this.accountId,
    this.bankAccountHolder,
    this.bankName,
    this.ifscCode,
    this.accountNumber,
    this.accountType,
    this.upiId,
    this.passbookDocUrl,
    this.accountStatus,
    this.updatedAt,
  });

  final String accountId;
  final String? bankAccountHolder;
  final String? bankName;
  final String? ifscCode;
  final String? accountNumber;
  final String? accountType;
  final String? upiId;
  final String? passbookDocUrl;
  final String? accountStatus;
  final DateTime? updatedAt;

  factory PartnerBankAccountRecord.fromJson(Map<String, dynamic> json) {
    return PartnerBankAccountRecord(
      accountId: json['account_id'] as String? ?? '',
      bankAccountHolder: json['bank_account_holder'] as String?,
      bankName: json['bank_name'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      accountNumber: json['account_number'] as String?,
      accountType: json['account_type'] as String?,
      upiId: json['upi_id'] as String?,
      passbookDocUrl: json['passbook_doc_url'] as String?,
      accountStatus: json['account_status'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class PartnerKycRecord {
  const PartnerKycRecord({
    required this.id,
    required this.partnerId,
    this.propertyType,
    this.panNumber,
    this.aadhaarNumber,
    this.bankAccountHolder,
    this.bankName,
    this.ifscCode,
    this.accountNumber,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.agreementDocUrl,
    this.gstDocUrl,
    this.passbookDocUrl,
    this.otherDocUrl,
    this.otherDocName,
    this.accountType,
    this.upiId,
    this.submittedAt,
  });

  final String id;
  final String partnerId;
  final String? propertyType;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? bankAccountHolder;
  final String? bankName;
  final String? ifscCode;
  final String? accountNumber;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? agreementDocUrl;
  final String? gstDocUrl;
  final String? passbookDocUrl;
  final String? otherDocUrl;
  final String? otherDocName;
  final String? accountType;
  final String? upiId;
  final DateTime? submittedAt;

  bool get hasSubmission => submittedAt != null;

  factory PartnerKycRecord.fromJson(Map<String, dynamic> json) {
    return PartnerKycRecord(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String,
      propertyType: json['property_type'] as String?,
      panNumber: json['pan_number'] as String?,
      aadhaarNumber: json['aadhaar_number'] as String?,
      bankAccountHolder: json['bank_account_holder'] as String?,
      bankName: json['bank_name'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      accountNumber: json['account_number'] as String?,
      aadhaarDocUrl: json['aadhaar_doc_url'] as String?,
      panDocUrl: json['pan_doc_url'] as String?,
      agreementDocUrl: json['agreement_doc_url'] as String?,
      gstDocUrl: json['gst_doc_url'] as String?,
      passbookDocUrl: json['passbook_doc_url'] as String?,
      otherDocUrl: json['other_doc_url'] as String?,
      otherDocName: json['other_doc_name'] as String?,
      accountType: json['account_type'] as String?,
      upiId: json['upi_id'] as String?,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'] as String)
          : null,
    );
  }
}

class PartnerKycFormData {
  const PartnerKycFormData({
    this.propertyType,
    this.panNumber,
    this.aadhaarNumber,
    this.bankAccountHolder,
    this.bankName,
    this.ifscCode,
    this.accountNumber,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.agreementDocUrl,
    this.gstDocUrl,
    this.passbookDocUrl,
    this.otherDocUrl,
    this.otherDocName,
    this.accountType,
    this.upiId,
  });

  final String? propertyType;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? bankAccountHolder;
  final String? bankName;
  final String? ifscCode;
  final String? accountNumber;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? agreementDocUrl;
  final String? gstDocUrl;
  final String? passbookDocUrl;
  final String? otherDocUrl;
  final String? otherDocName;
  final String? accountType;
  final String? upiId;

  Map<String, dynamic> toRpcParams({bool markSubmitted = true}) => {
        'property_type': propertyType,
        'pan_number': panNumber,
        'aadhaar_number': aadhaarNumber,
        'aadhaar_doc_url': aadhaarDocUrl,
        'pan_doc_url': panDocUrl,
        'agreement_doc_url': agreementDocUrl,
        'gst_doc_url': gstDocUrl,
        'other_doc_url': otherDocUrl,
        'other_doc_name': otherDocName,
        'mark_submitted': markSubmitted,
      };
}

enum KycDocType {
  aadhaar('aadhaar', 'Aadhaar'),
  pan('pan', 'PAN Card'),
  agreement('agreement', 'Agreement'),
  gst('gst', 'GST Certificate'),
  passbook('passbook', 'Bank Passbook'),
  other('other', 'Other Document');

  const KycDocType(this.key, this.label);

  final String key;
  final String label;
}
