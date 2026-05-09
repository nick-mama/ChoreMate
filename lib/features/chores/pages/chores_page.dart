import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';

class ChoresPage extends StatefulWidget {
  const ChoresPage({super.key});

  @override
  State<ChoresPage> createState() => _ChoresPageState();
}

class _ChoresPageState extends State<ChoresPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool todoExpanded = true;
  bool completedExpanded = true;
  bool _loadingHousehold = true;

  String _householdId = '';
  List<HouseholdMember> roommates = [];

  @override
  void initState() {
    super.initState();
    _loadHousehold();
  }

  Future<void> _loadHousehold() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) return;

    final householdId = userData['householdId'] ?? '';

    final usersSnapshot = await _db
        .collection('users')
        .where('householdId', isEqualTo: householdId)
        .get();

    final loadedRoommates = usersSnapshot.docs.map((doc) {
      final data = doc.data();
      final firstName = data['firstName'] ?? '';
      final lastName = data['lastName'] ?? '';
      final username = data['username'] ?? '';

      final fullName = '$firstName $lastName'.trim();

      return HouseholdMember(
        uid: doc.id,
        name: fullName.isNotEmpty ? fullName : username,
      );
    }).toList();

    if (!mounted) return;

    setState(() {
      _householdId = householdId;
      roommates = loadedRoommates;
      _loadingHousehold = false;
    });
  }

  Stream<List<ChoreItem>> _choresStream() {
    if (_householdId.isEmpty) {
      return const Stream.empty();
    }

    return _db
        .collection('chores')
        .where('householdId', isEqualTo: _householdId)
        .snapshots()
        .map((snapshot) {
          final chores = snapshot.docs.map((doc) {
            return ChoreItem.fromFirestore(doc.id, doc.data());
          }).toList();

          chores.sort((a, b) {
            final aDate = a.dueDate;
            final bDate = b.dueDate;

            if (aDate == null && bDate == null) return 0;
            if (aDate == null) return 1;
            if (bDate == null) return -1;

            return aDate.compareTo(bDate);
          });

          return chores;
        });
  }

  Future<void> _addChore({
    required String name,
    required String description,
    required DateTime? dueDate,
    required String estimatedTime,
    required HouseholdMember? roommate,
    required bool recurring,
  }) async {
    await _db.collection('chores').add({
      'householdId': _householdId,
      'name': name,
      'description': description,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'estimatedTime': estimatedTime,
      'assignedTo': roommate?.uid,
      'assignedToName': roommate?.name ?? 'Unassigned',
      'recurring': recurring,
      'completed': false,
      'completedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateChore(
    ChoreItem chore, {
    required String name,
    required String description,
    required DateTime? dueDate,
    required String estimatedTime,
    required HouseholdMember? roommate,
    required bool recurring,
  }) async {
    await _db.collection('chores').doc(chore.id).update({
      'name': name,
      'description': description,
      'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate),
      'estimatedTime': estimatedTime,
      'assignedTo': roommate?.uid,
      'assignedToName': roommate?.name ?? 'Unassigned',
      'recurring': recurring,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _completeTodo(ChoreItem chore) async {
    await _db.collection('chores').doc(chore.id).update({
      'completed': true,
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _undoCompleted(ChoreItem chore) async {
    await _db.collection('chores').doc(chore.id).update({
      'completed': false,
      'completedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteChore(ChoreItem chore) async {
    await _db.collection('chores').doc(chore.id).delete();
  }

  void _showChoreOverlay(ChoreItem chore) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ChoreOverlay(
          chore: chore,
          onComplete: () async {
            Navigator.pop(context);
            await _completeTodo(chore);
          },
          onDelete: () {
            Navigator.pop(context);
            _confirmDelete(chore.name, () => _deleteChore(chore));
          },
          onEdit: () {
            Navigator.pop(context);
            _showEditChoreDialog(chore);
          },
        );
      },
    );
  }

  void _showCompletedChoreOverlay(ChoreItem chore) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _CompletedChoreOverlay(
          chore: chore,
          onUndo: () async {
            Navigator.pop(context);
            await _undoCompleted(chore);
          },
          onDelete: () {
            Navigator.pop(context);
            _confirmDelete(chore.name, () => _deleteChore(chore));
          },
          onEdit: () {
            Navigator.pop(context);
            _showEditChoreDialog(chore);
          },
        );
      },
    );
  }

  void _showAddChoreDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final deadlineController = TextEditingController();
    final timeController = TextEditingController();

    HouseholdMember? selectedRoommate;
    bool recurring = false;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('New Chore'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Chore name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: deadlineController,
                        decoration: const InputDecoration(
                          hintText: 'Deadline (ex: 3/23/2026)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: timeController,
                        decoration: const InputDecoration(
                          hintText: 'Estimated time',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<HouseholdMember>(
                        initialValue: selectedRoommate,
                        hint: const Text('Roommate'),
                        decoration: const InputDecoration(),
                        items: roommates.map((member) {
                          return DropdownMenuItem(
                            value: member,
                            child: Text(member.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedRoommate = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: recurring,
                            onChanged: (value) {
                              setDialogState(() => recurring = value ?? false);
                            },
                          ),
                          const Text('Recurring'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tan,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    await _addChore(
                      name: name,
                      description: descriptionController.text.trim().isEmpty
                          ? 'No description added.'
                          : descriptionController.text.trim(),
                      dueDate: _parseDate(deadlineController.text.trim()),
                      estimatedTime: timeController.text.trim().isEmpty
                          ? 'Not set'
                          : timeController.text.trim(),
                      roommate: selectedRoommate,
                      recurring: recurring,
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditChoreDialog(ChoreItem chore) {
    final nameController = TextEditingController(text: chore.name);
    final descriptionController = TextEditingController(
      text: chore.description,
    );
    final deadlineController = TextEditingController(text: chore.deadline);
    final timeController = TextEditingController(text: chore.estimatedTime);

    HouseholdMember? selectedRoommate = roommates
        .where((member) => member.uid == chore.assignedTo)
        .firstOrNull;

    bool recurring = chore.recurring;

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Edit Chore'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: 'Chore name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Description',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: deadlineController,
                        decoration: const InputDecoration(
                          hintText: 'Deadline (ex: 3/23/2026)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: timeController,
                        decoration: const InputDecoration(
                          hintText: 'Estimated time',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<HouseholdMember>(
                        initialValue: selectedRoommate,
                        hint: const Text('Roommate'),
                        decoration: const InputDecoration(),
                        items: roommates.map((member) {
                          return DropdownMenuItem(
                            value: member,
                            child: Text(member.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedRoommate = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: recurring,
                            onChanged: (value) {
                              setDialogState(() => recurring = value ?? false);
                            },
                          ),
                          const Text('Recurring'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tan,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    await _updateChore(
                      chore,
                      name: name,
                      description: descriptionController.text.trim().isEmpty
                          ? 'No description added.'
                          : descriptionController.text.trim(),
                      dueDate: _parseDate(deadlineController.text.trim()),
                      estimatedTime: timeController.text.trim().isEmpty
                          ? 'Not set'
                          : timeController.text.trim(),
                      roommate: selectedRoommate,
                      recurring: recurring,
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(String choreName, Future<void> Function() onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$choreName"'),
        content: const Text(
          'Are you sure you want to delete this chore? Deleting this chore cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await onConfirm();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;

    final parts = value.split('/');
    if (parts.length != 3) return null;

    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (month == null || day == null || year == null) return null;

    return DateTime(year, month, day);
  }

  String _weekLabel() {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    return 'Week of ${_monthName(weekStart.month)} ${weekStart.day}';
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingHousehold) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    return StreamBuilder<List<ChoreItem>>(
      stream: _choresStream(),
      builder: (context, snapshot) {
        final chores = snapshot.data ?? [];

        final todoChores = chores.where((chore) => !chore.completed).toList();
        final completedChores = chores
            .where((chore) => chore.completed)
            .toList();

        final totalChores = chores.length;
        final completedCount = completedChores.length;
        final completedPercent = totalChores == 0
            ? 0
            : ((completedCount / totalChores) * 100).round();

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.tan,
            foregroundColor: Colors.white,
            elevation: 2,
            onPressed: () => _showAddChoreDialog(context),
            child: const Icon(Icons.add),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ChoresHeader(),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      _weekLabel(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$completedPercent%',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 5),
                        child: Text(
                          'of chores done',
                          style: TextStyle(fontSize: 15, color: AppColors.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ProgressBar(
                    progress: totalChores == 0
                        ? 0
                        : completedCount / totalChores,
                  ),
                  const SizedBox(height: 26),
                  _SectionHeader(
                    title: 'To-Do',
                    expanded: todoExpanded,
                    onTap: () => setState(() => todoExpanded = !todoExpanded),
                  ),
                  const SizedBox(height: 12),
                  if (todoExpanded) ...[
                    if (todoChores.isEmpty)
                      const _EmptyStateCard(text: 'No chores left. Nice work.')
                    else
                      ...todoChores.map(
                        (chore) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _TodoChoreTile(
                            title: chore.name,
                            onTap: () => _showChoreOverlay(chore),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: 'Completed',
                    expanded: completedExpanded,
                    onTap: () {
                      setState(() {
                        completedExpanded = !completedExpanded;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (completedExpanded) ...[
                    if (completedChores.isEmpty)
                      const _EmptyStateCard(text: 'No completed chores yet.')
                    else
                      ...completedChores.map(
                        (chore) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CompletedChoreTile(
                            title: chore.name,
                            time: chore.completedAtText,
                            onTap: () => _showCompletedChoreOverlay(chore),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChoresHeader extends StatelessWidget {
  const _ChoresHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        AppLogo(type: LogoType.wordmark, width: 230),
        Spacer(),
        Icon(Icons.notifications_none_rounded, size: 38, color: AppColors.text),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Container(
      height: 12,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFD0D0D0),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: clamped,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.tan,
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            color: AppColors.muted,
            size: 22,
          ),
        ],
      ),
    );
  }
}

class _TodoChoreTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _TodoChoreTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blue,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompletedChoreTile extends StatelessWidget {
  final String title;
  final String time;
  final VoidCallback onTap;

  const _CompletedChoreTile({
    required this.title,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String text;

  const _EmptyStateCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, color: AppColors.muted),
      ),
    );
  }
}

class _ChoreOverlay extends StatelessWidget {
  final ChoreItem chore;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _ChoreOverlay({
    required this.chore,
    required this.onComplete,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    chore.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onComplete,
                  icon: const Icon(Icons.check, color: Colors.white),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: Colors.white),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _OverlayField('Description:', chore.description),
            _OverlayField('Deadline:', chore.deadline),
            _OverlayField('Estimated Time:', chore.estimatedTime),
            _OverlayField('Recurring?', chore.recurring ? 'Yes' : 'No'),
            _OverlayField('Roommate:', chore.roommate),
            _OverlayField('Done?', 'No'),
          ],
        ),
      ),
    );
  }
}

class _CompletedChoreOverlay extends StatelessWidget {
  final ChoreItem chore;
  final VoidCallback onUndo;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CompletedChoreOverlay({
    required this.chore,
    required this.onUndo,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    chore.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onUndo,
                  icon: const Icon(Icons.undo, color: AppColors.text),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: AppColors.text),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: AppColors.text),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _OverlayField('Description:', chore.description, dark: true),
            _OverlayField('Deadline:', chore.deadline, dark: true),
            _OverlayField('Estimated Time:', chore.estimatedTime, dark: true),
            _OverlayField(
              'Recurring?',
              chore.recurring ? 'Yes' : 'No',
              dark: true,
            ),
            _OverlayField('Roommate:', chore.roommate, dark: true),
            _OverlayField('Completed:', chore.completedAtText, dark: true),
          ],
        ),
      ),
    );
  }
}

class _OverlayField extends StatelessWidget {
  final String label;
  final String value;
  final bool dark;

  const _OverlayField(this.label, this.value, {this.dark = false});

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.text : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: color, fontSize: 14, height: 1.45),
          children: [
            TextSpan(
              text: '$label\n',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class ChoreItem {
  final String id;
  final String name;
  final String description;
  final DateTime? dueDate;
  final String estimatedTime;
  final String? assignedTo;
  final String roommate;
  final bool recurring;
  final bool completed;
  final DateTime? completedAt;

  ChoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.dueDate,
    required this.estimatedTime,
    required this.assignedTo,
    required this.roommate,
    required this.recurring,
    required this.completed,
    required this.completedAt,
  });

  factory ChoreItem.fromFirestore(String id, Map<String, dynamic> data) {
    return ChoreItem(
      id: id,
      name: data['name'] ?? 'Untitled Chore',
      description: data['description'] ?? 'No description added.',
      dueDate: _readDate(data['dueDate']),
      estimatedTime: data['estimatedTime'] ?? 'Not set',
      assignedTo: data['assignedTo'],
      roommate: data['assignedToName'] ?? 'Unassigned',
      recurring: data['recurring'] == true,
      completed: data['completed'] == true,
      completedAt: _readDate(data['completedAt']),
    );
  }

  String get deadline {
    if (dueDate == null) return 'No deadline';
    return '${dueDate!.month}/${dueDate!.day}/${dueDate!.year}';
  }

  String get completedAtText {
    if (completedAt == null) return '';

    final month = completedAt!.month;
    final day = completedAt!.day;
    final year = completedAt!.year;

    var hour = completedAt!.hour;
    final minute = completedAt!.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'pm' : 'am';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$month/$day/$year, $hour:$minute$suffix';
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class HouseholdMember {
  final String uid;
  final String name;

  const HouseholdMember({required this.uid, required this.name});
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) return null;
    return first;
  }
}
