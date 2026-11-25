class UnitModel {
  final int id;
  final String category;
  final String description;
  final String code;
  final String color;
  final String? hsn;
  final String? goodsDesc;

  UnitModel({
    required this.id,
    required this.category,
    required this.description,
    required this.code,
    this.color = 'slate',
    this.hsn,
    this.goodsDesc,
  });

  factory UnitModel.fromJson(Map<String, dynamic> json) {
    return UnitModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      category: json['category']?.toString() ?? 'Cases',
      description: json['description']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      color: json['color']?.toString() ?? 'slate',
      hsn: json['hsn']?.toString(),
      goodsDesc: json['goodsDesc']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'description': description,
    'code': code,
    'color': color,
    'hsn': hsn,
    'goodsDesc': goodsDesc,
  };
}
