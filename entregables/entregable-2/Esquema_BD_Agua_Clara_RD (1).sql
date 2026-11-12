-- Agua Clara RD | Esquema físico de base de datos SQLite
-- Extraído de server/db.js, constantes SCHEMA y SCHEMA_E2.
-- El servidor también realiza migraciones, configura permisos y carga datos iniciales.
-- Para ejecutar en una nueva BD: sqlite3 aguas-claras.db < Esquema_BD_Agua_Clara_RD.sql
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Epica 1: identidad, seguridad y reportes
CREATE TABLE IF NOT EXISTS roles(
  id INTEGER PRIMARY KEY, nombre TEXT UNIQUE NOT NULL COLLATE NOCASE, activo INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS usuarios(
  id INTEGER PRIMARY KEY, nombre TEXT NOT NULL, correo TEXT UNIQUE NOT NULL COLLATE NOCASE,
  telefono TEXT DEFAULT '', clave_hash TEXT NOT NULL,
  rol_id INTEGER NOT NULL REFERENCES roles(id),
  estado TEXT NOT NULL DEFAULT 'Activo', motivo TEXT DEFAULT '', foto TEXT, actualizado INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS permisos(
  rol_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE, modulo TEXT NOT NULL,
  crear INTEGER NOT NULL DEFAULT 0, consultar INTEGER NOT NULL DEFAULT 0,
  modificar INTEGER NOT NULL DEFAULT 0, eliminar INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY(rol_id, modulo));
CREATE TABLE IF NOT EXISTS sesiones(
  token TEXT PRIMARY KEY, usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE, expira INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS tokens_recuperacion(
  token TEXT PRIMARY KEY, usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  expira INTEGER NOT NULL, usado INTEGER NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS auditoria(
  id INTEGER PRIMARY KEY, fecha INTEGER NOT NULL, usuario TEXT NOT NULL, evento TEXT NOT NULL,
  ip TEXT, localizacion TEXT, detalle TEXT DEFAULT '');
CREATE INDEX IF NOT EXISTS idx_auditoria_fecha ON auditoria(fecha DESC);
CREATE TABLE IF NOT EXISTS reportes(
  id INTEGER PRIMARY KEY, codigo TEXT UNIQUE NOT NULL, municipio TEXT NOT NULL, sector TEXT NOT NULL,
  tipo TEXT NOT NULL, desde TEXT, descripcion TEXT NOT NULL, estado INTEGER NOT NULL DEFAULT 0,
  contacto_nombre TEXT, contacto_telefono TEXT, creado INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS config(clave TEXT PRIMARY KEY, valor TEXT NOT NULL);

-- Epica 2: gestion operativa
CREATE TABLE IF NOT EXISTS tipos_operacion(
  id INTEGER PRIMARY KEY, nombre TEXT UNIQUE NOT NULL COLLATE NOCASE,
  sla_horas INTEGER NOT NULL DEFAULT 48, aviso_horas INTEGER NOT NULL DEFAULT 12,
  requiere_aprobacion INTEGER NOT NULL DEFAULT 0, aprobador_rol_id INTEGER REFERENCES roles(id) ON DELETE SET NULL,
  activo INTEGER NOT NULL DEFAULT 1);
CREATE TABLE IF NOT EXISTS operaciones(
  id INTEGER PRIMARY KEY, codigo TEXT UNIQUE NOT NULL, tipo_id INTEGER NOT NULL REFERENCES tipos_operacion(id),
  titulo TEXT NOT NULL, descripcion TEXT NOT NULL, prioridad TEXT NOT NULL DEFAULT 'Media',
  estado TEXT NOT NULL DEFAULT 'Creada',
  responsable_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL, creado_por INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
  reporte_codigo TEXT, fecha_limite INTEGER NOT NULL, resultado TEXT,
  creado INTEGER NOT NULL, actualizado INTEGER NOT NULL, cerrado INTEGER);
CREATE INDEX IF NOT EXISTS idx_op_estado ON operaciones(estado);
CREATE TABLE IF NOT EXISTS asignaciones(
  id INTEGER PRIMARY KEY, operacion_id INTEGER NOT NULL REFERENCES operaciones(id) ON DELETE CASCADE,
  responsable_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL, asignado_por INTEGER REFERENCES usuarios(id) ON DELETE SET NULL,
  fecha INTEGER NOT NULL, motivo TEXT DEFAULT '');
CREATE TABLE IF NOT EXISTS aprobaciones(
  id INTEGER PRIMARY KEY, operacion_id INTEGER NOT NULL REFERENCES operaciones(id) ON DELETE CASCADE,
  aprobador_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL, decision TEXT NOT NULL,
  comentario TEXT DEFAULT '', fecha INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS incidencias(
  id INTEGER PRIMARY KEY, codigo TEXT UNIQUE NOT NULL, operacion_id INTEGER NOT NULL REFERENCES operaciones(id) ON DELETE CASCADE,
  categoria TEXT NOT NULL, descripcion TEXT NOT NULL, prioridad TEXT NOT NULL DEFAULT 'Media',
  responsable_id INTEGER REFERENCES usuarios(id) ON DELETE SET NULL, estado TEXT NOT NULL DEFAULT 'Abierta',
  resolucion TEXT, creado_por INTEGER REFERENCES usuarios(id) ON DELETE SET NULL, creado INTEGER NOT NULL, actualizado INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS incidencia_comentarios(
  id INTEGER PRIMARY KEY, incidencia_id INTEGER NOT NULL REFERENCES incidencias(id) ON DELETE CASCADE,
  usuario TEXT NOT NULL, texto TEXT NOT NULL, fecha INTEGER NOT NULL);
CREATE TABLE IF NOT EXISTS notificaciones(
  id INTEGER PRIMARY KEY, usuario_id INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE, tipo TEXT NOT NULL,
  operacion_id INTEGER REFERENCES operaciones(id) ON DELETE CASCADE, mensaje TEXT NOT NULL,
  canal TEXT NOT NULL DEFAULT 'interno', resultado TEXT NOT NULL DEFAULT 'Entregada', leida INTEGER NOT NULL DEFAULT 0, fecha INTEGER NOT NULL);
CREATE INDEX IF NOT EXISTS idx_notif_usuario ON notificaciones(usuario_id, leida);
CREATE TABLE IF NOT EXISTS bitacora(
  id INTEGER PRIMARY KEY, fecha INTEGER NOT NULL, actor_id INTEGER, actor TEXT NOT NULL, entidad TEXT NOT NULL, entidad_id TEXT,
  operacion TEXT, accion TEXT NOT NULL, resultado TEXT NOT NULL DEFAULT 'Exitoso', antes TEXT, despues TEXT, detalle TEXT DEFAULT '');
CREATE INDEX IF NOT EXISTS idx_bitacora_op ON bitacora(operacion);
CREATE INDEX IF NOT EXISTS idx_bitacora_fecha ON bitacora(fecha DESC);
CREATE TRIGGER IF NOT EXISTS bitacora_sin_modificar BEFORE UPDATE ON bitacora
  BEGIN SELECT RAISE(ABORT, 'La bitácora no se puede modificar'); END;
CREATE TRIGGER IF NOT EXISTS bitacora_sin_eliminar BEFORE DELETE ON bitacora
  BEGIN SELECT RAISE(ABORT, 'La bitácora no se puede eliminar'); END;
