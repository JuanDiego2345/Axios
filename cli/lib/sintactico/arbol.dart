/// Representación intermedia (fase 6): un árbol que describe la pregunta
/// sin depender de ninguna lengua.
///
/// Este archivo es la INTERFAZ entre el parser y los generadores de
/// Kethari y Ozh. Ver
/// docs/interfaces-sintactico.md.
///
/// Reglas del árbol:
/// - No guarda palabras del español sino CONCEPTOS (`VENIR`, `NAVE`,
///   `CUANDO`). Los conceptos salen de la base de datos y son la llave para
///   buscar la palabra en Kethari y en Ozh.
/// - Las personas y los números gramaticales van como rasgos
///   ([Persona], [Numero]), no como pronombres escritos.
library;

/// Qué clase de oración es.
enum Modo {
  /// "Queremos paz."
  afirmacion,

  /// "¿Ustedes quieren paz?"
  preguntaSiNo,

  /// "¿Cuándo llegan?" (lleva palabra interrogativa).
  preguntaAbierta,
}

/// Tiempo del verbo. "Van a llegar" llega como [futuro].
enum Tiempo { presente, pasado, futuro }

/// Persona gramatical de quien hace la acción o de quien posee algo.
///
/// Es la persona del SIGNIFICADO, no la de la conjugación: "ustedes" es
/// [segunda] aunque el verbo vaya en tercera ("ustedes llegan").
enum Persona { primera, segunda, tercera }

/// Número gramatical.
enum Numero { singular, plural }

/// Papel que cumple la palabra interrogativa dentro de la oración.
enum RolInterrogativo {
  /// "¿Quién envió el mensaje?"
  sujeto,

  /// "¿Qué quieren?"
  objeto,

  /// "¿Cuándo llegan?"
  tiempo,

  /// "¿Dónde están?"
  lugar,

  /// "¿Cuántas naves llegaron?" (la pregunta es por la cantidad).
  cantidad,
}

/// La oración completa: raíz del árbol.
class Oracion {
  final Modo modo;

  /// Concepto de la palabra interrogativa (`CUANDO`, `QUIEN`...). Solo en
  /// [Modo.preguntaAbierta].
  final String? interrogativo;

  /// Qué papel cumple [interrogativo] en la oración.
  final RolInterrogativo? rolInterrogativo;

  /// "no" delante del verbo.
  final bool negada;

  final Tiempo tiempo;

  /// Concepto del verbo (`VENIR`, `QUERER`...).
  final String verbo;

  /// Quien hace la acción. Siempre existe: si en español se omitió
  /// ("¿Cuándo llegan?"), el parser lo deduce del verbo y lo marca como
  /// [Pronominal.inferido].
  final Participante sujeto;

  /// Lo que recibe la acción ("paz" en "queremos paz"). Puede no haber.
  final Participante? objeto;

  const Oracion({
    required this.modo,
    required this.negada,
    required this.tiempo,
    required this.verbo,
    required this.sujeto,
    this.objeto,
    this.interrogativo,
    this.rolInterrogativo,
  });

  Map<String, Object?> toMap() => {
        'modo': modo.name,
        if (interrogativo != null) 'interrogativo': interrogativo,
        if (rolInterrogativo != null) 'rolInterrogativo': rolInterrogativo!.name,
        'negada': negada,
        'tiempo': tiempo.name,
        'verbo': verbo,
        'sujeto': sujeto.toMap(),
        if (objeto != null) 'objeto': objeto!.toMap(),
      };

  /// El árbol dibujado en texto, para el modo traza.
  String dibujar() {
    final sb = StringBuffer('Oracion\n');
    final filas = <(String, String)>[
      ('modo', modo.name),
      if (interrogativo != null)
        ('interrogativo', '$interrogativo (${rolInterrogativo?.name})'),
      ('negada', negada ? 'si' : 'no'),
      ('tiempo', tiempo.name),
      ('verbo', verbo),
      ('sujeto', sujeto.describir()),
      if (objeto != null) ('objeto', objeto!.describir()),
    ];
    for (var i = 0; i < filas.length; i++) {
      final rama = i == filas.length - 1 ? '└─' : '├─';
      sb.writeln('$rama ${filas[i].$1}: ${filas[i].$2}');
    }
    return sb.toString().trimRight();
  }

