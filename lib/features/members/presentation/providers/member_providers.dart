import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/networking/providers.dart';
import '../../data/member_repository.dart';

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(apiClientProvider));
});
