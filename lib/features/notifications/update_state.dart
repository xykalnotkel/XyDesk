import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/devlog.dart';
import 'update_repository.dart';

/// Satu sumber status update untuk topbar, dot notifikasi, dan halaman update.
/// Error jaringan tidak dianggap "tidak ada update"; null berarti belum dapat
/// dipastikan dan akan dicoba lagi saat pengguna membuka pusat pembaruan.
final updateAvailabilityProvider = FutureProvider<UpdateCheckResult?>((
  ref,
) async {
  try {
    return await const OfficialUpdateRepository().check();
  } catch (error, stack) {
    DevLog.e('update', 'Pemeriksaan update topbar ditunda', error, stack);
    return null;
  }
});
