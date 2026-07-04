import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/partner_otp_repository.dart';

final partnerOtpRepositoryProvider = Provider<PartnerOtpRepository>((ref) {
  return PartnerOtpRepository(ref.watch(supabaseClientProvider));
});