  @override
  String toString() => dibujar();
}

/// Algo o alguien que participa en la oración (sujeto u objeto).
sealed class Participante {
  const Participante();

  Map<String, Object?> toMap();

  /// Descripción corta para la traza.
  String describir();
}

/// Un pronombre personal: yo, tú, usted, él, nosotros, ustedes, ellos.
class Pronominal extends Participante {
  final Persona persona;
  final Numero numero;

  /// true si el español no lo escribió y el parser lo dedujo del verbo
  /// ("¿Cuándo llegan?" -> ustedes).
  final bool inferido;

  const Pronominal(this.persona, this.numero, {this.inferido = false});

  @override
  Map<String, Object?> toMap() => {
        'clase': 'pronominal',
        'persona': persona.name,
        'numero': numero.name,
        if (inferido) 'inferido': true,
      };

  @override
  String describir() =>
      'pronombre ${persona.name} ${numero.name}${inferido ? ' (inferido)' : ''}';

  @override
  bool operator ==(Object other) =>
      other is Pronominal &&
      other.persona == persona &&
      other.numero == numero &&
      other.inferido == inferido;

  @override
  int get hashCode => Object.hash(persona, numero, inferido);
}

/// Un sustantivo con lo que lo acompaña: "quince naves", "nuestro planeta".
class Nominal extends Participante {
  /// Concepto del sustantivo (`NAVE`, `PLANETA`...).
  final String concepto;

  /// Plural si el sustantivo está en plural o lleva una cantidad mayor que 1.
  final Numero numero;

  /// Cantidad escrita: "quince naves" -> 15. null si no hay.
  final int? cantidad;

  /// Dueño: "nuestro planeta" -> primera persona plural. null si no hay.
  final Poseedor? poseedor;

  /// true en "¿cuántas naves...?": se pregunta por la cantidad.
  final bool preguntaCantidad;

  const Nominal(
    this.concepto, {
    required this.numero,
    this.cantidad,
    this.poseedor,
    this.preguntaCantidad = false,
  });

  @override
  Map<String, Object?> toMap() => {
        'clase': 'nominal',
        'concepto': concepto,
        'numero': numero.name,
        if (cantidad != null) 'cantidad': cantidad,
        if (poseedor != null) 'poseedor': poseedor!.toMap(),
        if (preguntaCantidad) 'preguntaCantidad': true,
      };

  @override
  String describir() {
    final partes = <String>[concepto, numero.name];
    if (cantidad != null) partes.add('cantidad $cantidad');
    if (preguntaCantidad) partes.add('pregunta cuántos');
    if (poseedor != null) partes.add('de ${poseedor!.describir()}');
    return partes.join(', ');
  }
}

/// El hueco que ocupa una palabra interrogativa: "¿QUIÉN envió...?" ocupa
/// el sujeto y "¿QUÉ quieren?" el objeto.
class Incognita extends Participante {
  /// Concepto interrogativo (`QUIEN`, `QUE`...).
  final String concepto;

  const Incognita(this.concepto);

  @override
  Map<String, Object?> toMap() => {'clase': 'incognita', 'concepto': concepto};

  @override
  String describir() => 'incógnita $concepto';
}

/// Dueño de un sustantivo ("su planeta", "nuestro mundo").
class Poseedor {
  final Persona persona;
  final Numero numero;

  const Poseedor(this.persona, this.numero);

  Map<String, Object?> toMap() =>
      {'persona': persona.name, 'numero': numero.name};

  String describir() => '${persona.name} ${numero.name}';
}
