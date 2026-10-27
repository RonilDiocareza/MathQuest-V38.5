String displayStatusLabel(String status) {
  final normalized =
      status.trim().replaceAll(RegExp(r'[_\s]+'), ' ').toLowerCase();
  if (normalized.isEmpty) return normalized;
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}
