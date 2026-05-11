// lib/screens/settings_screen.dart
//
// ERREURS CORRIGÉES :
//   1. ambiguous_import AppUser / EspDevice
//      → Ce fichier importait app_user.dart et esp_device.dart séparément
//        ALORS QUE database_helper.dart contenait aussi ces classes.
//        Solution : supprimer les imports directs — models.dart les réexporte.
//
//   2. argument_type_not_assignable List<DropdownMenuItem<Object>>
//      → Les DropdownMenuItem avaient value: e (EspDevice) au lieu de value: e.id (String).
//        Solution : value: e.id pour correspondre au type DropdownButton<String>.
//
//   3. 'AppUser' isn't a function (invocation_of_non_function)
//      → AppUser() était appelé comme constructeur mais le type était ambigu.
//        Solution : une fois ambiguous_import résolu, les constructeurs fonctionnent.
//
//   4. withOpacity() déprécié → remplacé par .withValues(alpha: ...)

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';
import '../widgets/widgets.dart';
import '../models/models.dart'; // ← un seul import pour AppUser + EspDevice

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<AppUser>   _users    = [];
  List<EspDevice> _esps     = [];
  bool            _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final users = await DatabaseHelper.instance.getAllUsers();
    final esps  = await DatabaseHelper.instance.getAllEsps();
    if (mounted) {
      setState(() { _users = users; _esps = esps; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Admin Settings',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                _ProfileHeader(user: currentUser),

                // ── Export ──────────────────────────────────────────────────
                _SectionLabel('DATA EXPORT'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SettingsMenuItem(
                    icon:     Icons.file_download_outlined,
                    title:    'Export Data',
                    subtitle: 'Export sensor readings & alerts to Excel or PDF',
                    onTap:    () => Navigator.pushNamed(context, '/export'),
                  ),
                ),

                // ── ESP Devices ─────────────────────────────────────────────
                _SectionLabel('ESP DEVICES (${_esps.length})'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    ..._esps.map((esp) => _EspRow(
                      esp:   esp,
                      onTap: () => Navigator.pushNamed(context, '/device-detail'),
                    )),
                    const SizedBox(height: 8),
                    if (AuthService.instance.isAdmin)
                      _AddButton(
                        label: 'Add ESP Device',
                        onTap: () => _showAddEspDialog(context),
                      ),
                  ]),
                ),

                // ── User Management — Admin seulement ───────────────────────
                if (AuthService.instance.isAdmin) ...[
                  _SectionLabel('USER MANAGEMENT (${_users.length})'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(children: [
                      ..._users.map((user) => _UserRow(
                        user:     user,
                        esps:     _esps,
                        onDelete: user.id != currentUser?.id
                            ? () => _deleteUser(user) : null,
                        onEdit:   () => _showEditUserDialog(context, user),
                      )),
                      const SizedBox(height: 8),
                      _AddButton(
                        label: 'Add User',
                        onTap: () => _showAddUserDialog(context),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Log out ─────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AuthService.instance.logout();
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (_) => false);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                        backgroundColor: Colors.red.withValues(alpha: 0.05),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon:  const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text('Log Out',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                              color: Colors.redAccent)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(child: Text('DATAGUARDIAN IOT V2.0',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                        color: AppColors.textMuted, letterSpacing: 2))),
                const SizedBox(height: 24),
              ]),
            ),
      bottomNavigationBar: AppBottomNavBar(currentIndex: 3, onTap: (_) {}),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────

  Future<void> _showAddUserDialog(BuildContext context) async {
    final nameCtrl  = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    String  role          = 'responsable';
    // CORRECTION : assignedEspId est String? — value doit être e.id (String)
    String? assignedEspId = _esps.isNotEmpty ? _esps.first.id : null;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add User',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogField(ctrl: nameCtrl,  label: 'Full Name',  hint: 'Mohammed Alami'),
            _DialogField(ctrl: emailCtrl, label: 'Email',      hint: 'user@company.com', isEmail: true),
            _DialogField(ctrl: passCtrl,  label: 'Password',   hint: '••••••••', isPassword: true),
            const SizedBox(height: 12),
            // Sélecteur de rôle
            Row(children: [
              const Text('Role:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: role,
                dropdownColor: AppColors.surfaceLight,
                style: const TextStyle(color: AppColors.textPrimary),
                items: const [
                  DropdownMenuItem(value: 'admin',       child: Text('Admin')),
                  DropdownMenuItem(value: 'responsable', child: Text('Responsable')),
                ],
                onChanged: (v) => setS(() => role = v!),
              ),
            ]),
            // Sélecteur ESP — visible seulement si rôle = responsable
            if (role == 'responsable' && _esps.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Text('ESP:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(width: 12),
                // CORRECTION : DropdownButton<String> avec value: e.id (String)
                DropdownButton<String>(
                  value: assignedEspId,
                  dropdownColor: AppColors.surfaceLight,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  items: _esps
                      .map((e) => DropdownMenuItem<String>(
                            value: e.id,   // ← String, pas EspDevice
                            child: Text(e.name),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => assignedEspId = v),
                ),
              ]),
            ],
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty ||
                  passCtrl.text.isEmpty) {
                return;
              }
              await DatabaseHelper.instance.createUser(
                AppUser(
                  fullName:      nameCtrl.text,
                  email:         emailCtrl.text,
                  role:          role,
                  assignedEspId: role == 'responsable' ? assignedEspId : null,
                ),
                passCtrl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  Future<void> _showEditUserDialog(BuildContext context, AppUser user) async {
    final nameCtrl    = TextEditingController(text: user.fullName);
    String? assignedEspId = user.assignedEspId;

    await showDialog(context: context, builder: (_) =>
      StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit User',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _DialogField(ctrl: nameCtrl, label: 'Full Name', hint: ''),
          if (user.isResponsable && _esps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Text('Assigned ESP:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(width: 12),
              // CORRECTION : DropdownButton<String> avec value: e.id
              DropdownButton<String>(
                value: assignedEspId,
                dropdownColor: AppColors.surfaceLight,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                items: _esps
                    .map((e) => DropdownMenuItem<String>(
                          value: e.id,
                          child: Text(e.name),
                        ))
                    .toList(),
                onChanged: (v) => setS(() => assignedEspId = v),
              ),
            ]),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              await DatabaseHelper.instance.updateUser(AppUser(
                id:            user.id,
                fullName:      nameCtrl.text,
                email:         user.email,
                role:          user.role,
                assignedEspId: assignedEspId,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }

  Future<void> _showAddEspDialog(BuildContext context) async {
    final idCtrl   = TextEditingController();
    final nameCtrl = TextEditingController();
    final ipCtrl   = TextEditingController();
    final locCtrl  = TextEditingController();
    final roomCtrl = TextEditingController();

    await showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Add ESP Device',
          style: TextStyle(color: AppColors.textPrimary)),
      content: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogField(ctrl: idCtrl,   label: 'Device ID',  hint: 'ESP8266-02'),
          _DialogField(ctrl: nameCtrl, label: 'Name',       hint: 'ESP8266 — Rack B'),
          _DialogField(ctrl: ipCtrl,   label: 'IP Address', hint: '192.168.1.105'),
          _DialogField(ctrl: locCtrl,  label: 'Location',   hint: 'Rack B-01'),
          _DialogField(ctrl: roomCtrl, label: 'Room',       hint: 'Server Room B'),
        ],
      )),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () async {
            if (idCtrl.text.isEmpty || ipCtrl.text.isEmpty) return;
            await DatabaseHelper.instance.upsertEsp(EspDevice(
              id:        idCtrl.text,
              name:      nameCtrl.text,
              ipAddress: ipCtrl.text,
              location:  locCtrl.text,
              room:      roomCtrl.text,
              isOnline:  false,
              firmware:  'v2.0.4',
            ));
            if (context.mounted) Navigator.pop(context);
            _load();
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _deleteUser(AppUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete User',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Delete ${user.fullName}?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && user.id != null) {
      await DatabaseHelper.instance.deleteUser(user.id!);
      _load();
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
    child: Text(text, style: const TextStyle(fontSize: 11,
        fontWeight: FontWeight.w700, color: AppColors.textSecondary,
        letterSpacing: 1.5)),
  );
}

class _ProfileHeader extends StatelessWidget {
  final AppUser? user;
  const _ProfileHeader({this.user});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primary.withValues(alpha: 0.2),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.admin_panel_settings,
            color: AppColors.primary, size: 28)),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(user?.fullName ?? 'Administrator',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        Text(user?.email ?? '',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4)),
          child: Text((user?.role ?? 'admin').toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.primary))),
      ]),
    ]),
  );
}

