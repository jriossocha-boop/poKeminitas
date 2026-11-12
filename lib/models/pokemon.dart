class Pokemon {
  final int id;
  final String name;
  final String imageUrl;
  final String? animatedUrl; 
  final List<String> types;
  final double height; 
  final double weight; 
  final Map<String, int> stats;

  Pokemon({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.animatedUrl,
    required this.types,
    required this.height,
    required this.weight,
    required this.stats,
  });

  String get displayName => name[0].toUpperCase() + name.substring(1);
  String get number => '#${id.toString().padLeft(3, '0')}';
  bool get isAnimated => animatedUrl != null;

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final sprites = json['sprites'];
    final animated =
        sprites['versions']?['generation-v']?['black-white']?['animated'];

    return Pokemon(
      id: json['id'],
      name: json['name'],
      imageUrl: sprites['other']['official-artwork']['front_default'] ??
          sprites['front_default'] ??
          '',
      animatedUrl: animated?['front_default'],
      types: (json['types'] as List)
          .map((t) => t['type']['name'] as String)
          .toList(),
      height: json['height'] / 10,
      weight: json['weight'] / 10,
      stats: {
        for (final s in json['stats'])
          s['stat']['name'] as String: s['base_stat'] as int,
      },
    );
  }
}