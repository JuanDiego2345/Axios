# Bitácora de decisiones: módulo léxico (integrante 1)

Formato: problema, opciones, decisión y prueba que la demuestra
(`cli/test/lexico/`).

---

### L-01 · 12/11/2026 · Tildes y ñ
- **Problema:** las preguntas llegan con o sin tildes y el vocabulario debe coincidir en ambos casos.
- **Opciones:** (a) conservar las tildes; (b) quitarlas y conservar la ñ; (c) quitar todo, incluida la ñ (ñ→n).
- **Decisión:** (b). Se quitan tildes y diéresis y se conserva la ñ, porque "año" y "ano" son palabras distintas. Qué/que y cuándo/cuando se distinguen por los signos y la posición.
- **Prueba:** `normalizador_test.dart` → "pasa a minúsculas y quita tildes", "conserva la ñ".

### L-02 · 12/11/2026 · "un" / "una": ¿artículo o número?
- **Problema:** "una nave" puede ser un artículo o la cantidad 1.
- **Opciones:** (a) convertir siempre a 1; (b) no convertir cuando aparecen solos.
- **Decisión:** (b). Solos son artículos. Dentro de una cantidad sí cuentan ("ciento un", "veintiuna"). "uno" solo sí se convierte en 1.
- **Prueba:** `normalizador_test.dart` → "un / una sueltos son artículos".

### L-03 · 12/11/2026 · Posición de los tokens
- **Problema:** el normalizador cambia la longitud del texto ("dos mil quince" → "2015"), así que la posición en el original y en el normalizado no coinciden.
- **Opciones:** (a) posición en el texto original; (b) posición en el texto normalizado.
- **Decisión:** (b). Es el texto que lee el AFD. El historial guarda los dos textos para poder relacionarlos.
- **Prueba:** `analizador_lexico_test.dart` → "pregunta simple con posiciones".

### L-04 · 12/11/2026 · Umbral del corrector
- **Problema:** un umbral alto inventa palabras y uno bajo no corrige nada.
- **Opciones:** (a) distancia fija de 2; (b) distancia según la longitud.
- **Decisión:** (b). 1–2 letras: no se corrige; 3–5 letras: distancia 1; 6 o más: distancia 2. Las palabras cortas tienen muchas vecinas, y la regla de Axios es "no se inventa nada".
- **Prueba:** `corrector_test.dart` → "umbral según longitud", "palabras de 1 o 2 letras no se corrigen".

### L-05 · 12/11/2026 · Empates en el corrector
- **Problema:** varias palabras pueden quedar a la misma distancia.
- **Opciones:** (a) no corregir si hay empate; (b) desempatar con reglas fijas.
- **Decisión:** (b). Gana la que tiene la misma primera letra, luego la de longitud más parecida y luego el orden alfabético. La corrección se marca `ambigua` y guarda las empatadas para el historial y la traza.
- **Prueba:** `corrector_test.dart` → "desempate: prefiere la misma primera letra".

### L-06 · 12/11/2026 · Palabras numéricas dentro del normalizador
- **Problema:** el enunciado prohíbe escribir el léxico en el código, pero el normalizador debe leer "dos mil quince".
- **Decisión:** las palabras numéricas del español son reglas de lectura de cantidades, no léxico de traducción. Viven en `numeros_texto.dart`. Los números en Kethari y Ozh sí van en la BD.
- **Pendiente:** confirmar con el docente; si no lo acepta, se pasan a la BD.

### L-07 · 12/11/2026 · Cantidades en letras mal escritas (limitación conocida)
- **Problema:** el normalizador se ejecuta antes que el corrector, así que "quinse naves" no se convierte en 15.
- **Decisión:** por ahora se acepta como limitación. Se puede resolver en la semana 2 volviendo a convertir números después de corregir.