class _SettingsMenuItem extends StatelessWidget {
  final IconData   icon;
  final String     title, subtitle;
  final VoidCallback onTap;
  const _SettingsMenuItem({required this.icon, required this.title,
      required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 22)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(subtitle, style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
            ])),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ]),
        ),
      ),
    ),
  );
}

class _UserRow extends StatelessWidget {
  final AppUser      user;
  final List<EspDevice> esps;
  final VoidCallback?  onDelete;
  final VoidCallback   onEdit;
  const _UserRow({required this.user, required this.esps,
      this.onDelete, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    final espName = user.assignedEspId != null
        ? _espName(user.assignedEspId!)
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (user.isAdmin ? AppColors.primary : AppColors.emerald)
                .withValues(alpha: 0.15)),
          child: Icon(
            user.isAdmin ? Icons.admin_panel_settings : Icons.person_outline,
            color: user.isAdmin ? AppColors.primary : AppColors.emerald,
            size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user.fullName, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text(user.email, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
          if (espName != null)
            Text('ESP: $espName',
                style: const TextStyle(fontSize: 11, color: AppColors.primary)),
        ])),
        IconButton(
          icon: const Icon(Icons.edit_outlined,
              color: AppColors.textMuted, size: 18),
          onPressed: onEdit),
        if (onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.red, size: 18),
            onPressed: onDelete),
      ]),
    );
  }

  // Retrouve le nom de l'ESP depuis son id
  String? _espName(String espId) {
    try {
      return esps.firstWhere((e) => e.id == espId).name;
    } catch (_) {
      return null;
    }
  }
}

