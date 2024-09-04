class Subject {
  final int id;
  final String sex;
  final String birthday;
  final double weight;
  final double height;
  String notes;

  //constructor
  Subject({
    required this.id,
    required this.sex,
    required this.birthday,
    required this.weight,
    required this.height,
    required this.notes,
  });

  //convert a Subject into a Map to be stored in the database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sex': sex,
      'birthday': birthday,
      'weight': weight,
      'height': height,
      'notes': notes,
    };
  }

  //override toString to make it easier to see the Subject
  @override
  String toString() {
    return 'Subject{id: $id, sex: $sex, DOB: $birthday, weight: $weight, height: $height, notes: $notes}';
  }
}
