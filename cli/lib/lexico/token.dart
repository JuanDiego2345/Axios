/// Tokens que produce el analizador léxico del español.
///
/// Este archivo es la INTERFAZ entre el módulo léxico (integrante 1) y el
/// parser (integrante 2). Ver docs/interfaces-lexico.md.
library;

/// Tipos de token que reconoce el autómata.
///
/// El léxico NO clasifica las palabras en pronombre, verbo, sustantivo, etc.:
/// eso requiere el vocabulario de la base de datos y lo hace el parser.
/// Aquí solo se distingue la forma del lexema.
enum TipoToken {
  /// Secuencia de letras: `cuando`, `naves`, `llegaran`.
  palabra,

  /// Secuencia de dígitos. Las cantidades en letras ya llegan convertidas
  /// por el normalizador ("dos mil quince" -> `2015`).
  numero,

  /// Signo `¿`.
  abreInterrogacion,

  /// Signo `?`.
  cierraInterrogacion,

  /// Signo `,`.
  coma,

  /// Signo `.`.
  punto,

  /// Carácter que el autómata no reconoce (`@`, `#`, `ʔ`...). No detiene el
  /// análisis: se reporta para que el sistema explique por qué no traduce.
  desconocido,

  /// Marca de fin de entrada. Siempre es el último token de la lista.
  fin,
}

/// Un token con su posición en el texto normalizado.
class Token {
  /// Tipo del token.
  final TipoToken tipo;

  /// Texto del token. Si el corrector lo cambió, aquí va la forma corregida.
  final String lexema;

  /// Índice (desde 0) del primer carácter del token en el texto normalizado.
  final int posicion;

  /// Valor numérico. Solo tiene valor cuando [tipo] es [TipoToken.numero].
  final int? valor;

  /// Lexema antes de la corrección ortográfica. Es `null` si no se corrigió.
  final String? original;

  const Token({
    required this.tipo,
    required this.lexema,
    required this.posicion,
    this.valor,
    this.original,
  });

  /// Columna (desde 1) para mostrar en mensajes de error.
  int get columna => posicion + 1;

  /// Indica si el corrector cambió este token.
  bool get fueCorregido => original != null;

  /// Copia del token con el lexema corregido, guardando el lexema original.
  Token corregido(String nuevoLexema) => Token(
        tipo: tipo,
        lexema: nuevoLexema,
        posicion: posicion,
        valor: valor,
        original: lexema,
      );

  /// Representación como mapa, útil para guardar en la BD o para la traza.
  Map<String, Object?> toMap() => {
        'tipo': tipo.name,
        'lexema': lexema,
        'posicion': posicion,
        'columna': columna,
        if (valor != null) 'valor': valor,
        if (original != null) 'original': original,
      };

  @override
  String toString() {
    final extra = original != null ? ' (era "$original")' : '';
    return '${tipo.name}("$lexema")@$columna$extra';
  }
}
