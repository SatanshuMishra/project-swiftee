import 'dart:math';

int levenshteinDistance(String a, String b) {
  final m = a.length;
  final n = b.length;

  var previous = List<int>.generate(n + 1, (i) => i);
  var current = List<int>.filled(n + 1, 0);

  for (var i = 1; i <= m; i++) {
    current[0] = i;
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = min(
        min(previous[j] + 1, current[j - 1] + 1),
        previous[j - 1] + cost,
      );
    }
    (previous, current) = (current, previous);
  }

  return previous[n];
}

bool isCloseMatch(String input, String target, [int maxDistance = 2]) {
  if (target.length < 5) {
    return input == target;
  }
  return levenshteinDistance(input, target) <= maxDistance;
}
