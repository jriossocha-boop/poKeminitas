import 'dart:math';
import 'package:flutter/material.dart';
import '../models/pokemon.dart';
import '../services/pokemon_service.dart';
import '../widgets/pokemon_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _totalPokemon = 1025; 

  final _controller = TextEditingController();
  final _service = PokemonService();
  final _random = Random();

  Pokemon? _pokemon;
  bool _loading = false;
  String? _error;

  Future<void> _loadPokemon(String query) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    Pokemon? result;
    String? error;
    try {
      result = await _service.fetchPokemon(query);
    } on PokemonException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'No pude conectarme. Revisa tu internet 📡';
    }

    if (!mounted) return;
    setState(() {
      _pokemon = result;
      _error = error;
      _loading = false;
      if (result != null) _controller.text = result.name;
    });
  }

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    _loadPokemon(query);
  }

  void _surprise() {
    final id = _random.nextInt(_totalPokemon) + 1;
    _loadPokemon(id.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PokéMinitas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: 'Busca tu primer Pokemonda',
                  
                  filled: true,
                  fillColor: Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Colors.redAccent,
                      width: 2,
                      )
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _loading ? null : _search,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(child: _buildContent()),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _surprise,
                  label: const Text(
                    'Sorpréndeme',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.catching_pokemon),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: CircularProgressIndicator(color: Colors.redAccent),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }
    if (_pokemon != null) {
      return PokemonCard(pokemon: _pokemon!);
    }
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.catching_pokemon, size: 100, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Busca un Pokémon o deja que el destino decida',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}