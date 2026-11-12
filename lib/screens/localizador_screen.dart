import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const Color kRed = Color(0xFFFF5555);
const Color kBg = Color(0xFFF6F6F8);
const LatLng kFallback = LatLng(40.4153, -3.6845); // Parque del Retiro, Madrid
const double kRadioMetros = 1000;

/// Modelo de un Pokémon cercano.
class NearbyPokemon {
  final int id;
  final String name;
  final String? sprite;
  final LatLng position;
  final double distance; // metros

  NearbyPokemon({
    required this.id,
    required this.name,
    required this.sprite,
    required this.position,
    required this.distance,
  });

  String get displayName =>
      name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);
}

class LocalizadorScreen extends StatefulWidget {
  const LocalizadorScreen({super.key});

  @override
  State<LocalizadorScreen> createState() => _LocalizadorScreenState();
}

class _LocalizadorScreenState extends State<LocalizadorScreen> {
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  final Random _random = Random();

  bool _loading = true;
  bool _error = false;
  bool _usingFallback = false;

  LatLng _user = kFallback;
  String _place = 'Buscando ubicación...';
  String _weather = '--';
  List<NearbyPokemon> _pokemons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // Carga de datos
  // ---------------------------------------------------------------------------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final pos = await _getPosition();
      final results = await Future.wait([
        _fetchPlace(pos),
        _fetchWeather(pos),
        _generatePokemons(pos),
      ]);

