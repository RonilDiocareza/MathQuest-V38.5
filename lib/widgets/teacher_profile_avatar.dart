import 'dart:typed_data';

import 'package:flutter/material.dart';

String? teacherAvatarAssetForGender(String? gender) {
  switch (gender?.trim().toLowerCase()) {
    case 'female':
      return 'assets/images/teacher/female_teacher.png';
    case 'male':
      return 'assets/images/teacher/male_teacher.png';
    default:
      return null;
  }
}

class TeacherProfileAvatar extends StatelessWidget {
  const TeacherProfileAvatar({
    super.key,
    required this.gender,
    this.photoBytes,
    this.size = 100,
    this.backgroundColor = const Color(0xFFD09F5C),
  });

  final String? gender;
  final Uint8List? photoBytes;
  final double size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final avatarAsset = teacherAvatarAssetForGender(gender);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: photoBytes != null
            ? Image.memory(
                photoBytes!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : avatarAsset == null
                ? Icon(
                    Icons.person_rounded,
                    size: size * 0.58,
                    color: Colors.white,
                  )
                : Image.asset(
                    avatarAsset,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                  ),
      ),
    );
  }
}
