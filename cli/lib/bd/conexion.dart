import 'package:sqlite3/sqlite3.dart';
import 'esquema.dart';

/// Abre la BD y crea las tablas si no existen.
/// Usa ':memory:' para pruebas o una ruta como 'datos/axios.db'.
Database abrirBd(String ruta) {
  final db = sqlite3.open(ruta);
  db.execute(esquemaSql);
  return db;
}