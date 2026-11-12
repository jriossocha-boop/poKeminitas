import 'package:flutter/material.dart';
import '../models/pokemon.dart';
import '../services/pokemon_service.dart';

class SmashPassScreen extends StatefulWidget {
  const SmashPassScreen({super.key});

  @override
  State<SmashPassScreen> createState() => _SmashPassScreenState();
}

class _SmashPassScreenState extends State<SmashPassScreen> {
  static const _totalPokemon = 1025;
  static const _smashColor = Color(0xFFA8E6A3); // verde pastel
  static const _passColor = Color(0xFFF5A3A3); // rojo pastel

  final _service = PokemonService();

  int _currentId = 1;
  int _smashCount = 0;
  int _passCount = 0;

  Pokemon? _pokemon;
  bool _loading = false;
  bool _finished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPokemon();
  }

  Future<void> _loadPokemon() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    Pokemon? result;
    String? error;
    try {
      result = await _service.fetchPokemon(_currentId.toString());
    } on PokemonException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'ERROR DE CONEXIÓN';
    }

    if (!mounted) return;
    setState(() {
      _pokemon = result;
      _error = error;
      _loading = false;
    });
  }

  void _vote({required bool smash}) {
    if (_loading || _pokemon == null) return;

    setState(() {
      if (smash) {
        _smashCount++;
      } else {
        _passCount++;
      }
    });

    if (_currentId >= _totalPokemon) {
      setState(() => _finished = true);
      return;
    }

    _currentId++;
    _loadPokemon();
  }

  void _restart() {
    setState(() {
      _currentId = 1;
      _smashCount = 0;
      _passCount = 0;
      _finished = false;
      _pokemon = null;
    });
    _loadPokemon();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Smash or Pass ¿A Quién le Darias ?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _finished ? _buildFinished() : _buildGame(),
          ),
        ),
      ),
    );
  }

  Widget _buildGame() {
    final canVote = !_loading && _pokemon != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPokemonImage(),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _VoteColumn(
                label: 'Smash',
                color: _smashColor,
                count: _smashCount,
                onPressed: canVote ? () => _vote(smash: true) : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _VoteColumn(
                label: 'Pass',
                color: _passColor,
                count: _passCount,
                onPressed: canVote ? () => _vote(smash: false) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPokemonImage() {
    const double size = 280;

    if (_error != null) {
      return SizedBox(
        height: size + 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadPokemon,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_pokemon == null) {
      return const SizedBox(
        height: size + 50,
        child: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }

    final p = _pokemon!;
    return Column(
      children: [
        Text(
          p.number,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        Text(
          p.displayName,
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Image.network(
            p.imageUrl,
            key: ValueKey(p.id),
            height: size,
            width: size,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: size,
                    width: size,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.redAccent),
                    ),
                  ),
            errorBuilder: (_, __, ___) => const SizedBox(
              height: size,
              width: size,
              child: Icon(Icons.catching_pokemon, size: 100, color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFinished() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.emoji_events, size: 90, color: Colors.amber),
        const SizedBox(height: 12),
        const Text(
          '¡Terminaste la PokéMitas!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        Text('Le Dabas a: $_smashCount pokemitas UMM',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Text('Smash: $_smashCount', style: const TextStyle(fontSize: 20)),
        Text('Pass: $_passCount', style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _restart,
          icon: const Icon(Icons.replay),
          label: const Text('Empezar de nuevo'),
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
        ),
      ],
    );
  }
}

class _VoteColumn extends StatelessWidget {
  final String label;
  final Color color;
  final int count;
  final VoidCallback? onPressed;

  const _VoteColumn({
    required this.label,
    required this.color,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.black87,
              disabledBackgroundColor: color.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$count',
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}