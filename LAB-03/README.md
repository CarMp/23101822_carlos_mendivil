# LAB-03 — Políticas prácticas, gobierno de datos y evidencias

**Materia:** Gestión de Seguridad y Desempeño de Bases de Datos — Unidad III  
**Estudiante:** Juan Carlos Mendivil Paez  
**Entorno Docker:**
- PostgreSQL 16 (**dba-u3-pg**) en puerto **5432**, base de datos **comercial**
- MongoDB 7 Community (**dba-u3-mongo**) en puerto **27017**, bases **comercial** y **auditoria**

## Estructura del proyecto

- [EXPEDIENTE.md](EXPEDIENTE.md): Evidencia oficial de la Unidad III.
- **sql/**:  
  - [01-verificaciones-calidad.sql](sql/01-verificaciones-calidad.sql): Consultas de duplicidad, formato de RFC/correo, rango de edad y completitud.
  - [02-comentarios-diccionario.sql](sql/02-comentarios-diccionario.sql): Documentación con **COMMENT ON TABLE/COLUMN** y consulta al diccionario operativo.
  - [03-inventario-tablas.sql](sql/03-inventario-tablas.sql): Inventario de tablas y vistas en **pg_class** tras **ANALYZE**.
  - [04-registro-cambios.sql](sql/04-registro-cambios.sql): Esquema **gobierno**, tabla **gobierno.solicitudes_cambio**, cambio **CAM-2026-014** y extracción de DDL/privilegios de **dba.bitacora**.
- **politicas/**: Seis políticas prácticas verificables [POL-01](politicas/POL-01-acceso.md) a [POL-06](politicas/POL-06-cambios-produccion.md).
- **evidencias/**: Reportes de actividades **01-calidad.md** a **06-conciliacion.md**, [diccionario-clientes.csv](evidencias/diccionario-clientes.csv), evidencias técnicas **E1** a **E6** y sus huellas SHA-256 en [hashes-E1-E6.sha256](evidencias/hashes-E1-E6.sha256).

## Lista de verificación final

- Hallazgos de calidad registrados con responsable de la decisión, ubicado en **evidencias/01-calidad.md**, sin eliminar los registros **id = 7** y **id = 8**.
- Matriz de responsables con propietario, custodio y usuarios **evidencias/02-responsables.md**.
- Comentarios **COMMENT** en **public.clientes** y en todas sus columnas **sql/02-comentarios-diccionario.sql** + **canal_alta** en **sql/04-registro-cambios.sql**.
- Diccionario exportado en formato CSV y completado con clasificación y finalidad **evidencias/diccionario-clientes.csv**, **evidencias/03-diccionario.md**.
- Catálogo mínimo integrado con al menos cinco conjuntos de datos entre Postgre y Mongo **evidencias/04-catalogo.md**.
- Criterio de conservación para los siete tipos de registro **evidencias/05-conservacion.md**.
- Seis políticas prácticas con regla verificable y evidencia nombrada **politicas/POL-01** a **POL-06**.
- Registro de cambios creado **gobierno.solicitudes_cambio** y conciliado contra **dba.bitacora** **evidencias/06-conciliacion.md**.
- Evidencias **E1** a **E6** generadas con cálculo SHA-256 verificado en terminal **evidencias/hashes-E1-E6.sha256**.
- **EXPEDIENTE.md** completo, con los cuatro eventos interpretados incluyendo el incidente del RFC de María García, hallazgos con severidad y limitaciones distinguiendo lo verificado de lo no practicado.
