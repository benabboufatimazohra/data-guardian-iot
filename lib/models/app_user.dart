// ─────────────────────────────────────────────────────────────────────────────
// lib/models/app_user.dart
//
// Modèle utilisateur de l'application DataGuardian IoT.
//
// ERREUR CORRIGÉE :
//   L'ancienne version utilisait des clés camelCase ('fullName', 'assignedEspId')
//   dans fromMap() et toMap(), alors que la base de données SQLite stocke les
//   colonnes en snake_case ('full_name', 'assigned_esp_id').
//   Cela causait des valeurs null silencieuses à la lecture (ex: fullName = null).
//
//   Ancien code (FAUX) :
//     fullName: map['fullName'],          ← retourne null, colonne 'fullName' inexistante
//     assignedEspId: map['assignedEspId'] ← idem
//
//   Nouveau code (CORRECT) :
//     fullName: m['full_name'],           ← correspond à la colonne SQLite
//     assignedEspId: m['assigned_esp_id'] ← idem
//
// CHAMP SUPPRIMÉ :
//   L'ancien modèle avait un champ 'password' en clair — supprimé car dangereux.
//   Le mot de passe est haché (SHA-256) dans DatabaseHelper avant insertion,
//   il ne doit jamais circuler en clair dans l'application.
//
// RÔLES :
//   'admin'       → voit tous les ESP, accès complet aux paramètres
//   'responsable' → assigné à un seul ESP (assignedEspId != null)
// ─────────────────────────────────────────────────────────────────────────────

class AppUser {
  // Identifiant auto-incrémenté par SQLite (null avant insertion)
  final int? id;

  // Nom complet affiché dans l'interface
  final String fullName;

  // Email unique — utilisé comme identifiant de connexion
  final String email;

  // Rôle : 'admin' ou 'responsable'
  final String role;

  // ID de l'ESP assigné — null pour les admins (voient tout),
  // obligatoire pour les responsables (voient un seul ESP)
  final String? assignedEspId;

  AppUser({
    this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.assignedEspId,
  });

  // ── Getters de commodité ──────────────────────────────────────────────────

  /// Vrai si l'utilisateur est administrateur (accès complet)
  bool get isAdmin => role == 'admin';

  /// Vrai si l'utilisateur est un responsable (accès limité à son ESP)
  bool get isResponsable => role == 'responsable';

  // ── Désérialisation depuis SQLite ─────────────────────────────────────────
  //
  // IMPORTANT : Les clés doivent correspondre EXACTEMENT aux noms de colonnes
  // définis dans CREATE TABLE users (database_helper.dart).
  //
  // Colonnes SQLite :  id | full_name | email | password_hash | role | assigned_esp_id | created_at
  //
  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
    id:            m['id']              as int?,
    fullName:      m['full_name']       as String,   // ← snake_case obligatoire
    email:         m['email']           as String,
    role:          m['role']            as String,
    assignedEspId: m['assigned_esp_id'] as String?,  // ← snake_case obligatoire
  );

  // ── Sérialisation vers SQLite ─────────────────────────────────────────────
  //
  // Utilisé par updateUser() dans DatabaseHelper.
  // NB : 'password_hash' n'est PAS inclus ici — il est géré séparément
  //      par createUser() et changePassword() dans DatabaseHelper pour
  //      s'assurer que le hash SHA-256 est toujours appliqué.
  //
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,       // Inclut l'id seulement si non-null (update)
    'full_name'       : fullName,
    'email'           : email,
    'role'            : role,
    'assigned_esp_id' : assignedEspId,
    'created_at'      : DateTime.now().toIso8601String(),
  };
}

