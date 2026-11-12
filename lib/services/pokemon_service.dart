import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pokemon.dart';

class PokemonException implements Exception {
  final String message;
  PokemonException(this.message);
}

class PokemonService {
  static const _baseUrl = 'https://pokeapi.co/api/v2/pokemon';

  Future<Pokemon> fetchPokemon(String query) async {
    final uri = Uri.parse('$_baseUrl/${query.trim().toLowerCase()}');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return Pokemon.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 404) {
      throw PokemonException('No se encontro ningun pokemon "$query"');
    } else {
      throw PokemonException('Error del servidor (${response.statusCode})');
    }
  }
}