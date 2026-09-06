import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';

/// Listens for `tayo://invite/<token>` and `tayo://activate/<token>` links,
/// both on cold start and while the app is running, and stashes matches in
/// [pendingDeepLinkProvider].
///
/// Note: for a custom-scheme URI like `tayo://invite/ABC123`, `invite` is
/// parsed as the host (authority), not a path segment — only `ABC123` shows
/// up in [Uri.pathSegments].
final deepLinkListenerProvider = Provider<void>((ref) {
  final appLinks = AppLinks();

  void handle(Uri? uri) {
    if (uri == null) return;
    if (uri.host != 'invite' && uri.host != 'activate') return;
    if (uri.pathSegments.isEmpty) return;

    ref.read(pendingDeepLinkProvider.notifier).state = uri;
  }

  appLinks.getInitialLink().then(handle);
  final subscription = appLinks.uriLinkStream.listen(handle);

  ref.onDispose(subscription.cancel);
});
