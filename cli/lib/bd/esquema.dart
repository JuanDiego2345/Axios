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
CREATE TABLE IF NOT EXISTS senal (
  id INTEGER PRIMARY KEY,
  nombre TEXT NOT NULL,
  significado TEXT,
  vigente_desde TEXT NOT NULL,
  vigente_hasta TEXT
);
CREATE TABLE IF NOT EXISTS carga (
  id INTEGER PRIMARY KEY,
  archivo TEXT,
  fecha TEXT NOT NULL,
  filas INTEGER
);
''';