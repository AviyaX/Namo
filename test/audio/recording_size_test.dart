import 'package:buddhist_gatha/audio/recording_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sizes are decimal megabytes, one decimal under 10 MB', () {
    expect(formatSize(1046598), '1.0 MB');
    expect(formatSize(171439), '0.2 MB');
    expect(formatSize(7420182), '7.4 MB');
  });

  test('from 10 MB sizes are whole megabytes', () {
    expect(formatSize(46219957), '46 MB');
    expect(formatSize(102523878), '103 MB');
  });
}
