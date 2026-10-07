final class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
  });

  final String id;
  final String name;
  final String description;

  AchievementDef copyWith({String? id, String? name, String? description}) =>
      AchievementDef(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
      );

  @override
  bool operator ==(Object other) =>
      other is AchievementDef &&
      other.id == id &&
      other.name == name &&
      other.description == description;

  @override
  int get hashCode => Object.hash(id, name, description);

  @override
  String toString() =>
      'AchievementDef(id: $id, name: $name, description: $description)';
}
