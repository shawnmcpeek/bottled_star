/// Stable achievement IDs — keep for future Play Games / Game Center sync.
enum AchievementId {
  firstFusion('first_fusion', 'First fusion', 'Combine two nuclei.'),
  reachIron('reach_iron', 'Reach iron', 'Climb the ladder to Fe.'),
  firstSupernova(
    'first_supernova',
    'First supernova',
    'Detonate iron against iron.',
  ),
  firstKilonova(
    'first_kilonova',
    'First kilonova',
    'Collide two neutron remnants.',
  ),
  fiveKilonovas(
    'five_kilonovas',
    'Five kilonovas',
    'Bank five remnant collisions in one run.',
  ),
  quietEnd(
    'quiet_end',
    'Quiet end',
    'Voluntarily bank a Collapse run.',
  ),
  postAScore(
    'post_a_score',
    'Post a score',
    'Submit a run to the cloud boards.',
  ),
  unlockChallenge(
    'unlock_challenge',
    'Unlock Challenge',
    'Purchase Challenge mode.',
  );

  const AchievementId(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;

  static AchievementId? fromId(String id) {
    for (final a in AchievementId.values) {
      if (a.id == id) return a;
    }
    return null;
  }
}
