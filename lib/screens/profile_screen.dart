import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../theme/ceylon_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingPhoto = false;
  final _picker = ImagePicker();

  Future<void> _pickAndUploadAvatar() async {
    final auth = context.read<app_auth.AuthProvider>();
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      imageQuality: 50,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final base64Data = base64Encode(bytes);
      await auth.updateProfile(photoBase64: base64Data);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _editNameBio() async {
    final auth = context.read<app_auth.AuthProvider>();
    final nameController = TextEditingController(text: auth.appUser?.name ?? '');
    final bioController = TextEditingController(text: auth.appUser?.bio ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CeylonSpiceTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: CeylonSpiceTheme.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Text('Edit Profile', style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Bio', prefixIcon: Icon(Icons.info_outline)),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CeylonSpiceTheme.cinnamon,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await auth.updateProfile(name: nameController.text.trim(), bio: bioController.text.trim());
    }
  }

  Future<void> _changePassword() async {
    final formKey = GlobalKey<FormState>();
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscure = true;
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CeylonSpiceTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: CeylonSpiceTheme.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text('Change Password', style: Theme.of(ctx).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Enter your current password to confirm it\'s you.',
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: currentController,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: newController,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: confirmController,
                    obscureText: obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: Icon(Icons.check_circle_outline),
                    ),
                    validator: (v) => (v != newController.text) ? 'Passwords do not match' : null,
                  ),
                  CheckboxListTile(
                    value: !obscure,
                    onChanged: (v) => setSheetState(() => obscure = !(v ?? false)),
                    title: const Text('Show passwords'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CeylonSpiceTheme.cinnamon,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: submitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setSheetState(() => submitting = true);

                              final auth = context.read<app_auth.AuthProvider>();
                              final success = await auth.changePassword(
                                currentPassword: currentController.text,
                                newPassword: newController.text,
                              );

                              setSheetState(() => submitting = false);

                              if (!ctx.mounted) return;
                              if (success) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password updated successfully')),
                                );
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(auth.errorMessage ?? 'Failed to update password')),
                                );
                              }
                            },
                      child: submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CeylonSpiceTheme.darkSurface,
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<app_auth.AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<app_auth.AuthProvider>();
    final user = auth.appUser;

    return Scaffold(
      backgroundColor: CeylonSpiceTheme.darkBg,
      body: user == null
          ? const Center(child: CircularProgressIndicator(color: CeylonSpiceTheme.saffron))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 220,
                  pinned: true,
                  backgroundColor: CeylonSpiceTheme.deepJungle,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [CeylonSpiceTheme.deepJungle, CeylonSpiceTheme.darkBg],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: CeylonSpiceTheme.saffron, width: 2.5),
                                  ),
                                  child: CircleAvatar(
                                    radius: 48,
                                    backgroundColor: CeylonSpiceTheme.darkCard,
                                    backgroundImage: user.photoBase64.isNotEmpty
                                        ? MemoryImage(base64Decode(user.photoBase64))
                                        : null,
                                    child: user.photoBase64.isEmpty
                                        ? const Icon(Icons.person, size: 48, color: CeylonSpiceTheme.textSecondary)
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _uploadingPhoto ? null : _pickAndUploadAvatar,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: CeylonSpiceTheme.saffron,
                                        border: Border.all(color: CeylonSpiceTheme.darkBg, width: 2),
                                      ),
                                      child: _uploadingPhoto
                                          ? const Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                                            )
                                          : const Icon(Icons.camera_alt, size: 16, color: Colors.black87),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.name.isEmpty ? 'Traveler' : user.name,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: CeylonSpiceTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: GoogleFonts.lato(fontSize: 13, color: CeylonSpiceTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user.bio.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: CeylonSpiceTheme.darkCard,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.format_quote, size: 16, color: CeylonSpiceTheme.saffron),
                                    SizedBox(width: 6),
                                    Text('About', style: TextStyle(color: CeylonSpiceTheme.saffron, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(user.bio, style: Theme.of(context).textTheme.bodyLarge),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          'ACCOUNT SETTINGS',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                            color: CeylonSpiceTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.edit_outlined,
                          title: 'Edit Profile',
                          subtitle: 'Update your name and bio',
                          onTap: _editNameBio,
                        ),
                        _SettingsTile(
                          icon: Icons.lock_reset_outlined,
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          onTap: _changePassword,
                        ),
                        const SizedBox(height: 24),
                        _SettingsTile(
                          icon: Icons.logout,
                          title: 'Sign Out',
                          subtitle: 'Log out of your account',
                          iconColor: Colors.redAccent,
                          titleColor: Colors.redAccent,
                          onTap: _confirmSignOut,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: CeylonSpiceTheme.darkCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? CeylonSpiceTheme.saffron).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor ?? CeylonSpiceTheme.saffron, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? CeylonSpiceTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: CeylonSpiceTheme.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: CeylonSpiceTheme.textSecondary, size: 20),
        onTap: onTap,
        ),
      ),
    );
  }
}