class _EspRow extends StatelessWidget {
  final EspDevice esp;
  final VoidCallback onTap;
  const _EspRow({required this.esp, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
      child: Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: esp.isOnline ? AppColors.emerald : AppColors.red,
            shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(esp.name, style: const TextStyle(fontSize: 14,
              fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          Text('${esp.id} · ${esp.ipAddress} · ${esp.room}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
      ]),
    ),
  );
}

class _AddButton extends StatelessWidget {
  final String     label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primary),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      icon:  const Icon(Icons.add, color: AppColors.primary, size: 18),
      label: Text(label, style: const TextStyle(color: AppColors.primary,
          fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  );
}

class _DialogField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final bool   isEmail, isPassword;
  const _DialogField({required this.ctrl, required this.label,
      required this.hint, this.isEmail = false, this.isPassword = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          fontSize: 12, color: AppColors.textSecondary)),
      const SizedBox(height: 4),
      TextField(
        controller:   ctrl,
        obscureText:  isPassword,
        keyboardType: isEmail
            ? TextInputType.emailAddress : TextInputType.text,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText:  hint,
          hintStyle: const TextStyle(
              color: AppColors.textMuted, fontSize: 13),
          filled:     true,
          fillColor:  AppColors.surfaceLight,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ]),
  );
}

