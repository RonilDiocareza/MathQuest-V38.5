import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mathquest/utils/display_text.dart';

void main() {
  test('formats persisted status values as display-only sentence case', () {
    expect(displayStatusLabel('correct'), 'Correct');
    expect(displayStatusLabel('incorrect'), 'Incorrect');
    expect(displayStatusLabel('timed_out'), 'Timed out');
    expect(displayStatusLabel('completed'), 'Completed');
    expect(displayStatusLabel('failed'), 'Failed');
    expect(displayStatusLabel('approved'), 'Approved');
    expect(displayStatusLabel('pending'), 'Pending');
    expect(displayStatusLabel('  in_progress  '), 'In progress');
    expect(displayStatusLabel(''), '');
  });
}
