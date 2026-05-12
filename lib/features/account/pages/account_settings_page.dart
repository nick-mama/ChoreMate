import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/theme/app_colors.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  final _usernameController = TextEditingController();

  bool _loading = true;
  bool _savingUsername = false;
  bool _savingStartOfWeek = false;
  bool _savingPhoto = false;

  String _email = '';
  String _startOfWeek = 'sunday';
  String _photoUrl = '';

  Map<String, bool> _notificationSettings = {
    'newChoreAssigned': true,
    'overdueChores': true,
    'upcomingDeadlines': true,
    'newPeopleAdded': true,
    'inApp': true,
    'email': false,
    'banner': true,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));

    final data = doc.data() ?? {};
    final savedNotificationSettings = data['notificationSettings'];

    if (!mounted) return;
    setState(() {
      _email = user.email ?? '';
      _usernameController.text = data['username'] ?? '';
      _startOfWeek = data['startOfWeek'] ?? 'sunday';
      _photoUrl = data['photoUrl'] ?? '';

      if (savedNotificationSettings is Map) {
        _notificationSettings = {
          ..._notificationSettings,
          ...savedNotificationSettings.map(
            (key, value) => MapEntry(key.toString(), value == true),
          ),
        };
      }

      _loading = false;
    });
  }

  Future<void> _changeProfilePhoto() async {
    final user = _auth.currentUser;
    if (user == null || _savingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Choose Profile Picture',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.tan,
                  ),
                  title: const Text(
                    'Photo Library',
                    style: TextStyle(color: AppColors.text),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.tan,
                  ),
                  title: const Text(
                    'Camera',
                    style: TextStyle(color: AppColors.text),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: AppColors.tan,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Profile Picture',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() => _savingPhoto = true);

    try {
      final ref = _storage.ref().child(
        'profilePictures/${user.uid}/profile.jpg',
      );

      await ref.putFile(
        File(croppedFile.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _photoUrl = url);

      _showMessage('Profile picture updated.');
    } catch (e) {
      debugPrint('Upload error: $e');
      _showMessage('Upload failed.');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _removeProfilePhoto() async {
    final user = _auth.currentUser;
    if (user == null || _savingPhoto) return;

    setState(() => _savingPhoto = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      try {
        await _storage
            .ref()
            .child('profilePictures/${user.uid}/profile.jpg')
            .delete();
      } catch (_) {}

      if (!mounted) return;
      setState(() => _photoUrl = '');

      _showMessage('Profile picture removed.');
    } catch (_) {
      _showMessage('Could not remove profile picture.');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _saveUsername() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      _showMessage('Username cannot be empty.');
      return;
    }

    setState(() => _savingUsername = true);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'username': username,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('Username updated.');
    } catch (_) {
      _showMessage('Could not update username.');
    } finally {
      if (mounted) setState(() => _savingUsername = false);
    }
  }

  Future<void> _saveStartOfWeek(String value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _startOfWeek = value;
      _savingStartOfWeek = true;
    });

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'startOfWeek': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('Start of week updated.');
    } catch (_) {
      _showMessage('Could not update start of week.');
    } finally {
      if (mounted) setState(() => _savingStartOfWeek = false);
    }
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _notificationSettings[key] = value;
    });

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'notificationSettings': {key: value},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationSettings[key] = !value;
      });
      _showMessage('Could not update notification setting.');
    }
  }

  Future<void> _changeEmail() async {
    final newEmailController = TextEditingController();
    final passwordController = TextEditingController();

    final confirmed = await _showAuthDialog(
      title: 'Change Email',
      fields: [
        _DialogField(
          controller: newEmailController,
          label: 'New email',
          keyboardType: TextInputType.emailAddress,
        ),
        _DialogField(
          controller: passwordController,
          label: 'Current password',
          obscureText: true,
        ),
      ],
    );

    if (confirmed != true) return;

    final user = _auth.currentUser;
    final currentEmail = user?.email;
    final newEmail = newEmailController.text.trim();
    final password = passwordController.text.trim();

    if (user == null || currentEmail == null) return;

    if (newEmail.isEmpty || password.isEmpty) {
      _showMessage('Please fill out all fields.');
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      _showMessage('Verification email sent to $newEmail.');
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e));
    } catch (_) {
      _showMessage('Could not change email.');
    }
  }

  Future<void> _changePassword() async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    final confirmed = await _showAuthDialog(
      title: 'Change Password',
      fields: [
        _DialogField(
          controller: oldPasswordController,
          label: 'Current password',
          obscureText: true,
        ),
        _DialogField(
          controller: newPasswordController,
          label: 'New password',
          obscureText: true,
        ),
      ],
    );

    if (confirmed != true) return;

    final user = _auth.currentUser;
    final currentEmail = user?.email;
    final oldPassword = oldPasswordController.text.trim();
    final newPassword = newPasswordController.text.trim();

    if (user == null || currentEmail == null) return;

    if (oldPassword.isEmpty || newPassword.isEmpty) {
      _showMessage('Please fill out all fields.');
      return;
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: currentEmail,
        password: oldPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      if (!mounted) return;
      _showMessage('Password updated.');
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e));
    } catch (_) {
      _showMessage('Could not change password.');
    }
  }

  Future<bool?> _showAuthDialog({
    required String title,
    required List<_DialogField> fields,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: fields.map((field) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: field.controller,
                  obscureText: field.obscureText,
                  keyboardType: field.keyboardType,
                  decoration: InputDecoration(
                    labelText: field.label,
                    filled: true,
                    fillColor: AppColors.field,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.text),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.tan,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak.';
      case 'email-already-in-use':
        return 'That email is already in use.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'requires-recent-login':
        return 'Please log out and log back in before making this change.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _setting(String key) {
    return _notificationSettings[key] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.text,
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            28 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsCard(
                title: 'Account',
                children: [
                  _InfoRow(label: 'Email', value: _email),
                  const SizedBox(height: 14),
                  _SettingsButton(
                    icon: Icons.email_outlined,
                    label: 'Change Email',
                    onTap: _changeEmail,
                  ),
                  const SizedBox(height: 10),
                  _SettingsButton(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change Password',
                    onTap: _changePassword,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsCard(
                title: 'Profile',
                children: [
                  Center(
                    child: _ProfilePhotoPicker(
                      photoUrl: _photoUrl,
                      saving: _savingPhoto,
                      onChangePhoto: _changeProfilePhoto,
                      onRemovePhoto: _photoUrl.isEmpty
                          ? null
                          : _removeProfilePhoto,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: true,
                      fillColor: AppColors.field,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrimaryButton(
                    label: _savingUsername ? 'Saving...' : 'Save Username',
                    onTap: _savingUsername ? null : _saveUsername,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsCard(
                title: 'Preferences',
                children: [
                  const Text(
                    'Start of Week',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 10),
                  RadioGroup<String>(
                    groupValue: _startOfWeek,
                    onChanged: (value) {
                      if (value == null || _savingStartOfWeek) return;
                      _saveStartOfWeek(value);
                    },
                    child: const Column(
                      children: [
                        _WeekOption(label: 'Sunday', value: 'sunday'),
                        _WeekOption(label: 'Monday', value: 'monday'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingsCard(
                title: 'Notifications',
                children: [
                  const _SettingsSubsectionTitle('Notify me when...'),
                  const SizedBox(height: 6),
                  _NotificationSwitch(
                    title: 'New chores assigned',
                    value: _setting('newChoreAssigned'),
                    onChanged: (value) =>
                        _saveNotificationSetting('newChoreAssigned', value),
                  ),
                  _NotificationSwitch(
                    title: 'Overdue chores',
                    value: _setting('overdueChores'),
                    onChanged: (value) =>
                        _saveNotificationSetting('overdueChores', value),
                  ),
                  _NotificationSwitch(
                    title: 'Upcoming deadlines',
                    value: _setting('upcomingDeadlines'),
                    onChanged: (value) =>
                        _saveNotificationSetting('upcomingDeadlines', value),
                  ),
                  _NotificationSwitch(
                    title: 'New people added to household',
                    value: _setting('newPeopleAdded'),
                    onChanged: (value) =>
                        _saveNotificationSetting('newPeopleAdded', value),
                  ),
                  const SizedBox(height: 18),
                  const _SettingsSubsectionTitle('Notification methods'),
                  const SizedBox(height: 6),
                  _NotificationSwitch(
                    title: 'In-app',
                    value: _setting('inApp'),
                    onChanged: (value) =>
                        _saveNotificationSetting('inApp', value),
                  ),
                  _NotificationSwitch(
                    title: 'Email',
                    subtitle: 'Email delivery requires backend support.',
                    value: _setting('email'),
                    onChanged: (value) =>
                        _saveNotificationSetting('email', value),
                  ),
                  _NotificationSwitch(
                    title: 'Banner',
                    subtitle:
                        'Banner delivery requires push or local notifications.',
                    value: _setting('banner'),
                    onChanged: (value) =>
                        _saveNotificationSetting('banner', value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogField {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;

  const _DialogField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
  });
}

class _ProfilePhotoPicker extends StatelessWidget {
  final String photoUrl;
  final bool saving;
  final VoidCallback onChangePhoto;
  final VoidCallback? onRemovePhoto;

  const _ProfilePhotoPicker({
    required this.photoUrl,
    required this.saving,
    required this.onChangePhoto,
    required this.onRemovePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 126,
          height: 126,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.tan, width: 8),
          ),
          child: ClipRRect(
            child: photoUrl.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.person_outline,
                      size: 56,
                      color: AppColors.tan,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, _, _) => const Center(
                      child: Icon(
                        Icons.person_outline,
                        size: 56,
                        color: AppColors.tan,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        _PrimaryButton(
          label: saving ? 'Saving...' : 'Change Profile Picture',
          onTap: saving ? null : onChangePhoto,
        ),
        if (onRemovePhoto != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: saving ? null : onRemovePhoto,
            child: const Text(
              'Remove Profile Picture',
              style: TextStyle(color: AppColors.text),
            ),
          ),
        ],
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _NotificationSwitch extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitch({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.tan,
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.25,
                color: AppColors.text,
              ),
            ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tan,
          foregroundColor: Colors.white,
          elevation: 0,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tan,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _WeekOption extends StatelessWidget {
  final String label;
  final String value;

  const _WeekOption({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      activeColor: AppColors.tan,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: const TextStyle(fontSize: 15, color: AppColors.text),
      ),
    );
  }
}

class _SettingsSubsectionTitle extends StatelessWidget {
  final String text;

  const _SettingsSubsectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }
}
