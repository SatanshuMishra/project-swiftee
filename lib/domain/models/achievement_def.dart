final class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.name,
    required this.description,
    required this.catFile,
  });

  final String id;
  final String name;
  final String description;
  final String catFile;

  AchievementDef copyWith({
    String? id,
    String? name,
    String? description,
    String? catFile,
  }) => AchievementDef(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    catFile: catFile ?? this.catFile,
  );

  @override
  bool operator ==(Object other) =>
      other is AchievementDef &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.catFile == catFile;

  @override
  int get hashCode => Object.hash(id, name, description, catFile);

  @override
  String toString() =>
      'AchievementDef(id: $id, name: $name, description: $description, '
      'catFile: $catFile)';
}
