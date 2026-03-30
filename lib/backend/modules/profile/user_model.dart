
class UserModel {
  final String uid;
  final String name;
  final int age;
  final List<String> conditions;

  UserModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.conditions,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data['name'] ?? '',
      age: data['age'] ?? 0,
      conditions: List<String>.from(data['conditions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'conditions': conditions,
    };
  }
}
