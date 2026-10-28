/// Blocks offensive leaderboard names, including leetspeak, spacing, and
/// stretched-letter evasions ("f u c k", "fvck", "sh1t", "fuuuck").
abstract final class NameFilter {
  /// Blocked anywhere in the name, even inside other words or across spaces.
  static const List<String> anywhere = [
    'fuck', 'fuk', 'phuck', 'shit', 'cunt', 'nigg', 'nigr', 'faggot',
    'bitch', 'biatch', 'whore', 'slut', 'porn', 'penis', 'vagina', 'pussy',
    'dildo', 'asshole', 'arsehole', 'bastard', 'hitler', 'nazi', 'retard',
    'tranny', 'kike', 'wetback', 'jizz', 'twat', 'bollock', 'molest',
    'pedophile', 'paedo', 'blowjob', 'handjob', 'cocksuck', 'motherf',
    'siegheil', 'killyourself',
  ];

  /// Blocked only as a whole word — these appear inside innocent words
  /// (class, Dickens, peacock, grape, therapist, spice, raccoon, torpedo).
  static const List<String> wholeWord = [
    'ass', 'arse', 'dick', 'cock', 'cum', 'fag', 'fags', 'rape', 'raping',
    'rapist', 'spic', 'chink', 'coon', 'gook', 'pedo', 'kkk', 'kys', 'tit',
    'tits', 'nig', 'dyke', 'negro', 'sex', 'anal', 'anus', 'piss', 'hoe',
    'hoes', 'thot', 'milf', 'nsfw', 'wtf', 'stfu', 'wank', 'clit', 'semen',
    'horny', 'boner', 'cumshot',
  ];

  static const Map<String, String> _leet = {
    '0': 'o',
    '1': 'i',
    '!': 'i',
    '|': 'i',
    '3': 'e',
    '4': 'a',
    '@': 'a',
    '5': 's',
    r'$': 's',
    '7': 't',
    '+': 't',
    '8': 'b',
    '9': 'g',
    '6': 'g',
  };

  static bool isAllowed(String name) => !isBlocked(name);

  static bool isBlocked(String name) {
    final mapped =
        name.toLowerCase().split('').map((c) => _leet[c] ?? c).join();
    // "fvck" / "cvnt": check once with v read as u, once as itself.
    for (final source in {mapped, mapped.replaceAll('v', 'u')}) {
      if (_hits(source)) return true;
    }
    return false;
  }

  static bool _hits(String source) {
    final joined = source.replaceAll(RegExp('[^a-z]'), '');
    final squeezedJoined = _squeeze(joined);
    for (final term in anywhere) {
      if (joined.contains(term)) return true;
      final squeezedTerm = _squeeze(term);
      // Squeezing "nigg" to "nig" would hit "night"; only squeeze terms that
      // stay distinctive.
      if ((squeezedTerm == term || squeezedTerm.length >= 5) &&
          squeezedJoined.contains(squeezedTerm)) {
        return true;
      }
    }

    final words = {
      ...source.split(RegExp('[^a-z]+')).where((w) => w.isNotEmpty),
      joined,
    };
    for (final term in wholeWord) {
      final squeezedTerm = _squeeze(term);
      for (final word in words) {
        if (word == term) return true;
        // "asss" matches "ass", but "as" does not.
        if (word.length >= term.length && _squeeze(word) == squeezedTerm) {
          return true;
        }
      }
    }
    return false;
  }

  /// "fuuuuck" -> "fuck", "assss" -> "as".
  static String _squeeze(String s) {
    final out = StringBuffer();
    String? prev;
    for (final c in s.split('')) {
      if (c != prev) out.write(c);
      prev = c;
    }
    return out.toString();
  }
}
