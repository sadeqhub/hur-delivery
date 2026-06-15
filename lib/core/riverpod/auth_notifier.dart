import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../shared/models/user_model.dart';

/// Thin Riverpod bridge over [AuthProvider].
/// Delegates all business logic to the existing ChangeNotifier.
/// Use ref.watch(authNotifierProvider) in new screens instead of
/// context.watch<AuthProvider>().
class AuthNotifier extends ChangeNotifier {
  final AuthProvider _auth;

  AuthNotifier(this._auth) {
    _auth.addListener(notifyListeners);
  }

  bool get isAuthenticated => _auth.isAuthenticated;
  bool get isLoading => _auth.isLoading;
  bool get isInitialized => _auth.isInitialized;
  bool get isDemoMode => _auth.isDemoMode;
  bool get isVerified => _auth.isVerified;
  String? get currentRole => _auth.user?.role;
  String? get error => _auth.error;
  String? get verifiedPhone => _auth.verifiedPhone;
  UserModel? get user => _auth.user;

  AuthProvider get delegate => _auth;

  @override
  void dispose() {
    _auth.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Bridged from the AuthProvider in the MultiProvider tree.
/// Override in ProviderScope:
/// ```dart
/// ProviderScope(
///   overrides: [
///     authNotifierProvider.overrideWith((ref) {
///       final auth = Provider.of<AuthProvider>(navigatorKey.currentContext!, listen: false);
///       return AuthNotifier(auth);
///     }),
///   ],
/// )
/// ```
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  throw UnimplementedError(
      'Provide authNotifierProvider override in ProviderScope');
});
