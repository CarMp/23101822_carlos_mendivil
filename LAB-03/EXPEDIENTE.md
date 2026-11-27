# Expediente de auditoría interna — Base comercial

## 1. Alcance

- **Organización:** Comercializadora Norte S.A. de C.V. — Revisión de Auditoría Interna sobre la base **comercial** (solicitudes **A1** a **A6**).
- **Sistemas y despliegue:**
  - **PostgreSQL 16.16** en contenedor Docker **dba-u3-pg** (**postgres:16**), puerto **5432**, base de datos **comercial** (esquemas **public**, **auditoria**, **dba**, **gobierno**).
  - **MongoDB 7 Community** en contenedor Docker **dba-u3-mongo** (**mongo:7**), puerto **27017**, bases **comercial** y **auditoria** (referencia del LAB-02).
- **Periodo revisado:** Sesión de ejecución e integración del entorno del **2026-11-27** (UTC) / **2026-11-26** (hora local **-07:00**), abarcando desde el arranque del colector de bitácoras (**E5**, línea 1) hasta el cierre de las evidencias **E1**–**E6**.
- **Responsable de integración del expediente:** Juan Carlos Mendivil Paez (**DBA**). La conciliación independiente y la aceptación de hallazgos y riesgos corresponden a **Auditoría Interna**, **Gerencia Comercial**, **Comité de Cambios**, **Área Jurídica** y **Dirección de TI** según cada dominio.

---

## 2. Configuración de auditoría (A3)

Los controles técnicos verificados en el entorno comprenden:

1. **Bitácora del servidor PostgreSQL (**E1**, **E5**):**
   - **logging_collector = on** escribiendo en **log/postgresql.log** (verificado en [E1-configuracion-registro.txt](evidencias/E1-configuracion-registro.txt)).
   - **log_connections = on**, **log_disconnections = on**, **log_statement = mod**, **log_min_error_statement = error** y **log_line_prefix = '%m [%p] user=%u db=%d app=%a '**.
   - Vista de consulta **dba.bitacora** sobre **pg_current_logfile()**, con acceso revocado a **PUBLIC**.
2. **Mínimo privilegio en PostgreSQL (**E2**):**
   - Rol **app_ventas** con **SELECT, UPDATE** sobre **public.clientes** y rol **soporte_ana** con **SELECT** sobre **public.clientes**, sin acceso a los esquemas **auditoria**, **dba** ni **gobierno** ([E2-privilegios.txt](evidencias/E2-privilegios.txt)).
3. **Auditoría de cambios a nivel de fila (**E3**, **E4**):**
   - Disparador **trg_auditoria_clientes** habilitado (**tgenabled = O**) sobre **public.clientes** ([E3-disparadores.txt](evidencias/E3-disparadores.txt)), invocando a la función **SECURITY DEFINER** **auditoria.fn_registrar_cambio_cliente()** para registrar **INSERT**, **UPDATE** y **DELETE** en **auditoria.cambios_clientes** ([E4-muestra-auditoria.txt](evidencias/E4-muestra-auditoria.txt)).
4. **Trazabilidad de referencia en MongoDB 7 Community (**E6**):**
   - Perfilador de operaciones activado en nivel **2** sobre **comercial.system.profile** ([system-profile.json](evidencias/E6-mongodb/system-profile.json)).
   - Registro de red y eventos del daemon en [bitacora-mongod.log](evidencias/E6-mongodb/bitacora-mongod.log).
   - Instantánea de roles/usuarios en **auditoria.instantaneas_privilegios** y matriz comparativa en [09-comparacion.md](evidencias/E6-mongodb/09-comparacion.md).

---

## 3. Bitácora interpretada (A3, A5)

