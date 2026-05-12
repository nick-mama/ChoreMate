import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:choremate/features/chores/pages/chores_page.dart';

void main() {
  group('ChoreItem', () {
    test('uses fallback values for missing user-facing fields', () {
      final chore = ChoreItem.fromFirestore('chore-1', {});

      expect(chore.id, 'chore-1');
      expect(chore.name, 'Untitled Chore');
      expect(chore.description, 'No description added.');
      expect(chore.deadline, 'No deadline');
      expect(chore.estimatedTime, 'Not set');
      expect(chore.roommate, 'Unassigned');
      expect(chore.recurring, false);
      expect(chore.completed, false);
      expect(chore.completedAtText, '');
    });

    test('formats deadline from DateTime', () {
      final chore = ChoreItem.fromFirestore('chore-1', {
        'name': 'Vacuum',
        'dueDate': DateTime(2026, 3, 23),
      });

      expect(chore.deadline, '3/23/2026');
    });

    test('formats deadline from Firestore Timestamp', () {
      final chore = ChoreItem.fromFirestore('chore-1', {
        'name': 'Dishes',
        'dueDate': Timestamp.fromDate(DateTime(2026, 3, 23)),
      });

      expect(chore.deadline, '3/23/2026');
    });

    test('formats completed time correctly in the morning', () {
      final chore = ChoreItem.fromFirestore('chore-1', {
        'completed': true,
        'completedAt': DateTime(2026, 3, 23, 9, 5),
      });

      expect(chore.completedAtText, '3/23/2026, 9:05am');
    });

    test('formats completed time correctly in the afternoon', () {
      final chore = ChoreItem.fromFirestore('chore-1', {
        'completed': true,
        'completedAt': DateTime(2026, 3, 23, 15, 30),
      });

      expect(chore.completedAtText, '3/23/2026, 3:30pm');
    });

    test('keeps assigned roommate data', () {
      final chore = ChoreItem.fromFirestore('chore-1', {
        'assignedTo': 'user-123',
        'assignedToName': 'Alex Kim',
      });

      expect(chore.assignedTo, 'user-123');
      expect(chore.roommate, 'Alex Kim');
    });
  });

  group('FirstOrNullExtension', () {
    test('returns null for an empty iterable', () {
      expect(<String>[].firstOrNull, isNull);
    });

    test('returns first item for a non-empty iterable', () {
      expect(['a', 'b', 'c'].firstOrNull, 'a');
    });
  });
}
