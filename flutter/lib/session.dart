import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _secure = FlutterSecureStorage();
final _prefs = SharedPreferencesAsync();

// Token demonstrativ, pastrat separat de SQLite si preferinte.
final tokenProvider = FutureProvider<String>((ref) async {
  final saved = await _secure.read(key: 'field.token');

  if (saved != null) return saved;

  final token = 'placeholder-${const Uuid().v4()}';
  await _secure.write(key: 'field.token', value: token);

  return token;
});

Future<String> lastTab() async =>
    await _prefs.getString('field.lastTab') ?? '/map';

Future<void> saveLastTab(String path) =>
    _prefs.setString('field.lastTab', path);

// Tipul conexiunii disponibile; nu garanteaza accesul la internet.
final connectivityProvider =
    StreamProvider<List<ConnectivityResult>>((ref) async* {
  final connectivity = Connectivity();

  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});