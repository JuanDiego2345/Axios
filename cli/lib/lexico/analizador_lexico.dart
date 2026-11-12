/// Fase 2: analizador léxico del español con un AFD escrito a mano.
///
/// No usa expresiones regulares: cada carácter se clasifica con
/// [AnalizadorLexico.clasificar] y el estado siguiente sale de la tabla de
/// transiciones [AnalizadorLexico.tabla]. Se aplica la regla del lexema más
/// largo: se avanza mientras haya transición y, al no haberla, el estado en
/// que se quedó el autómata decide el tipo del token.
library;

import 'token.dart';

/// Estados del autómata. Todos menos [inicio] son de aceptación.
enum Estado {
  inicio,
  palabra,
  numero,
  abreInterrogacion,
  cierraInterrogacion,
  coma,
  punto,
  error,
}

/// Clases de caracteres (el alfabeto del autómata).
enum ClaseCaracter {
  letra,
  digito,
  espacio,
  abreInterrogacion,
  cierraInterrogacion,
  coma,
  punto,
  otro,
}

class AnalizadorLexico {
  const AnalizadorLexico();

  /// Función de transición δ(estado, clase) -> estado.
  /// Si una pareja no aparece, no hay transición y el token termina.
  static const Map<Estado, Map<ClaseCaracter, Estado>> tabla = {
    Estado.inicio: {
      ClaseCaracter.letra: Estado.palabra,
      ClaseCaracter.digito: Estado.numero,
      ClaseCaracter.abreInterrogacion: Estado.abreInterrogacion,
      ClaseCaracter.cierraInterrogacion: Estado.cierraInterrogacion,
      ClaseCaracter.coma: Estado.coma,
      ClaseCaracter.punto: Estado.punto,
      ClaseCaracter.otro: Estado.error,
    },
    Estado.palabra: {ClaseCaracter.letra: Estado.palabra},
    Estado.numero: {ClaseCaracter.digito: Estado.numero},
    Estado.abreInterrogacion: {},
    Estado.cierraInterrogacion: {},
    Estado.coma: {},
    Estado.punto: {},
    Estado.error: {},
  };

  /// Estados de aceptación y el tipo de token que producen.
  static const Map<Estado, TipoToken> aceptacion = {
    Estado.palabra: TipoToken.palabra,
    Estado.numero: TipoToken.numero,
    Estado.abreInterrogacion: TipoToken.abreInterrogacion,
    Estado.cierraInterrogacion: TipoToken.cierraInterrogacion,
    Estado.coma: TipoToken.coma,
    Estado.punto: TipoToken.punto,
    Estado.error: TipoToken.desconocido,
  };

  /// Letras fuera de a-z que se aceptan (por si el texto no viene
  /// normalizado).
  static const String _letrasExtra = 'ñÑáéíóúüÁÉÍÓÚÜ';

  /// Clasifica un carácter en su clase del alfabeto.
  static ClaseCaracter clasificar(String c) {
    final u = c.codeUnitAt(0);
    if ((u >= 0x61 && u <= 0x7A) || (u >= 0x41 && u <= 0x5A)) {
      return ClaseCaracter.letra; // a-z, A-Z
    }
    if (_letrasExtra.contains(c)) return ClaseCaracter.letra;
    if (u >= 0x30 && u <= 0x39) return ClaseCaracter.digito; // 0-9
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      return ClaseCaracter.espacio;
    }
    if (c == '¿') return ClaseCaracter.abreInterrogacion;
    if (c == '?') return ClaseCaracter.cierraInterrogacion;
    if (c == ',') return ClaseCaracter.coma;
    if (c == '.') return ClaseCaracter.punto;
    return ClaseCaracter.otro;
  }

  /// Recorre [texto] y devuelve sus tokens, terminando siempre con
  /// [TipoToken.fin]. Si se pasa [traza], se agrega una línea por cada
  /// transición (sirve para el modo traza del CLI).
  List<Token> analizar(String texto, {List<String>? traza}) {
    final tokens = <Token>[];
    var i = 0;

    while (i < texto.length) {
      // Los espacios separan lexemas y no producen tokens.
      if (clasificar(texto[i]) == ClaseCaracter.espacio) {
        i++;
        continue;
      }

      final inicio = i;
      var estado = Estado.inicio;
      while (i < texto.length) {
        final clase = clasificar(texto[i]);
        final siguiente = tabla[estado]![clase];
        if (siguiente == null) break;
        traza?.add('${estado.name} --"${texto[i]}" (${clase.name})--> '
            '${siguiente.name}');
        estado = siguiente;
        i++;
      }
      // Desde `inicio` toda clase distinta de espacio tiene transición, así
      // que siempre se consumió al menos un carácter.

      final lexema = texto.substring(inicio, i);
      final tipo = aceptacion[estado]!;
      traza?.add('  acepta ${tipo.name}("$lexema") en columna ${inicio + 1}');
      tokens.add(Token(
        tipo: tipo,
        lexema: lexema,
        posicion: inicio,
        valor: tipo == TipoToken.numero ? int.tryParse(lexema) : null,
      ));
    }

    tokens.add(Token(tipo: TipoToken.fin, lexema: '', posicion: texto.length));
    return tokens;
  }
}
