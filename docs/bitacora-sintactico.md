# Bitácora de decisiones: módulo sintáctico

Formato: problema, opciones, decisión y prueba que la demuestra
(`cli/test/sintactico/`).

---

### S-01 · 12/11/2026 · Sujeto omitido ("¿Cuándo llegan?")
- **Problema:** el español omite el sujeto, pero Kethari y Ozh lo exigen siempre. "llegan" puede ser *ellos* o *ustedes*, y "llega" *él* o *usted*.
- **Opciones:** (a) tomar siempre la 3ª persona (ellos); (b) en preguntas, tomar la 2ª persona (ustedes/usted), y en afirmaciones la 3ª; (c) no traducir y pedir el sujeto.
- **Decisión:** (b). Las preguntas de los gobiernos van dirigidas a los alienígenas, así que "¿Cuándo llegan?" significa "¿cuándo llegan ustedes?" (como la señal del día 5). La regla está en `morfologia.json` → `sujetoOmitido` y se puede cambiar sin recompilar. El parser avisa en `advertencias` que dedujo el sujeto.
- **Prueba:** `analizador_sintactico_test.dart` → "sujeto omitido en pregunta: ¿Cuándo llegan? -> ustedes", "Queremos paz: sujeto omitido y objeto".

### S-02 · 12/11/2026 · Sin "vosotros"
- **Problema:** el español de España tiene una forma más (vosotros llegáis).
- **Opciones:** (a) incluirla; (b) dejar solo cinco personas.
- **Decisión:** (b). En Colombia se usa "ustedes" con el verbo en 3ª plural. Se puede agregar en `morfologia.json` → `personas` sin tocar el código.
- **Prueba:** `morfologia_test.dart` → "verbo en -ar en las cinco personas".

### S-03 · 12/11/2026 · Formas verbales ambiguas
- **Problema:** sin tildes y por el propio español, una forma puede tener varios análisis: "llegamos" (presente o pasado), "envio" (yo envío o él envió), "fue" (ser o ir).
- **Opciones:** (a) rechazar la pregunta; (b) elegir por concordancia con el sujeto y, si sigue el empate, por una prioridad fija de tiempos.
- **Decisión:** (b). Primero se elige el análisis que concuerda con el sujeto ("¿quién envió?" pide 3ª singular → pasado). Si todavía hay empate, gana el primero de `prioridadTiempos` (presente, pasado, futuro) y se avisa en `advertencias`.
- **Prueba:** `morfologia_test.dart` → grupo "ambigüedades"; `analizador_sintactico_test.dart` → "¿Quién envió el mensaje?: envio en pasado".

### S-04 · 12/11/2026 · ¿Sujeto u objeto después del verbo?
- **Problema:** en "¿Llegaron las naves?" el sustantivo es el sujeto, y en "¿Quieren paz?" es el objeto. El orden no basta.
- **Opciones:** (a) siempre objeto; (b) usar la transitividad del verbo; (c) usar la concordancia.
- **Decisión:** (b). Cada verbo tiene `transitivo` en `verbos.json`. Después de un verbo transitivo el sustantivo es objeto, y después de uno intransitivo, sujeto. La concordancia no sirve sola: "enviaron mensajes" concuerda en plural y aun así "mensajes" es el objeto.
- **Prueba:** `analizador_sintactico_test.dart` → "verbo intransitivo: el sustantivo de después es el sujeto", "Queremos paz".

### S-05 · 12/11/2026 · "su" / "sus"
- **Problema:** "su planeta" puede ser de él, de ella, de usted, de ustedes o de ellos.
- **Opciones:** (a) 3ª persona; (b) 2ª plural (de ustedes).
- **Decisión:** (b), por la misma razón que S-01: las preguntas se dirigen a los alienígenas. Está en `palabras.json` → `posesivos`.
- **Prueba:** `analizador_sintactico_test.dart` → "¿Dónde está su hogar?: posesivo su -> de ustedes".

### S-06 · 12/11/2026 · Formas conjugadas para el corrector (pregunta del módulo léxico)
- **Problema:** el corrector necesita conocer "vendran", "llegaron"... o los cambiaría por otra palabra.
- **Opciones:** (a) guardar todas las conjugaciones en la BD; (b) que la morfología las genere a partir de reglas.
- **Decisión:** (b). La morfología aplica `morfologia.json` a los verbos de `verbos.json` al arrancar y entrega las formas por `AnalizadorSintactico.vocabulario`. Con (a) habría que llenar cientos de filas a mano, y el criterio de la rúbrica pide morfología "con reglas propias".
- **Prueba:** `morfologia_test.dart` → "da al corrector las formas conjugadas".

### S-07 · 12/11/2026 · "de dónde", "en dónde"
- **Problema:** el manual no tiene preposiciones como "de" o "en".
- **Opciones:** (a) ignorarlas y traducir "¿de dónde vienen?" como "¿dónde vienen?"; (b) no traducir y explicarlo.
- **Decisión:** (b). Ignorarla cambia el sentido de la pregunta, y la regla de Axios es "no traduzcan nada que no entiendan". Solo "a" está en el vocabulario ("ir a" y la "a" personal).
- **Prueba:** `analizador_sintactico_test.dart` → "palabra fuera del vocabulario" (mismo mecanismo).

### S-08 · 12/11/2026 · "ser vivo" (pendiente)
- **Problema:** el manual traduce "criatura, ser vivo" como `yorr`/`fen`, pero "ser" también es verbo.
- **Decisión provisional:** solo "criatura" está en el vocabulario. Se revisa en la semana 2.

### S-09 · 12/11/2026 · "tu/tú" y "el/él" sin tilde
- **Problema:** el normalizador quita las tildes, así que "tu planeta" y "tú vienes" llegan igual.
- **Opciones:** (a) pedir tildes; (b) decidir mirando el siguiente token.
- **Decisión:** (b). Si sigue un sustantivo o un número, es determinante; si no, pronombre. La gramática sigue siendo LL(1) (docs/bnf.md).
- **Prueba:** `analizador_sintactico_test.dart` → grupo "palabras con dos categorías sin tilde".

### S-10 · 12/11/2026 · Datos en JSON mientras se hace la BD
- **Problema:** el parser necesita el vocabulario desde ya, y la base de datos todavía no existe.
- **Opciones:** (a) esperar a la BD; (b) escribir el vocabulario en el código; (c) archivos de datos detrás de una interfaz.
- **Decisión:** (c). `FuenteLexicoEspanol` define qué se necesita y `FuenteLexicoJson` lo lee de `datos/espanol/`. La BD solo tendrá que implementar la misma interfaz. (b) está prohibido por el enunciado.
- **Prueba:** todas las pruebas cargan los datos reales con `FuenteLexicoJson()`.

### S-11 · 12/11/2026 · Dos verbos seguidos (limitación conocida)
- **Problema:** "¿Quieren visitar la tierra?" tiene un verbo conjugado y un infinitivo.
- **Decisión:** por ahora el parser lo rechaza con una explicación ("todavía no se entienden dos verbos"). Se resuelve en la semana 2, de acuerdo con el generador, porque el manual no dice cómo se dice en Kethari ni en Ozh.
- **Prueba:** `analizador_sintactico_test.dart` → "dos verbos seguidos todavía no se entienden".
