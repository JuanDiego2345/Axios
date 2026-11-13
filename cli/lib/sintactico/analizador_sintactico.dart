/// Fase 5: analizador sintáctico del español, descendente recursivo.
///
/// Cada regla de la gramática de docs/bnf.md es una función de [_Parser] con
/// el mismo nombre (`_entrada`, `_clausula`, `_interrogativo`, `_nucleo`,
/// `_complemento`, `_grupoVerbal`, `_sn`). El resultado es el árbol de
/// arbol.dart (fase 6), que no depende de ninguna lengua.
///
/// Recibe los tokens del módulo léxico ya corregidos. Los
/// tokens no traen categoría: el parser la consulta en el vocabulario
/// ([LexicoEspanol]) y en la morfología ([AnalizadorMorfologico]).
library;

import '../lexico/token.dart';
import 'arbol.dart';
import 'lexico_espanol.dart';
import 'morfologia.dart';

/// Error que impide construir el árbol. Lleva una explicación para el
/// usuario (condición 1 de Axios: si no hay traducción, se dice por qué).
class ErrorSintactico implements Exception {
  final String mensaje;

  /// Columna (desde 1) en el texto normalizado.
  final int columna;

  const ErrorSintactico(this.mensaje, this.columna);

  @override
  String toString() => 'Error sintáctico en la columna $columna: $mensaje';
}

/// Lo que devuelve el parser para una pregunta.
class ResultadoSintactico {
  /// El árbol, o null si hubo error.
  final Oracion? arbol;

  /// El error, o null si se construyó el árbol.
  final ErrorSintactico? error;

  /// Decisiones que el parser tomó y conviene mostrar o guardar: sujeto
  /// deducido, verbo ambiguo, falta de concordancia...
  final List<String> advertencias;

  /// Reglas por las que pasó el parser (vacía si no se pidió traza).
  final List<String> traza;

  const ResultadoSintactico({
    required this.arbol,
    required this.error,
    required this.advertencias,
    required this.traza,
  });

  bool get exito => arbol != null;
}

class AnalizadorSintactico {
  final LexicoEspanol lexico;
  final AnalizadorMorfologico morfologia;

  AnalizadorSintactico(this.lexico, this.morfologia);

  /// Construye el parser con el vocabulario y las reglas de [fuente].
  factory AnalizadorSintactico.desde(FuenteLexicoEspanol fuente) =>
      AnalizadorSintactico(
        LexicoEspanol(fuente.palabras()),
        AnalizadorMorfologico.desde(fuente),
      );

  /// Todas las palabras que el parser entiende, incluidas las formas
  /// verbales. Es el vocabulario que necesita el corrector del léxico
  /// (`FaseLexica(analizador.vocabulario)`).
  Iterable<String> get vocabulario =>
      {...lexico.formas, ...morfologia.formasConocidas};