      if (!mounted) return;
      setState(() {
        _user = pos;
        _place = results[0] as String;
        _weather = results[1] as String;
        _pokemons = results[2] as List<NearbyPokemon>;
        _loading = false;
      });
      _mapController.move(_user, 15.3);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<LatLng> _getPosition() async {
    _usingFallback = false;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _usingFallback = true;
        return kFallback;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _usingFallback = true;
        return kFallback;
      }

      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      _usingFallback = true;
      return kFallback;
    }
  }

  Future<String> _fetchPlace(LatLng p) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=16&lat=${p.latitude}&lon=${p.longitude}');
      final res = await http
          .get(uri, headers: {'User-Agent': 'pokeminitas-app/1.0'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return 'Ubicación actual';
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final name = (json['name'] as String?) ?? '';
      if (name.isNotEmpty) {
        final city = (json['address']?['city'] ??
                json['address']?['town'] ??
                json['address']?['village'] ??
                '') as String;
        return city.isNotEmpty && city != name ? '$name, $city' : name;
      }
      final display = (json['display_name'] as String?) ?? '';
      if (display.isEmpty) return 'Ubicación actual';
      return display.split(',').take(2).map((e) => e.trim()).join(', ');
    } catch (_) {
      return 'Ubicación actual';
    }
  }

  Future<String> _fetchWeather(LatLng p) async {
    try {
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${p.latitude}&longitude=${p.longitude}&current_weather=true');
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return '--';
      final cw = (jsonDecode(res.body) as Map<String, dynamic>)['current_weather']
          as Map<String, dynamic>;
      final temp = (cw['temperature'] as num).round();
      final code = (cw['weathercode'] as num).toInt();
      return '${_weatherLabel(code)} · $temp °C';
    } catch (_) {
      return '--';
    }
  }

  String _weatherLabel(int code) {
    if (code == 0) return 'Soleado';
    if (code <= 3) return 'Nublado';
    if (code == 45 || code == 48) return 'Niebla';
    if (code >= 51 && code <= 67) return 'Lluvia';
    if (code >= 71 && code <= 77) return 'Nieve';
    if (code >= 80 && code <= 82) return 'Chubascos';
    if (code >= 95) return 'Tormenta';
    return 'Variable';
  }

  /// Genera entre 3 y 5 Pokémon aleatorios alrededor del usuario.
  Future<List<NearbyPokemon>> _generatePokemons(LatLng center) async {
    final count = 3 + _random.nextInt(3);
    final ids = <int>{};
    while (ids.length < count) {
      ids.add(1 + _random.nextInt(151));
    }

    final list = await Future.wait(ids.map((id) async {
      final res = await http
          .get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('PokeAPI error');
      final json = jsonDecode(res.body) as Map<String, dynamic>;

      // Posición aleatoria dentro del radio
      final dist = 60 + _random.nextDouble() * (kRadioMetros - 120);
      final angle = _random.nextDouble() * 2 * pi;
      final dLat = (dist * cos(angle)) / 111320;
      final dLng =
          (dist * sin(angle)) / (111320 * cos(center.latitude * pi / 180));
      final pos = LatLng(center.latitude + dLat, center.longitude + dLng);

      return NearbyPokemon(
        id: id,
        name: json['name'] as String,
        sprite: json['sprites']?['front_default'] as String?,
        position: pos,
        distance: _distance(center, pos),
      );
    }));

    list.sort((a, b) => a.distance.compareTo(b.distance));
    return list;
  }

  // ---------------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------------
  String _fmtDistance(double m) =>
      m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '${m.round()} m';

  String _timeLabel() {
    final now = DateTime.now();
    final h = now.hour;
    final part = h < 6
        ? 'Madrugada'
        : h < 12
            ? 'Mañana'
            : h < 19
                ? 'Tarde'
                : 'Noche';
    final mm = now.minute.toString().padLeft(2, '0');
    return '${h.toString().padLeft(2, '0')}:$mm · $part';
  }

  void _focusPokemon(NearbyPokemon p) {
    _mapController.move(p.position, 16.2);
    _showPokemonSheet(p);
  }

  void _showPokemonSheet(NearbyPokemon p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (p.sprite != null)
              Image.network(p.sprite!, width: 120, height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.catching_pokemon, size: 80, color: kRed))
            else
              const Icon(Icons.catching_pokemon, size: 80, color: kRed),
            Text(
              '#${p.id.toString().padLeft(3, '0')}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            Text(
              p.displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.place, color: kRed, size: 18),
                const SizedBox(width: 4),
                Text('A ${_fmtDistance(p.distance)} de ti',
                    style: const TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kRed,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Localizador Pokémon',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: _error ? _buildError() : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No pude conectarme. Revisa tu internet 📡',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tu ubicación',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            _usingFallback
                ? '$_place · radio de 1 km (ubicación de ejemplo)'
                : '$_place · radio de 1 km',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(Icons.wb_sunny_outlined, _weather),
              _chip(Icons.park_outlined, _place.split(',').first),
              _chip(Icons.access_time, _timeLabel()),
            ],
          ),
          const SizedBox(height: 14),
          _buildMap(),
          const SizedBox(height: 14),
          _buildNearbyList(),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 2,
              ),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.catching_pokemon),
              label: const Text('Buscar cerca de mí',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Pokémon y apariciones de ejemplo · ubicación en tiempo real',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1B5FAA)),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1B5FAA))),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _user,
                initialZoom: 15.3,
                minZoom: 12,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.flutter_application_1',
                ),
                CircleLayer(circles: [
                  CircleMarker(
                    point: _user,
                    radius: kRadioMetros,
                    useRadiusInMeter: true,
                    color: const Color(0x142F80ED),
                    borderColor: const Color(0x552F80ED),
                    borderStrokeWidth: 1.5,
                  ),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: _user,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F80ED),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  for (int i = 0; i < _pokemons.length; i++)
                    Marker(
                      point: _pokemons[i].position,
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => _focusPokemon(_pokemons[i]),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kRed,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                ]),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _mapController.move(_user, 15.3),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    child: Text('Centrar',
                        style: TextStyle(
                            color: Color(0xFF1B5FAA),
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ),
              ),
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  color: Colors.white70,
                  child: const Center(
                    child: CircularProgressIndicator(color: kRed),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyList() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pokémon más cercanos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          if (_pokemons.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay Pokémon cerca. ¡Intenta de nuevo!'),
            ),
          for (int i = 0; i < _pokemons.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _focusPokemon(_pokemons[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: kRed,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    if (_pokemons[i].sprite != null)
                      Image.network(_pokemons[i].sprite!,
                          width: 32,
                          height: 32,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(width: 32, height: 32)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_pokemons[i].displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(_fmtDistance(_pokemons[i].distance),
                        style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
