const esquemaSql = '''
CREATE TABLE IF NOT EXISTS lexico (
  id INTEGER PRIMARY KEY,
  lema_es TEXT NOT NULL,
  categoria TEXT NOT NULL,
  UNIQUE (lema_es, categoria)
);
CREATE TABLE IF NOT EXISTS lexico_version (
  id INTEGER PRIMARY KEY,
  lexico_id INTEGER NOT NULL REFERENCES lexico(id),
  kethari TEXT,
  ozh TEXT,
  vigente_desde TEXT NOT NULL,
  vigente_hasta TEXT,
  origen TEXT
);
CREATE TABLE IF NOT EXISTS carga (
  id INTEGER PRIMARY KEY,
  archivo TEXT,
  fecha TEXT NOT NULL,
  filas INTEGER
);
CREATE TABLE IF NOT EXISTS senal (
  id INTEGER PRIMARY KEY,
  dia INTEGER NOT NULL,
  voz TEXT NOT NULL,
  transcripcion TEXT NOT NULL,
  salida TEXT NOT NULL,
  carga_id INTEGER REFERENCES carga(id),
  UNIQUE (dia, voz, transcripcion, salida)
);
''';