  /// Analiza [tokens] (los de `ResultadoLexico.tokens`).
  ResultadoSintactico analizar(List<Token> tokens, {bool conTraza = false}) {
    final parser = _Parser(this, tokens, conTraza);
    try {
      final arbol = parser._entrada();
      return ResultadoSintactico(
        arbol: arbol,
        error: null,
        advertencias: parser.advertencias,
        traza: parser.traza,
      );
    } on ErrorSintactico catch (e) {
      parser._log('ERROR: ${e.mensaje}');
      return ResultadoSintactico(
        arbol: null,
        error: e,
        advertencias: parser.advertencias,
        traza: parser.traza,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Estructuras internas: lo que devuelve cada regla antes de armar el árbol.
// ---------------------------------------------------------------------------

/// Un sintagma nominal ya leído.
class _SN {
  final Participante participante;

  /// Persona y número que pide al verbo si es el sujeto ("3p").
  final String concordancia;
  final bool esPronombre;
  final bool antesDelVerbo;

  /// Va después de la preposición "a" ("vieron a las criaturas").
  final bool conPreposicion;
  final Token token;

  const _SN({
    required this.participante,
    required this.concordancia,
    required this.esPronombre,
    required this.antesDelVerbo,
    required this.conPreposicion,
    required this.token,
  });
}

/// El verbo ya leído, con todos sus análisis posibles.
class _GrupoVerbal {
  final Token token;

  /// Análisis del verbo conjugado (en "van a llegar", los del auxiliar).
  final List<AnalisisVerbal> analisis;

  /// En "van a llegar", el verbo que se traduce (llegar). null si no es
  /// perífrasis.
  final DatosVerbo? principal;

  bool get perifrasis => principal != null;

  const _GrupoVerbal(this.token, this.analisis, this.principal);
}

class _Interrogativo {
  final EntradaLexica entrada;

  /// En "¿cuántas naves...?", el sustantivo por el que se pregunta.
  final Nominal? sustantivo;
  final Token token;

  const _Interrogativo(this.entrada, this.sustantivo, this.token);
}

class _Nucleo {
  final _SN? antes;
  final bool negada;
  final _GrupoVerbal verbo;
  final List<_SN> despues;

  const _Nucleo(this.antes, this.negada, this.verbo, this.despues);
}

class _Clausula {
  final _Interrogativo? interrogativo;
  final _Nucleo nucleo;

  const _Clausula(this.interrogativo, this.nucleo);
}

// ---------------------------------------------------------------------------
// El parser.
// ---------------------------------------------------------------------------

class _Parser {
  final LexicoEspanol lexico;
  final AnalizadorMorfologico morf;
  final List<Token> t;
  final bool conTraza;

  final List<String> traza = [];
  final List<String> advertencias = [];
  int i = 0;
  int _nivel = 0;

  _Parser(AnalizadorSintactico a, List<Token> tokens, this.conTraza)
      : lexico = a.lexico,
        morf = a.morfologia,
        // Las comas no forman parte de la gramática (docs/bnf.md).
        t = _conFin(tokens.where((x) => x.tipo != TipoToken.coma).toList());

  /// Garantiza que la lista termine en `fin`, aunque quien llame se olvide.
  static List<Token> _conFin(List<Token> tokens) {
    if (tokens.isEmpty || tokens.last.tipo != TipoToken.fin) {
      final pos = tokens.isEmpty ? 0 : tokens.last.posicion + 1;
      tokens.add(Token(tipo: TipoToken.fin, lexema: '', posicion: pos));
    }
    return tokens;
  }

  // ----- utilidades -----

  Token get actual => t[i];
  Token _mirar(int k) => i + k < t.length ? t[i + k] : t.last;
  bool get _enFin => actual.tipo == TipoToken.fin;

  void _log(String linea) {
    if (conTraza) traza.add('${'  ' * _nivel}$linea');
  }

  String _mostrar(Token tok) =>
      tok.tipo == TipoToken.fin ? 'FIN' : '"${tok.lexema}"';

  /// Envuelve una regla para que la traza muestre por dónde pasa el parser.
  T _regla<T>(String nombre, T Function() cuerpo) {
    _log('<$nombre> en ${_mostrar(actual)}');
    _nivel++;
    try {
      return cuerpo();
    } finally {
      _nivel--;
    }
  }

  Token _consumir() {
    final tok = actual;
    if (!_enFin) i++;
    _log('lee ${_mostrar(tok)}');
    return tok;
  }

  bool _esPalabra(Token tok) => tok.tipo == TipoToken.palabra;

  bool _es(Token tok, Categoria c) =>
      _esPalabra(tok) && lexico.es(tok.lexema, c);

  bool _conocida(Token tok) =>
      lexico.buscar(tok.lexema).isNotEmpty || morf.esVerbo(tok.lexema);

  bool _esConjugado(Token tok) =>
      _esPalabra(tok) &&
      morf.analizar(tok.lexema).any((a) => !a.esInfinitivo);

  bool _esInfinitivo(Token tok) =>
      _esPalabra(tok) && morf.esInfinitivo(tok.lexema);

  /// Primeros de `<sn>`: PRONOMBRE | ARTICULO | POSESIVO | NUMERO | SUSTANTIVO.
  bool _empiezaSN(Token tok) =>
      tok.tipo == TipoToken.numero ||
      _es(tok, Categoria.pronombre) ||
      _es(tok, Categoria.articulo) ||
      _es(tok, Categoria.posesivo) ||
      _es(tok, Categoria.sustantivo);

  /// "el"/"tu" se leen como determinante si los sigue un sustantivo o un
  /// número ("tu planeta"); si no, como pronombre ("tú vienes").
  bool _esDeterminanteAqui() =>
      (_es(actual, Categoria.articulo) || _es(actual, Categoria.posesivo)) &&
      (_es(_mirar(1), Categoria.sustantivo) ||
          _mirar(1).tipo == TipoToken.numero);

  void _advertir(String texto) {
    advertencias.add(texto);
    _log('aviso: $texto');
  }

  /// Error para un token que no encaja donde está.
  ErrorSintactico _inesperado(Token tok) {
    switch (tok.tipo) {
      case TipoToken.desconocido:
        return ErrorSintactico(
            'el carácter "${tok.lexema}" no se reconoce', tok.columna);
      case TipoToken.fin:
        return ErrorSintactico(
            'la oración terminó antes de lo esperado', tok.columna);
      case TipoToken.palabra:
        if (!_conocida(tok)) return _noConocida(tok);
        if (morf.esVerbo(tok.lexema)) {
          return ErrorSintactico(
              'sobra el verbo "${tok.lexema}": todavía no se entienden dos '
              'verbos en la misma oración',
              tok.columna);
        }
        return ErrorSintactico(
            'no se esperaba "${tok.lexema}" en esta posición', tok.columna);
      default:
        return ErrorSintactico(
            'no se esperaba "${tok.lexema}" en esta posición', tok.columna);
    }
  }

  /// Error para cuando se esperaba algo concreto.
  ErrorSintactico _esperado(String que, Token tok) {
    if (_esPalabra(tok) && !_conocida(tok)) return _noConocida(tok);
    if (tok.tipo == TipoToken.desconocido) return _inesperado(tok);
    return ErrorSintactico(
        'se esperaba $que y llegó ${_mostrar(tok)}', tok.columna);
  }

  ErrorSintactico _noConocida(Token tok) => ErrorSintactico(
      'la palabra "${tok.lexema}" no está en el vocabulario; no se traduce '
      'para no inventar nada',
      tok.columna);

  // ----- reglas de la gramática (docs/bnf.md) -----

  /// `<entrada> ::= [ "¿" ] <clausula> [ "?" ] [ "." ] FIN`
  Oracion _entrada() => _regla('entrada', () {
        if (_enFin) {
          throw ErrorSintactico('la pregunta está vacía', actual.columna);
        }
        for (final tok in t) {
          if (tok.tipo == TipoToken.desconocido) throw _inesperado(tok);
        }

        var signos = false;
        if (actual.tipo == TipoToken.abreInterrogacion) {
          _consumir();
          signos = true;
        }
        final clausula = _clausula();
        if (actual.tipo == TipoToken.cierraInterrogacion) {
          _consumir();
          signos = true;
        }
        if (actual.tipo == TipoToken.punto) _consumir();
        if (!_enFin) throw _inesperado(actual);

        return _construir(clausula, esPregunta: signos);
      });

  /// `<clausula> ::= <interrogativo> <nucleo> | <nucleo>`
  _Clausula _clausula() => _regla('clausula', () {
        final interrogativo =
            _es(actual, Categoria.interrogativo) ? _interrogativo() : null;
        return _Clausula(interrogativo, _nucleo());
      });

  /// `<interrogativo> ::= INTERROGATIVO_CANTIDAD [ SUSTANTIVO ] | INTERROGATIVO`
  _Interrogativo _interrogativo() => _regla('interrogativo', () {
        final tok = _consumir();
        final entrada = lexico.como(tok.lexema, Categoria.interrogativo)!;
        Nominal? sustantivo;
        if (entrada.rol == RolInterrogativo.cantidad &&
            _es(actual, Categoria.sustantivo)) {
          final s = lexico.como(_consumir().lexema, Categoria.sustantivo)!;
          sustantivo = Nominal(s.concepto!,
              numero: s.numero!, preguntaCantidad: true);
        }
        return _Interrogativo(entrada, sustantivo, tok);
      });

  /// `<nucleo> ::= [ <sn> ] [ NEGACION ] <grupo-verbal>`
  /// `             [ <complemento> [ <complemento> ] ]`
  _Nucleo _nucleo() => _regla('nucleo', () {
        final antes = _empiezaSN(actual) ? _sn(antesDelVerbo: true) : null;
        var negada = false;
        if (_es(actual, Categoria.negacion)) {
          _consumir();
          negada = true;
        }
        final verbo = _grupoVerbal();
        final despues = <_SN>[];
        while (despues.length < 2 &&
            (_empiezaSN(actual) ||
                (_es(actual, Categoria.preposicion) &&
                    _empiezaSN(_mirar(1))))) {
          despues.add(_complemento());
        }
        return _Nucleo(antes, negada, verbo, despues);
      });

  /// `<complemento> ::= [ PREPOSICION ] <sn>`
  _SN _complemento() => _regla('complemento', () {
        var conPreposicion = false;
        if (_es(actual, Categoria.preposicion)) {
          _consumir();
          conPreposicion = true;
        }
        return _sn(antesDelVerbo: false, conPreposicion: conPreposicion);
      });

  /// `<grupo-verbal> ::= AUXILIAR_FUTURO ENLACE_FUTURO INFINITIVO`
  /// `                 | VERBO_CONJUGADO`
  _GrupoVerbal _grupoVerbal() => _regla('grupo-verbal', () {
        final tok = actual;
        final enlace = morf.reglas.enlaceFuturo;

        if (_esPalabra(tok) &&
            morf.esAuxiliarFuturo(tok.lexema) &&
            _mirar(1).lexema == enlace &&
            _esInfinitivo(_mirar(2))) {
          final aux = morf.comoAuxiliarFuturo(_consumir().lexema)!;
          _consumir(); // la "a"
          final inf = _consumir();
          final principal = morf
              .analizar(inf.lexema)
              .firstWhere((a) => a.esInfinitivo)
              .verbo;
          _log('futuro con "ir a": ${tok.lexema} a ${inf.lexema}');
          return _GrupoVerbal(tok, [aux], principal);
        }

        if (_esConjugado(tok)) {
          _consumir();
          final analisis =
              morf.analizar(tok.lexema).where((a) => !a.esInfinitivo).toList();
          _log('análisis de "${tok.lexema}": ${analisis.join(' | ')}');
          return _GrupoVerbal(tok, analisis, null);
        }

        if (_esInfinitivo(tok)) {
          throw ErrorSintactico(
              '"${tok.lexema}" es un infinitivo; falta el verbo conjugado',
              tok.columna);
        }
        throw _esperado('un verbo', tok);
      });

  /// `<sn> ::= PRONOMBRE | [ <determinante> ] [ NUMERO ] SUSTANTIVO`
  /// `<determinante> ::= ARTICULO | POSESIVO`
  _SN _sn({required bool antesDelVerbo, bool conPreposicion = false}) =>
      _regla('sn', () {
        final inicio = actual;

        if (_es(actual, Categoria.pronombre) && !_esDeterminanteAqui()) {
          final p = lexico.como(_consumir().lexema, Categoria.pronombre)!;
          return _SN(
            participante: Pronominal(p.persona!, p.numero!),
            concordancia: p.concordancia!,
            esPronombre: true,
            antesDelVerbo: antesDelVerbo,
            conPreposicion: conPreposicion,
            token: inicio,
          );
        }

        Poseedor? poseedor;
        if (_es(actual, Categoria.articulo) ||
            _es(actual, Categoria.posesivo)) {
          final det = _consumir();
          final pos = lexico.como(det.lexema, Categoria.posesivo);
          if (pos != null) poseedor = Poseedor(pos.persona!, pos.numero!);
        }

        int? cantidad;
        if (actual.tipo == TipoToken.numero) cantidad = _consumir().valor;

        if (!_es(actual, Categoria.sustantivo)) {
          throw _esperado('un sustantivo', actual);
        }
        final s = lexico.como(_consumir().lexema, Categoria.sustantivo)!;

        var numero = s.numero!;
        if (cantidad != null) {
          final pide = cantidad == 1 ? Numero.singular : Numero.plural;
          if (pide != numero) {
            _advertir('"$cantidad ${s.forma}": se toma el número de la '
                'cantidad (${pide.name})');
            numero = pide;
          }
        }
        return _SN(
          participante: Nominal(s.concepto!,
              numero: numero, cantidad: cantidad, poseedor: poseedor),
          concordancia: numero == Numero.singular ? '3s' : '3p',
          esPronombre: false,
          antesDelVerbo: antesDelVerbo,
          conPreposicion: conPreposicion,
          token: inicio,
        );
      });

  // ----- del análisis al árbol (reglas de docs/bnf.md, "funciones") -----

  Oracion _construir(_Clausula c, {required bool esPregunta}) {
    final q = c.interrogativo;
    final n = c.nucleo;
    final modo = q != null
        ? Modo.preguntaAbierta
        : (esPregunta ? Modo.preguntaSiNo : Modo.afirmacion);

    // Análisis utilizables: el verbo que se traduce debe tener concepto.
    final candidatos = n.verbo.perifrasis
        ? n.verbo.analisis
        : n.verbo.analisis.where((a) => a.verbo.concepto != null).toList();
    final principal = n.verbo.principal;
    if (candidatos.isEmpty ||
        (principal != null && principal.concepto == null)) {
      final lema = principal?.lema ?? n.verbo.analisis.first.lema;
      throw ErrorSintactico(
          'el verbo "$lema" no tiene traducción en el manual', n.verbo.token.columna);
    }
    final transitivo =
        principal?.transitivo ?? candidatos.first.verbo.transitivo;

    // 1-4. Sujeto y objeto a partir de los grupos escritos.
    _SN? sujeto;
    _SN? objeto;
    void ubicar(_SN sn) {
      final bool vaDeSujeto;
      if (sn.esPronombre) {
        vaDeSujeto = sujeto == null;
      } else if (sn.conPreposicion) {
        vaDeSujeto = false;
      } else if (sn.antesDelVerbo) {
        vaDeSujeto = sujeto == null;
      } else {
        vaDeSujeto = !(transitivo && objeto == null) && sujeto == null;
      }
      if (vaDeSujeto) {
        sujeto = sn;
      } else if (objeto == null) {
        objeto = sn;
      } else {
        throw ErrorSintactico(
            'sobra "${sn.token.lexema}": la oración ya tiene sujeto y objeto',
            sn.token.columna);
      }
    }

    if (n.antes != null) ubicar(n.antes!);
    n.despues.forEach(ubicar);

    Participante? sujetoP = sujeto?.participante;
    Participante? objetoP = objeto?.participante;
    var concordancia = sujeto?.concordancia;

    // 5. La palabra interrogativa ocupa su hueco.
    RolInterrogativo? rol;
    if (q != null) {
      final concepto = q.entrada.concepto!;
      final rolDato = q.entrada.rol!;
      final Participante hueco = q.sustantivo ?? Incognita(concepto);
      var alSujeto = false;
      switch (rolDato) {
        case RolInterrogativo.tiempo:
        case RolInterrogativo.lugar:
          // cuándo / dónde no ocupan ni sujeto ni objeto.
          rol = rolDato;
        case RolInterrogativo.sujeto:
          alSujeto = sujetoP == null;
        case RolInterrogativo.objeto:
          alSujeto = !(transitivo && objetoP == null) && sujetoP == null;
        case RolInterrogativo.cantidad:
          alSujeto = !transitivo && sujetoP == null;
      }
      if (rol == null) {
        final esCantidad = rolDato == RolInterrogativo.cantidad;
        if (alSujeto) {
          sujetoP = hueco;
          rol = esCantidad ? RolInterrogativo.cantidad : RolInterrogativo.sujeto;
          final s = q.sustantivo;
          concordancia = s != null
              ? (s.numero == Numero.singular ? '3s' : '3p')
              : q.entrada.concordancia;
        } else if (objetoP == null) {
          objetoP = hueco;
          rol = esCantidad ? RolInterrogativo.cantidad : RolInterrogativo.objeto;
        } else {
          throw ErrorSintactico(
              '"${q.token.lexema}" no tiene lugar: la oración ya tiene '
              'sujeto y objeto',
              q.token.columna);
        }
      }
      _log('interrogativo $concepto -> $rol');
    }

    // 7. Elegir el análisis del verbo que concuerda con el sujeto.
    final AnalisisVerbal elegido;
    if (concordancia != null) {
      final conc = concordancia;
      final coinciden =
          candidatos.where((a) => a.personaVerbo == conc).toList();
      if (coinciden.isEmpty) {
        elegido = candidatos.first;
        _advertir('"${n.verbo.token.lexema}" no concuerda con el sujeto '
            '(se esperaba $conc); se mantiene el sujeto escrito');
      } else {
        elegido = coinciden.first;
        _avisarAmbiguedad(n.verbo.token.lexema, coinciden, elegido);
      }
    } else {
      elegido = candidatos.first;
      _avisarAmbiguedad(n.verbo.token.lexema, candidatos, elegido);
    }

    // 6. Sujeto omitido: se deduce de la persona del verbo.
    final Participante sujetoFinal;
    if (sujetoP != null) {
      sujetoFinal = sujetoP;
    } else {
      final tabla = modo == Modo.afirmacion
          ? morf.reglas.sujetoOmitidoAfirmacion
          : morf.reglas.sujetoOmitidoPregunta;
      final codigoVerbo = elegido.personaVerbo!;
      final codigo = tabla[codigoVerbo] ?? codigoVerbo;
      final r = rasgosDesdeCodigo(codigo);
      sujetoFinal = Pronominal(r.persona, r.numero, inferido: true);
      _advertir('sujeto omitido: se dedujo $codigo a partir del verbo '
          '"${n.verbo.token.lexema}" ($codigoVerbo)');
    }

    final tiempo = n.verbo.perifrasis ? Tiempo.futuro : elegido.tiempo!;
    final concepto = (principal ?? elegido.verbo).concepto!;

    final oracion = Oracion(
      modo: modo,
      interrogativo: q?.entrada.concepto,
      rolInterrogativo: rol,
      negada: n.negada,
      tiempo: tiempo,
      verbo: concepto,
      sujeto: sujetoFinal,
      objeto: objetoP,
    );
    _log('árbol construido:');
    for (final linea in oracion.dibujar().split('\n')) {
      _log('  $linea');
    }
    return oracion;
  }

  /// Avisa si [opciones] deja dudas que la prioridad de los datos resolvió.
  void _avisarAmbiguedad(
      String forma, List<AnalisisVerbal> opciones, AnalisisVerbal elegido) {
    final distintas = {
      for (final o in opciones) '${o.lema} ${o.tiempo?.name} ${o.personaVerbo}'
    };
    if (distintas.length > 1) {
      _advertir('"$forma" puede ser: ${distintas.join(' / ')}; '
          'se eligió ${elegido.lema} ${elegido.tiempo?.name} '
          '${elegido.personaVerbo}');
    }
  }
}
