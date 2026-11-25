class Godown {
  final int id;
  final String name;

  Godown({
    required this.id,
    required this.name,
  });

  factory Godown.fromJson(Map<String, dynamic> json) {
    return Godown(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name']?.toString() ?? '',
    );
  }
}
