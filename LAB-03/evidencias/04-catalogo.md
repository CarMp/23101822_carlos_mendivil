# Actividad 4 — Catálogo mínimo de datos

**Fuente técnica:** [03-inventario-tablas.sql](../sql/03-inventario-tablas.sql) ejecutado tras **ANALYZE;** sobre **comercial** en **dba-u3-pg**.

## Salida técnica del inventario en PostgreSQL 16 (**dba-u3-pg**)

```text
  esquema  |       tabla        | propietario_tecnico | filas_estimadas | tamano |                                                                 descripcion
-----------+--------------------+---------------------+-----------------+--------+----------------------------------------------------------------------------------------------------------------------------------------------
 auditoria | cambios_clientes   | postgres            |              15 | 32 kB  |
 gobierno  | solicitudes_cambio | postgres            |               1 | 32 kB  | Registro de solicitudes de cambio en la base comercial. Propietario: Comité de cambios. Custodio: DBA. Evidencia de POL-06.
 public    | clientes           | postgres            |               8 | 24 kB  | Clientes de Comercializadora Norte. Propietario: Gerencia Comercial. Custodio: DBA. Clasificación: confidencial (contiene datos personales).
```

Nota: La vista **dba.bitacora** (**relkind = 'v'**) también existe en el catálogo del motor (**propietario_tecnico = postgres**) y se incorpora como activo de gobierno aunque no aparezca en el filtro **relkind = 'r'**.

## Catálogo integrado (PostgreSQL 16 y MongoDB 7)

| ID | Conjunto de datos | Motor | Ubicación | Propietario (Data Owner) | Custodio | Clasificación | Volumetría observada |
|---|---|---|---|---|---|---|---|
| CAT-01 | Clientes | PostgreSQL 16 | **dba-u3-pg (localhost:5432)** / **comercial** / **public.clientes** | Gerencia Comercial | DBA | Confidencial (datos personales) | 8 filas (**24 kB**) |
| CAT-02 | Auditoría de clientes | PostgreSQL 16 | **dba-u3-pg (localhost:5432)** / **comercial** / **auditoria.cambios_clientes** | Auditoría Interna | DBA | Confidencial (contiene **valores_antes** / **valores_despues** con datos personales) | 15 filas (**32 kB**) |
| CAT-03 | Registro de cambios | PostgreSQL 16 | **dba-u3-pg (localhost:5432)** / **comercial** / **gobierno.solicitudes_cambio** | Comité de Cambios | DBA | Uso interno / Gobierno | 1 fila (**32 kB**) |
| CAT-04 | Clientes (tienda) | MongoDB 7 | **dba-u3-mongo (localhost:27017)** / **comercial** / **clientes** | Gerencia de Comercio Electrónico / Gerencia Comercial | DBA | Confidencial (datos personales) | 3 documentos |
| CAT-05 | Perfilado | MongoDB 7 | **dba-u3-mongo (localhost:27017)** / **comercial** / **system.profile** | Oficial de Seguridad / Auditoría Interna | DBA | Uso interno / Confidencial (puede contener filtros con datos personales) | 3 documentos capturados (colección capped de 1 MB) |
| CAT-06 | Vista de bitácora | PostgreSQL 16 | **dba-u3-pg (localhost:5432)** / **comercial** / **dba.bitacora** | Oficial de Seguridad / Auditoría Interna | DBA | Restringida (operación y posibles secretos sin redactar) | 125 líneas exportadas en **E5** |
| CAT-07 | Instantáneas de privilegios | MongoDB 7 | **dba-u3-mongo (localhost:27017)** / **auditoria** / **instantaneas_privilegios** | Auditoría Interna | DBA | Uso interno / Seguridad | 1 documento |

## Respuestas a las preguntas de análisis

1. **¿Por qué CAT-02 y CAT-05 contienen datos personales aunque su propósito sea la auditoría?**  
   Porque **auditoria.cambios_clientes** (CAT-02) guarda instantáneas JSONB (**valores_antes** y **valores_despues**) de la fila modificada en **clientes** para poder reconstruir qué cambió, y **system.profile** (CAT-05) captura el documento **command** completo de consultas y actualizaciones (como filtros por correo, nombre o teléfono). Por ello, la auditoría hereda la clasificación de confidencialidad de los datos que monitorea.

2. **¿Qué pasa si CAT-01 y CAT-04 tienen propietarios distintos y el RFC de un cliente difiere entre ambos motores?**  
   Se rompe el principio de **fuente única de verdad** (Single Source of Truth): cada área asumirá que su registro es el correcto (por ejemplo, en nuestro entorno **María García** tiene **GAMA900412XY9** en PostgreSQL y **GAMA900412XY8** en MongoDB), generando errores de facturación, rechazo fiscal o entregas fallidas sin un responsable claro que resuelva la discrepancia.

3. **¿Qué información del catálogo cambia con más frecuencia y quién debe actualizarla?**  
   Las **métricas operativas** (filas estimadas, tamaño en disco, nuevas tablas/colecciones y estado de perfilado) cambian constantemente y debe actualizarlas el **DBA** (custodio) mediante consultas periódicas al catálogo del sistema. Los cambios en **propietarios, clasificación o creación de nuevos conjuntos** los aprueba el propietario correspondiente y se reflejan en el catálogo tras cada solicitud de cambio.
