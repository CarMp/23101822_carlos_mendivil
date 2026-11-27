# Actividad 2 — Matriz de propietarios, custodios y usuarios

Ampliación de las figuras de gobierno (Sección 4.2: Propietario, Custodio y Usuario) sobre los conjuntos de datos de la base **comercial** en PostgreSQL 16 (**dba-u3-pg**) y MongoDB 7 (**dba-u3-mongo**), incorporando los objetos de auditoría y gobierno de la Unidad III.

## Matriz de responsabilidades

| Conjunto de datos | Propietario (Data Owner) | Custodio (Data Custodian) | Usuarios autorizados | Quién aprueba accesos |
|---|---|---|---|---|
| **comercial.public.clientes** (PostgreSQL 16) | Gerencia Comercial | DBA | **app_ventas** (**SELECT, UPDATE**), **soporte_ana** (**SELECT** mediante vista restringida / mínimo privilegio) | Gerencia Comercial |
| **auditoria.cambios_clientes** (PostgreSQL 16) | Área de Auditoría Interna / Oficial de Cumplimiento | DBA (sin alterar registros; solo resguardo e integridad) | Auditoría Interna (solo lectura) y función **SECURITY DEFINER** del trigger **trg_auditoria_clientes** | Auditoría Interna / Dirección de TI |
| Bitácora de PostgreSQL y vista **dba.bitacora** | Oficial de Seguridad de la Información / Auditoría Interna | DBA (configuración de **logging_collector**, rotación y exportación con hash) | DBA (operación/diagnóstico) y Auditoría Interna (revisión, previa redacción de secretos) | Oficial de Seguridad / Auditoría Interna |
| **gobierno.solicitudes_cambio** (PostgreSQL 16) | Comité de Cambios | DBA | Comité de Cambios, Gerencia Comercial (consulta/solicitud) y Auditoría Interna (conciliación) | Comité de Cambios |
| **comercial.clientes** (MongoDB 7) | Gerencia de Comercio Electrónico / Gerencia Comercial | DBA | Aplicación de tienda en línea y equipo de soporte autorizado | Gerencia Comercial / Gerencia de Tienda |
| **comercial.system.profile** y bitácora **mongod** (MongoDB 7) | Oficial de Seguridad de la Información / Auditoría Interna | DBA | DBA (diagnóstico de desempeño) y Auditoría Interna | Oficial de Seguridad / Auditoría Interna |
| **auditoria.instantaneas_privilegios** (MongoDB 7) | Área de Auditoría Interna | DBA | Auditoría Interna y DBA (solo lectura / comparación) | Auditoría Interna |

## Respuestas a las preguntas de análisis

1. **¿Por qué el propietario de **auditoria.cambios_clientes** no debería ser el mismo que opera **clientes**?**  
   Por el principio de **segregación de funciones**. Si el mismo rol operativo o propietario que modifica o autoriza cambios en **clientes** controlara también quién accede, borra o modifica la tabla de auditoría **auditoria.cambios_clientes**, podría ocultar modificaciones no autorizadas o alterar la evidencia sin contrapeso.

2. **¿Quién debería poder leer las bitácoras y la vista **dba.bitacora**? Relaciónalo con lo observado en el LAB-01 (secretos en la bitácora).**  
   Únicamente el **DBA** (para administración técnica) y **Auditoría Interna / Seguridad** (para verificación y conciliación), nunca usuarios aplicativos ni **PUBLIC**. Como se observó en el LAB-01 (y se reproduce en la línea 26 de la bitácora actual con **CREATE ROLE rol_temporal LOGIN PASSWORD 'Temporal_Practica_2026'**), las sentencias DDL registradas por **log_statement = 'mod'** pueden capturar contraseñas en texto claro, además de revelar estructura interna e identificadores de clientes; por ello el esquema **dba** tiene revocados los permisos a **PUBLIC** y cualquier copia exportada debe redactarse antes de entregarse.

3. **¿Qué ocurre con la responsabilidad sobre un dato cuando nadie la tiene asignada? Relaciónalo con el problema inicial de la unidad.**  
   Se produce un **vacío de rendición de cuentas**: se detectan errores (como un RFC incompleto o un cambio sin ticket), nadie sabe si un cambio fue legítimo o indebido, nadie aprueba la corrección ni define cuánto tiempo conservar los registros, y las bitácoras técnicas pierden valor probatorio ante una auditoría porque responden qué pasó, pero no quién responde por ello.
