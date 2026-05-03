// lib/services/auth_service.dart
//
// ERREUR CORRIGÉE :
//   ambiguous_import pour AppUser
//   → Cause : ce fichier importait '../models/app_user.dart' ET indirectement
//     database_helper.dart qui contenait aussi une classe AppUser.
//   → Solution : supprimer l'import direct de app_user.dart et esp_device.dart —
//     DatabaseHelper importe déjà '../models/models.dart' qui réexporte tout.
//     Ici on importe seulement ce dont on a besoin directement.
//
//   L'import de esp_device.dart est aussi supprimé car EspDevice
//   n'est pas utilisé dans ce fichier.

import '../database/database_helper.dart';
import '../models/models.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  AppUser? _currentUser;

  /// Utilisateur actuellement connecté (null si déconnecté)
  AppUser? get currentUser => _currentUser;

  /// true si un utilisateur est connecté
  bool get isLoggedIn => _currentUser != null;

  /// true si l'utilisateur connecté est administrateur
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// Tente la connexion — retourne true si email + mot de passe valides
  Future<bool> login(String email, String password) async {
    final user = await DatabaseHelper.instance.login(email, password);
    if (user != null) {
      _currentUser = user;
      return true;
    }
    return false;
  }

  /// Déconnecte l'utilisateur courant
  void logout() => _currentUser = null;
}