### Evento 1 — Incidente del RFC de María García (intento fallido de **app_ventas**, desactivación del disparador por **postgres** y corrección posterior)
- **Quién:** Inicialmente **app_ventas**; posteriormente el superusuario **postgres**; finalmente **app_ventas** en la corrección.
- **Cuándo:** **2026-11-27 03:11:25.707 UTC** (intento fallido), **03:11:25.821–03:11:25.824 UTC** (evasión por **postgres**) y **03:11:25.940251 UTC** (corrección auditada).
- **Desde dónde:** Conexión local (**host=[local]**), cliente **psql**.
- **Qué ocurrió:**
  1. En [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log#L34-L36), **app_ventas** intentó ejecutar **ALTER TABLE public.clientes DISABLE TRIGGER trg_auditoria_clientes;** y fue bloqueado (**ERROR: must be owner of table clientes**).
  2. En [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log#L40-L42), **postgres** deshabilitó **trg_auditoria_clientes**, ejecutó **UPDATE public.clientes SET rfc = 'GAMA900412ZZ0' WHERE id = 2;** (María García) sin dejar rastro en **auditoria.cambios_clientes**, y volvió a habilitar el disparador.
  3. En [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log#L46) y [E4-muestra-auditoria.txt](evidencias/E4-muestra-auditoria.txt) (**id_evento = 13**), **app_ventas** restauró el RFC de **id_cliente = 2** a **'GAMA900412XY9'**, registrando **valores_antes.rfc = GAMA900412ZZ0** y **valores_despues.rfc = GAMA900412XY9**.
- **Tipo de evento:** Intento de evasión de control (rechazado), desactivación no autorizada de auditoría por superusuario y modificación directa sin folio de cambio.
- **Qué prueba:** Demuestra que el mínimo privilegio protegió el trigger frente a **app_ventas**, pero también prueba que un administrador (**postgres**) puede eludir **auditoria.cambios_clientes**; solo la bitácora del servidor (**E5**) permitió reconstruir el cambio intermedio sobre el RFC de María García.

### Evento 2 — Creación de rol temporal y exposición de contraseña en texto claro
- **Quién:** **postgres**.
- **Cuándo:** **2026-11-27 03:11:25.469 UTC**.
- **Desde dónde:** **host=[local]**, aplicación **psql**.
- **Qué ocurrió:** Ejecución de **CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';** registrada en [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log#L26) sin folio en **gobierno.solicitudes_cambio**.
- **Tipo de evento:** Evento DDL de gestión de identidades y privilegios.
- **Qué prueba:** Confirma que **log_statement = 'mod'** registra la creación de cuentas, pero evidencia que incluir contraseñas literales en sentencias DDL las expone en el log del servidor, obligando a restringir el acceso a **dba.bitacora** y a redactar (**<REDACTED>**) antes de exportar la evidencia.

### Evento 3 — Cambio estructural autorizado en producción dentro de ventana (**CAM-2026-014**)
- **Quién:** **postgres** (ejecutor), solicitado por **Gerencia Comercial** y aprobado por **Comité de cambios**.
- **Cuándo:** **2026-11-27 03:13:23.098–03:13:23.099 UTC** (dentro de la ventana autorizada **[now() - 5 min, now() + 1 h]**).
- **Desde dónde:** **host=[local]**, aplicación **psql**.
- **Qué ocurrió:** Se ejecutó **ALTER TABLE public.clientes ADD COLUMN IF NOT EXISTS canal_alta VARCHAR(20);** seguido de su **COMMENT ON COLUMN**, registrado en [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log#L102-L103) y vinculado al folio **CAM-2026-014** en **gobierno.solicitudes_cambio** ([06-conciliacion.md](evidencias/06-conciliacion.md)).
- **Tipo de evento:** Cambio DDL autorizado y ejecutado en ventana productiva.
- **Qué prueba:** Demuestra el funcionamiento de **POL-06**: es posible conciliar de forma verificable una modificación en la bitácora del motor contra una aprobación previa vigente.

### Evento 4 — Perfilado de escritura y conexión sin autenticación en MongoDB 7
- **Quién:** Cliente sin usuario autenticado (**user: ""**, **appName: "mongosh 2.14.2"**).
- **Cuándo:** **2026-11-27T03:10:59Z**.
- **Desde dónde:** **127.0.0.1** (sesiones **conn6** a **conn9**).
- **Qué ocurrió:** Activación de **db.setProfilingLevel(2)** en **comercial** ([bitacora-mongod.log](evidencias/E6-mongodb/bitacora-mongod.log#L41-L43)), inserción y actualización sobre **comercial.clientes** capturadas en [system-profile.json](evidencias/E6-mongodb/system-profile.json), bajo mensajes **"Connection not authenticating"** ([bitacora-mongod.log](evidencias/E6-mongodb/bitacora-mongod.log#L36-L38)).
- **Tipo de evento:** Operación perfilada y conexión sin autenticación en instancia MongoDB Community.
- **Qué prueba:** Demuestra que el perfilador registra operaciones recientes en **system.profile**, pero al no existir autenticación ni auditoría nativa, no atribuye acciones a usuarios individuales nominales.

---

## 4. Elementos de gobierno (A1, A2)

- **Propietarios, custodios y usuarios (A1):** Documentado en [02-responsables.md](evidencias/02-responsables.md). Se separa explícitamente al propietario de negocio (Gerencia Comercial para **clientes**, Auditoría Interna / Oficial de Seguridad para auditoría y bitácoras, Comité de Cambios para **gobierno.solicitudes_cambio**) del custodio operativo (DBA) y los usuarios aplicativos (**app_ventas**, **soporte_ana**).
- **Catálogo mínimo de datos (A1):** Documentado en [04-catalogo.md](evidencias/04-catalogo.md) y respaldado por [03-inventario-tablas.sql](sql/03-inventario-tablas.sql), inventariando siete activos (**CAT-01** a **CAT-07**) entre PostgreSQL 16 y MongoDB 7, con propietario, ubicación, clasificación y volumetría tras **ANALYZE**.
- **Diccionario de datos operativo (A2):** Implementado dentro del motor mediante **COMMENT ON TABLE/COLUMN** en [02-comentarios-diccionario.sql](sql/02-comentarios-diccionario.sql), exportado a [diccionario-clientes.csv](evidencias/diccionario-clientes.csv) y complementado con clasificación, finalidad, control aplicado y regla de calidad en [03-diccionario.md](evidencias/03-diccionario.md).

---

## 5. Conservación (A3)

El criterio completo de conservación para los siete tipos de registro (accesos de PostgreSQL, cambios de privilegios/estructura, modificaciones DML, **auditoria.cambios_clientes**, bitácora de **mongod**, **comercial.system.profile** e instantáneas de privilegios de MongoDB) se detalla en [05-conservacion.md](evidencias/05-conservacion.md). Se establecen **12 meses** para auditoría de cambios, privilegios y estructura (alineado con **POL-05**), **90 días** para operación rutinaria, exportación previa a sobrescritura para **system.profile** (colección capped de 1 MB) y resguardo externo con SHA-256, marcando las obligaciones legales (LFPDPPP / CFF) como **Plazo a confirmar con el área jurídica**.

---

## 6. Políticas (A4)

| ID | Política | Archivo | Evidencia vinculada / Estado actual |
|---|---|---|---|
| **POL-01** | Acceso | [POL-01-acceso.md](politicas/POL-01-acceso.md) | [E2-privilegios.txt](evidencias/E2-privilegios.txt), [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log), **auditoria.instantaneas_privilegios** (sin acta de revisión mensual histórica aún) |
| **POL-02** | Respaldo | [POL-02-respaldo.md](politicas/POL-02-respaldo.md) | [E5-bitacora-postgresql.sha256](evidencias/E5-bitacora-postgresql.sha256) y **E6** (no existe respaldo automatizado ni prueba mensual ejecutada aún; procedimiento técnico en Unidad V) |
| **POL-03** | Retención | [POL-03-retencion.md](politicas/POL-03-retencion.md) | [05-conservacion.md](evidencias/05-conservacion.md), [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log) y **E6** (pendiente confirmación jurídica de plazos LFPDPPP/CFF y automatización de purga) |
| **POL-04** | Restauración | [POL-04-restauracion.md](politicas/POL-04-restauracion.md) | **gobierno.solicitudes_cambio** (no existe registro de pruebas de restauración ejecutadas aún; procedimiento técnico en Unidad V) |
| **POL-05** | Uso de datos sensibles | [POL-05-datos-sensibles.md](politicas/POL-05-datos-sensibles.md) | [E2-privilegios.txt](evidencias/E2-privilegios.txt), [E3-disparadores.txt](evidencias/E3-disparadores.txt), [E4-muestra-auditoria.txt](evidencias/E4-muestra-auditoria.txt), [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log) (pendiente vista enmascarada de soporte en esta instancia) |
| **POL-06** | Cambios en producción | [POL-06-cambios-produccion.md](politicas/POL-06-cambios-produccion.md) | [04-registro-cambios.sql](sql/04-registro-cambios.sql), **gobierno.solicitudes_cambio** (**CAM-2026-014**) y [06-conciliacion.md](evidencias/06-conciliacion.md) |

---

## 7. Conciliación de cambios (A5)

La conciliación completa entre **dba.bitacora** ([E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log)) y **gobierno.solicitudes_cambio** consta en [06-conciliacion.md](evidencias/06-conciliacion.md):
- **Conforme:** El cambio **CAM-2026-014** (**ALTER TABLE public.clientes ADD COLUMN IF NOT EXISTS canal_alta VARCHAR(20)**, línea **102**) contó con aprobación del Comité de cambios y se ejecutó dentro de su ventana (**dentro_de_ventana = t**).
- **Preparación de laboratorio:** Ajustes iniciales **REVOKE**/**GRANT** (líneas **23**–**24**), columna **segmento** (línea **25**), comentarios **COMMENT** (líneas **60**–**70**) e implantación de **gobierno.solicitudes_cambio** (líneas **77**–**89**).
- **No autorizados / Hallazgos:** Creación de **rol_temporal** con contraseña en log (línea **26**), intento de **app_ventas** por deshabilitar **trg_auditoria_clientes** (línea **34**), deshabilitación efectiva de **trg_auditoria_clientes** por **postgres** (líneas **40**–**42**) y hueco previo por **log_statement = 'none'**.

---

## 8. Hallazgos

*(Todos los hallazgos se documentan intactos sin corrección silenciosa; los registros de prueba **id = 7** y **id = 8** permanecen en **public.clientes**.)*

| ID | Hallazgo | Fuente | Severidad | Impacto | Recomendación | Decisión requerida de |
|---|---|---|---|---|---|---|
| **H-01** | Posible registro duplicado por correo (**ana.lopez@example.test**, **id** **1** y **7**) | [01-calidad.md](evidencias/01-calidad.md) (C1) | Media | Duplicidad de identidad de cliente, historial fragmentado y riesgo en facturación | Validar identidad con el cliente, fusionar/inactivar duplicado y aprobar índice único en **lower(correo)** | Gerencia Comercial |
| **H-02** | RFC incompleto (**LOAA850315AB**, **id = 7**) y RFC ausente (**NULL**, **id = 8**) | [01-calidad.md](evidencias/01-calidad.md) (C2, C3) | Media | Imposibilidad de emitir facturación fiscal válida | Solicitar constancia fiscal para corregir y aprobar regla **CHECK** de formato RFC | Gerencia Comercial / Facturación |
| **H-03** | Datos inválidos al alta en **id = 8**: correo **sin-correo**, edad **-3**, teléfono **667**, CP **8000** | [01-calidad.md](evidencias/01-calidad.md) (C3, C4) | Media | Contaminación analítica, fallas de contacto y baja confiabilidad del padrón | Contactar al cliente para captura real e implantar validaciones **CHECK** tras aprobación | Gerencia Comercial y Comité de Cambios |
| **H-04** | Desactivación temporal de **trg_auditoria_clientes** por **postgres** y modificación del RFC de María García (**id = 2**) sin registro en **auditoria.cambios_clientes** | [06-conciliacion.md](evidencias/06-conciliacion.md), **E5** L40–42 | Alta | Pérdida de trazabilidad en la tabla de auditoría de datos (**valores_antes**/**valores_despues**) ante uso de cuenta superusuario | Prohibir **DISABLE TRIGGER** en producción (**POL-06**), restringir uso de **postgres** a emergencias con folio y revisar bitácoras externamente | Auditoría Interna / Dirección de TI |
| **H-05** | Creación de **rol_temporal** sin folio de cambio y exposición de contraseña en la bitácora del servidor (**E5** L26), más intento fallido de **app_ventas** por deshabilitar trigger (**E5** L34) | [06-conciliacion.md](evidencias/06-conciliacion.md), **E5** L26, L34–36 | Alta | Riesgo de acceso no gobernado, fuga de credenciales en logs y tentativa de evasión de controles | Exigir folio **POL-01**/**POL-06**, usar autenticación/gestión sin contraseñas en claro en SQL y redactar toda bitácora exportada | Oficial de Seguridad / Comité de Cambios |
| **H-06** | Periodo inicial con **log_statement = 'none'** donde no quedó registrada la creación de la vista **dba.bitacora** | [06-conciliacion.md](evidencias/06-conciliacion.md) | Media | Imposibilidad de verificar integridad completa de cambios previos al encendido de **log_statement = 'mod'** | Mantener **log_statement = 'mod'** desde la provisión inicial de la instancia | Dirección de TI / Auditoría Interna |
| **H-07** | Discrepancia del RFC de María García entre PostgreSQL (**GAMA900412XY9**) y MongoDB (**GAMA900412XY8**) | [04-catalogo.md](evidencias/04-catalogo.md), [09-comparacion.md](evidencias/E6-mongodb/09-comparacion.md) | Media | Inconsistencia entre base administrativa y tienda en línea por falta de fuente única de verdad | Designar a PostgreSQL **public.clientes** como maestro autorizado y conciliar/sincronizar MongoDB | Gerencia Comercial y Gerencia de Tienda |
| **H-08** | Ausencia de respaldos automatizados y pruebas de restauración verificadas (**POL-02**, **POL-04**), y falta de confirmación jurídica de plazos LFPDPPP/CFF (**POL-03**) | [POL-02-respaldo.md](politicas/POL-02-respaldo.md), [POL-03-retencion.md](politicas/POL-03-retencion.md), [POL-04-restauracion.md](politicas/POL-04-restauracion.md) | Alta | Riesgo de pérdida de datos ante falla grave e incertidumbre sobre cumplimiento de supresión/retención | Ejecutar plan técnico de respaldo y recuperación en Unidad V y formalizar plazos con Jurídico | Dirección de TI y Área Jurídica |
| **H-09** | Vista enmascarada para soporte (**soporte_ana**) documentada en Unidad II no desplegada aún en esta instancia (**E2** muestra **SELECT** directo sobre **public.clientes**) | [E2-privilegios.txt](evidencias/E2-privilegios.txt), [POL-05-datos-sensibles.md](politicas/POL-05-datos-sensibles.md) | Media | Exposición de **rfc** y datos personales completos a cuentas de soporte | Crear vista enmascarada y restringir **soporte_ana** exclusivamente a la vista | Gerencia Comercial / Oficial de Seguridad |
| **H-10** | MongoDB 7 Community operando sin autenticación habilitada y sin auditoría nativa; **system.profile** limitado a 1 MB | [09-comparacion.md](evidencias/E6-mongodb/09-comparacion.md), [bitacora-mongod.log](evidencias/E6-mongodb/bitacora-mongod.log) | Alta | Falta de atribución nominal de operaciones y pérdida de trazas al llenarse 1 MB o recrearse el contenedor | Habilitar control de acceso en **mongod**, exportar **system.profile** periódicamente y centralizar logs | Dirección de TI / Oficial de Seguridad |

---

## 9. Limitaciones conocidas y riesgos aceptados (A6)

Se distingue explícitamente lo **verificado en ejecución** en los laboratorios de lo **documentado pero no practicado**:

| Limitación / Brecha | Condición: Verificado vs. Documentado no practicado | Riesgo residual | Quién debe aceptar formalmente el riesgo |
|---|---|---|---|
| **Lecturas (**SELECT**) sobre **clientes** no quedan en **dba.bitacora**** con **log_statement = 'mod'** | **Verificado** en **E1** y **E5** (las consultas **SELECT** no se registran). La extensión **pgaudit** para auditar lecturas está **documentada pero no practicada** en **dba-u3-pg**. | No es posible demostrar quién leyó un RFC sin haberlo modificado. | Oficial de Seguridad de la Información y Gerencia Comercial |
| **El superusuario (**postgres**) puede deshabilitar triggers o alterar logs locales** | **Verificado** en **E5** líneas **40**–**42**. | Un administrador con credenciales **postgres** puede omitir **auditoria.cambios_clientes**. | Dirección de TI y Auditoría Interna (mitigable enviando logs en tiempo real a un servidor externo append-only) |
| **MongoDB 7 Community carece de auditoría nativa (**auditLog**)** | **Verificado** en **E6** (**system.profile** es colección capped de 1 MB y **getLog** vive en memoria). La auditoría nativa de **MongoDB Enterprise** es una capacidad **documentada pero no practicada**. | En Community no existe bitácora nativa inmutable de cambios de roles ni de quién consultó documentos. | Dirección de TI y Oficial de Seguridad de la Información |
| **Procedimientos de respaldo y restauración automática aún no implementados** | **Documentado pero no practicado** (reglas fijadas en **POL-02** y **POL-04**; ejecución técnica diferida a la **Unidad V**). | Sin respaldo verificado, una falla de almacenamiento o borrado accidental compromete la continuidad. | Dirección de TI y Gerencia Comercial (de forma temporal hasta completar la Unidad V) |
| **Plazos legales exactos de conservación/eliminación pendientes** | **Documentado** en **POL-03** y [05-conservacion.md](evidencias/05-conservacion.md) (Plazo a confirmar con el área jurídica). | Posible desajuste entre retención operativa/auditoría y obligaciones fiscales o de LFPDPPP. | Área Jurídica y Oficial de Cumplimiento |

---

## 10. Índice de evidencias

Todas las huellas criptográficas SHA-256 fueron calculadas directamente en terminal sobre los archivos exportados ([hashes-E1-E6.sha256](evidencias/hashes-E1-E6.sha256)):

| Evidencia / Archivo | Descripción | SHA-256 |
|---|---|---|
| [E1-configuracion-registro.txt](evidencias/E1-configuracion-registro.txt) | Parámetros vigentes de bitácora en **dba-u3-pg** | **c8de2d12aa7ef833e615871d9057c84e2ab4f3b794f6da02e29270a002e02ae5** |
| [E2-privilegios.txt](evidencias/E2-privilegios.txt) | Privilegios vigentes sobre tablas en **comercial** | **6077d47aea0356ea219afe0f2267fe920421114e81ce658f054859e6246b8808** |
| [E3-disparadores.txt](evidencias/E3-disparadores.txt) | Estado del disparador **trg_auditoria_clientes** (**tgenabled = O**) | **50440894270faeca401c5cdc79dc4f611547bff40804e6fda6ebed7c744c813a** |
| [E4-muestra-auditoria.txt](evidencias/E4-muestra-auditoria.txt) | Muestra de últimos 10 eventos (solo metadatos) en **auditoria.cambios_clientes** | **4dfe94993e3203863f46d18670f39ad9c5949d0a65ce40b4209fcbd7944838e1** |
| [E5-bitacora-postgresql.log](evidencias/E5-bitacora-postgresql.log) | Bitácora exportada de PostgreSQL 16 con secreto redactado (**<REDACTED>**) | **1a18a38aa443cbf4f049e465526911893106055a2c693b85183e9d4f192ad394** |
| [E5-bitacora-postgresql.sha256](evidencias/E5-bitacora-postgresql.sha256) | Archivo de verificación SHA-256 de **E5** | (archivo de firma de E5) |
| [system-profile.json](evidencias/E6-mongodb/system-profile.json) | **E6** — Operaciones perfiladas en **comercial.system.profile** (MongoDB 7) | **578e7f7e3d2750cddb86982df18f39337a530a2b4dcd4e796a3dff23f194647d** |
| [bitacora-mongod.log](evidencias/E6-mongodb/bitacora-mongod.log) | **E6** — Bitácora reciente del servidor **mongod** (**dba-u3-mongo**) | **37060df9d8bbfa5c4ab9479b9a41d5b79487be96f8e2b91136aea3c8f7cfbe08** |
| [09-comparacion.md](evidencias/E6-mongodb/09-comparacion.md) | **E6** — Comparación técnica PostgreSQL 16 vs. MongoDB 7 Community | **044a3540511c4e02374ede7cf66880ee6cdd6d9c887ccd067989d0120271fa5a** |
| [hashes-E1-E6.sha256](evidencias/hashes-E1-E6.sha256) | Consolidado de hashes SHA-256 para **E1** a **E6** | (archivo índice de hashes) |
| [diccionario-clientes.csv](evidencias/diccionario-clientes.csv) | Diccionario operativo de **public.clientes** exportado desde **information_schema** | — |
| [01-calidad.md](evidencias/01-calidad.md) | Hallazgos de calidad de datos (**C1**–**C4**) | — |
| [02-responsables.md](evidencias/02-responsables.md) | Matriz de propietarios, custodios y usuarios | — |
| [03-diccionario.md](evidencias/03-diccionario.md) | Complemento de gobierno del diccionario de datos | — |
| [04-catalogo.md](evidencias/04-catalogo.md) | Catálogo mínimo integrado (**CAT-01**–**CAT-07**) | — |
| [05-conservacion.md](evidencias/05-conservacion.md) | Criterio razonado de conservación de bitácoras | — |
| [06-conciliacion.md](evidencias/06-conciliacion.md) | Conciliación de **dba.bitacora** vs. **gobierno.solicitudes_cambio** | — |
