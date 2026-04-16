import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';

class ChoresPage extends StatefulWidget {
  const ChoresPage({super.key});

  @override
  State<ChoresPage> createState() => _ChoresPageState();
}

class _ChoresPageState extends State<ChoresPage> {
  final List<ChoreItem> todoChores = [
    ChoreItem(
      name: 'Tidying',
      description:
          'Tidy the house by picking up loose clothes, arranging the pillows, and watering the plants.',
      deadline: '3/23/2026',
      estimatedTime: '1-2 hours',
      roommate: 'Geoffrey',
      recurring: false,
    ),
  ];

  final List<CompletedChoreItem> completedChores = [
    CompletedChoreItem(
      name: 'Laundry',
      description: 'Wash, dry, and fold clothes.',
      deadline: '3/20/2026',
      estimatedTime: '1 hour',
      roommate: 'Geoffrey',
      recurring: true,
      completedAt: '3/20/2026, 3:22pm',
    ),
    CompletedChoreItem(
      name: 'Dishwashing',
      description: 'Wash dishes and wipe kitchen counters.',
      deadline: '3/19/2026',
      estimatedTime: '45 min',
      roommate: 'Geoffrey',
      recurring: true,
      completedAt: '3/19/2026, 1:18pm',
    ),
    CompletedChoreItem(
      name: 'Trash',
      description: 'Take out trash and replace liners.',
      deadline: '3/19/2026',
      estimatedTime: '15 min',
      roommate: 'Geoffrey',
      recurring: true,
      completedAt: '3/19/2026, 11:01am',
    ),
    CompletedChoreItem(
      name: 'Vacuuming',
      description: 'Vacuum common areas and hallway.',
      deadline: '3/18/2026',
      estimatedTime: '30 min',
      roommate: 'Geoffrey',
      recurring: true,
      completedAt: '3/18/2026, 7:22pm',
    ),
    CompletedChoreItem(
      name: 'Dusting',
      description: 'Dust shelves, tables, and TV stand.',
      deadline: '3/16/2026',
      estimatedTime: '25 min',
      roommate: 'Geoffrey',
      recurring: true,
      completedAt: '3/16/2026, 5:13pm',
    ),
  ];

  bool todoExpanded = true;
  bool completedExpanded = true;

  int get totalChores => todoChores.length + completedChores.length;

  int get completedCount => completedChores.length;

  int get completedPercent {
    if (totalChores == 0) return 0;
    return ((completedCount / totalChores) * 100).round();
  }

  void _completeTodo(ChoreItem item) {
    setState(() {
      todoChores.remove(item);
      completedChores.insert(
        0,
        CompletedChoreItem(
          name: item.name,
          description: item.description,
          deadline: item.deadline,
          estimatedTime: item.estimatedTime,
          roommate: item.roommate,
          recurring: item.recurring,
          completedAt: _formattedNow(),
        ),
      );
    });
  }

  void _showChoreOverlay(ChoreItem chore) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ChoreOverlay(
          chore: chore,
          onComplete: () {
            _completeTodo(chore);
            Navigator.pop(context);
          },
          onDelete: () {
            setState(() {
              todoChores.remove(chore);
            });
            Navigator.pop(context);
          },
        );
      },
    );
  }

  String _formattedNow() {
    final now = DateTime.now();

    final month = now.month;
    final day = now.day;
    final year = now.year;

    int hour = now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final suffix = hour >= 12 ? 'pm' : 'am';

    hour = hour % 12;
    if (hour == 0) hour = 12;

    return '$month/$day/$year, $hour:$minute$suffix';
  }

  void _showAddChoreDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final deadlineController = TextEditingController();
    final timeController = TextEditingController();
    final roommateController = TextEditingController();
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
                      TextField(
                        controller: roommateController,
                        decoration: const InputDecoration(hintText: 'Roommate'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: recurring,
                            onChanged: (value) {
                              setDialogState(() {
                                recurring = value ?? false;
                              });
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
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.tan,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;

                    setState(() {
                      todoChores.add(
                        ChoreItem(
                          name: name,
                          description: descriptionController.text.trim().isEmpty
                              ? 'No description added.'
                              : descriptionController.text.trim(),
                          deadline: deadlineController.text.trim().isEmpty
                              ? 'No deadline'
                              : deadlineController.text.trim(),
                          estimatedTime: timeController.text.trim().isEmpty
                              ? 'Not set'
                              : timeController.text.trim(),
                          roommate: roommateController.text.trim().isEmpty
                              ? 'Unassigned'
                              : roommateController.text.trim(),
                          recurring: recurring,
                        ),
                      );
                    });

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

  @override
  Widget build(BuildContext context) {
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
              const Center(
                child: Text(
                  'Week of March 23',
                  style: TextStyle(
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
                progress: totalChores == 0 ? 0 : completedCount / totalChores,
              ),
              const SizedBox(height: 26),
              _SectionHeader(
                title: 'To-Do',
                expanded: todoExpanded,
                onTap: () {
                  setState(() {
                    todoExpanded = !todoExpanded;
                  });
                },
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
              if (completedExpanded)
                ...completedChores.map(
                  (chore) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompletedChoreTile(
                      title: chore.name,
                      time: chore.completedAt,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoresHeader extends StatelessWidget {
  const _ChoresHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: AppLogo(type: LogoType.wordmark, width: 230),
          ),
        ),
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

  const _CompletedChoreTile({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
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

  const _ChoreOverlay({
    required this.chore,
    required this.onComplete,
    required this.onDelete,
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

class _OverlayField extends StatelessWidget {
  final String label;
  final String value;

  const _OverlayField(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.45,
          ),
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
  final String name;
  final String description;
  final String deadline;
  final String estimatedTime;
  final String roommate;
  final bool recurring;

  ChoreItem({
    required this.name,
    required this.description,
    required this.deadline,
    required this.estimatedTime,
    required this.roommate,
    required this.recurring,
  });
}

class CompletedChoreItem extends ChoreItem {
  final String completedAt;

  CompletedChoreItem({
    required super.name,
    required super.description,
    required super.deadline,
    required super.estimatedTime,
    required super.roommate,
    required super.recurring,
    required this.completedAt,
  });
}
