/// `cb_<category>_<subject>_<state>` — the export name from the asset
/// checklist. [state] may itself contain underscores (`stone_club`); it is
/// omitted only for a sheet that is the whole subject (`cb_rock_rok`).
class SpriteName {
  const SpriteName({
    required this.category,
    required this.subject,
    this.state = '',
  });

  final String category;
  final String subject;
  final String state;

  static final _pattern = RegExp(
    r'^cb_([a-z0-9]+)_([a-z0-9]+)(?:_([a-z0-9_]+))?$',
  );

  static SpriteName? parse(String stem) {
    final m = _pattern.firstMatch(stem);
    if (m == null) return null;
    return SpriteName(
      category: m.group(1)!,
      subject: m.group(2)!,
      state: m.group(3) ?? '',
    );
  }

  String get stem => state.isEmpty
      ? 'cb_${category}_$subject'
      : 'cb_${category}_${subject}_$state';

  /// Folder under `assets/sprites/`. Animation sheets live with the players
  /// even though their category is `anim`.
  String get folder => switch (category) {
    'anim' => 'players',
    'club' => 'clubs',
    'rock' => 'rocks',
    'bg' || 'field' => 'field',
    'card' || 'fx' || 'palette' => 'ui',
    _ => category,
  };

  String get pngAsset => 'assets/sprites/$folder/$stem.png';

  String get jsonAsset => 'assets/sprites/$folder/$stem.json';

  @override
  bool operator ==(Object other) =>
      other is SpriteName &&
      other.category == category &&
      other.subject == subject &&
      other.state == state;

  @override
  int get hashCode => Object.hash(category, subject, state);

  @override
  String toString() => stem;
}
