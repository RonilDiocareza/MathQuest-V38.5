import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/models/user_account.dart';

void main() {
  test('serializes the selected character with the user profile', () {
    final account = UserAccount(
      email: 'student@example.com',
      role: 'student',
      status: 'pending',
      name: 'Student',
      address: 'School',
      lrn: '123456789012',
      character: 'girl',
      profilePhotoUrl: 'https://example.com/profile-photo',
    );

    expect(account.toJson()['character'], 'girl');
    expect(
      UserAccount.fromJson(account.toJson()).profilePhotoUrl,
      'https://example.com/profile-photo',
    );
  });

  test('persists either selected registration character', () {
    for (final character in ['boy', 'girl']) {
      final account = UserAccount(
        email: 'student@example.com',
        role: 'student',
        status: 'pending',
        name: 'Student',
        address: 'School',
        lrn: '123456789012',
        character: character,
      );

      expect(account.toJson()['character'], character);
      expect(UserAccount.fromJson(account.toJson()).character, character);
    }
  });

  test('defaults legacy profiles to boy', () {
    final account = UserAccount.fromJson({
      'email': 'student@example.com',
      'role': 'student',
      'status': 'pending',
      'name': 'Student',
      'address': 'School',
      'lrn': '123456789012',
    });

    expect(account.character, 'boy');
    expect(account.profilePhotoUrl, isEmpty);
  });

  test('recognizes teacher roles from the Firestore account profile', () {
    final teacher = UserAccount.fromJson({
      'uid': 'SG58XfeEt9eP7xdUoFaC7vT7Zte2',
      'email': 'teacher@example.com',
      'role': 'teacher',
      'status': 'approved',
      'name': 'Rhodney Nano',
    });

    expect(teacher.isTeacher, isTrue);
    expect(teacher.isAdmin, isFalse);
    expect(teacher.isApproved, isTrue);

    final student = UserAccount.fromJson({
      'email': 'student@example.com',
      'role': 'student',
      'status': 'approved',
      'name': 'Student',
    });
    expect(student.isTeacher, isFalse);
  });

  test('does not infer a student role when profile role data is missing', () {
    final account = UserAccount.fromJson({
      'email': 'unknown@example.com',
      'status': 'approved',
      'name': 'Unknown Role',
    });

    expect(account.role, isEmpty);
    expect(account.isTeacher, isFalse);
    expect(account.isAdmin, isFalse);
  });

  test('persists an inline profile photo in the account record', () {
    const photoDataUrl = 'data:image/jpeg;base64,YWJj';
    final account = UserAccount.fromJson({
      'email': 'student@example.com',
      'role': 'student',
      'status': 'approved',
      'name': 'Student',
      'address': 'School',
      'lrn': '123456789012',
      'profilePhotoUrl': photoDataUrl,
    });

    expect(account.toJson()['profilePhotoUrl'], photoDataUrl);
  });

  test('reads and preserves an explicitly stored gender', () {
    final account = UserAccount.fromJson({
      'email': 'teacher@example.com',
      'role': 'teacher',
      'status': 'approved',
      'name': 'Teacher',
      'gender': 'Female',
    });

    expect(account.gender, 'Female');
    expect(account.toJson()['gender'], 'Female');
    expect(account.copyWith(name: 'Updated').gender, 'Female');
  });

  test('leaves unspecified gender empty without inferring from other fields',
      () {
    final account = UserAccount.fromJson({
      'email': 'teacher@example.com',
      'role': 'teacher',
      'status': 'approved',
      'name': 'Jane Teacher',
      'character': 'girl',
    });

    expect(account.gender, isEmpty);
    expect(account.toJson().containsKey('gender'), isFalse);
  });

  test('stores student grade separately from the account role', () {
    final account = UserAccount.fromJson({
      'email': 'student@example.com',
      'role': 'student',
      'status': 'approved',
      'name': 'Student',
      'grade': 'Grade 7',
      'lrn': '001234567890',
    });

    expect(account.role, 'student');
    expect(account.grade, 'Grade 7');
    expect(account.lrn, '001234567890');
    expect(account.copyWith(grade: 'Grade 7').toJson()['role'], 'student');
  });

  test('sorts displayed accounts by case-insensitive name with safe fallbacks',
      () {
    UserAccount account({
      required String uid,
      required String name,
      required String email,
    }) =>
        UserAccount(
          uid: uid,
          email: email,
          role: 'student',
          status: 'approved',
          name: name,
          address: '',
          lrn: '',
        );

    final unsorted = [
      account(uid: 'z', name: '  ', email: 'zebra@example.com'),
      account(uid: 'b', name: 'alice smith', email: 'b@example.com'),
      account(uid: 'a', name: 'Alice Smith', email: 'a@example.com'),
      account(uid: 'c', name: 'Bob Jones', email: 'bob@example.com'),
    ];

    final sorted = UserAccount.sortAccountsByDisplayName(unsorted);

    expect(
      sorted.map((account) => account.uid).toList(),
      ['a', 'b', 'c', 'z'],
    );
    expect(unsorted.first.uid, 'z');
  });
}
