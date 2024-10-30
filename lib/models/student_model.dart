class Student {
  final int? id;
  final String name;

  Student({this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name};
  }

  static Student fromMap(Map<String, dynamic> map) {
    return Student(id: map['id'], name: map['name']);
  }
}