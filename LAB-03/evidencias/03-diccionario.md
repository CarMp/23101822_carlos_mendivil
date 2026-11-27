# Actividad 3 — Diccionario de datos operativo (**public.clientes**)

**Fuente técnica:** [02-comentarios-diccionario.sql](../sql/02-comentarios-diccionario.sql) y exportación CSV en [diccionario-clientes.csv](diccionario-clientes.csv).  
*(Nota: En la Actividad 7 se añadió posteriormente la columna **canal_alta VARCHAR(20)** mediante el cambio **CAM-2026-014**, también documentada con **COMMENT ON COLUMN**).*

## Atributos que el motor no conoce (complemento de gobierno)

| Columna | Clasificación (Unidad II) | Finalidad | Control aplicado | ¿Cambios auditados? | Regla de calidad |
|---|---|---|---|---|---|
| **id** | Identificador técnico interno | Llave primaria subrogada para integridad referencial | **PRIMARY KEY** (**BIGSERIAL**); solo lectura operativa | Sí, en **auditoria.cambios_clientes** (**id_cliente**) | Único, no nulo, generado por secuencia |
| **nombre** | Dato personal (identificador directo) | Identificación nominal del cliente | Acceso mínimo (**app_ventas**, **soporte_ana** en **E2**) | Sí, **trg_auditoria_clientes** + **log_statement='mod'** | No nulo; formato homogéneo de nombre |
| **correo** | Dato personal (contacto) | Notificaciones y contacto comercial | Acceso mínimo; pendiente unicidad funcional | Sí, **trg_auditoria_clientes** | Formato RFC-like **^[^@\s]+@[^@\s]+\.[^@\s]+$** y unicidad sobre **lower(correo)** |
| **telefono** | Dato personal (contacto) | Seguimiento comercial y soporte | Acceso mínimo (**E2**); vista enmascarada recomendada (U2) | Sí, **trg_auditoria_clientes** | Longitud de 10 dígitos numéricos |
| **rfc** | Dato personal / fiscal | Facturación electrónica y cumplimiento tributario | Vista enmascarada para soporte (U2, pendiente de desplegar en esta instancia) | Sí, **trg_auditoria_clientes** (excepto si se desactiva trigger) | Formato **^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$** |
| **edad** | Dato personal | Analítica agregada de perfil de clientes | Acceso controlado por rol | Sí, **trg_auditoria_clientes** | Rango **18 <= edad <= 120** |
| **ciudad** | Dato de localización general | Segmentación geográfica y logística | Acceso estándar de roles autorizados | Sí, **trg_auditoria_clientes** | Catálogo / normalización de acentos y nombres |
| **codigo_postal** | Dato de localización | Facturación fiscal y cobertura de envíos | Acceso estándar de roles autorizados | Sí, **trg_auditoria_clientes** | 5 dígitos numéricos (**^[0-9]{5}$**) |
| **fecha_alta** | Metadato de negocio | Control de antigüedad y cohortes | Valor por defecto **CURRENT_DATE**, **NOT NULL** | Sí, **trg_auditoria_clientes** | Fecha válida no nula |
| **segmento** | Clasificación comercial | Asignación de nivel de servicio y descuentos | Controlado por **app_ventas** y Gerencia Comercial | Sí, **trg_auditoria_clientes** | Dominio controlado (**retail**, **pyme**, **corporativo**) |
| **canal_alta** (Act. 7) | Metadato comercial | Trazabilidad del canal de adquisición | Agregado bajo folio **CAM-2026-014** (**POL-06**) | Sí, **trg_auditoria_clientes** | Catálogo de canales autorizados |

## Respuestas a las preguntas de análisis

1. **¿Qué ventaja tiene guardar el significado en **COMMENT** en lugar de solo en un documento aparte?**  
   Que la descripción vive **junto al objeto dentro del propio SGBD** (**pg_description**, consultable vía **col_description** e **information_schema**): cualquier DBA, desarrollador o herramienta cliente que inspeccione la tabla obtiene su definición actualizada al instante, evitando que la documentación quede desfasada u olvidada en un archivo externo.

2. **¿Quedaron registrados los **COMMENT** en la bitácora? ¿Con qué nivel de **log_statement**?**  
   **Sí.** En la instancia **dba-u3-pg** con **log_statement = 'mod'**, las 11 sentencias **COMMENT** de la Actividad 3 quedaron registradas en las líneas **60 a 70** de [E5-bitacora-postgresql.log](E5-bitacora-postgresql.log) (y las de la Actividad 7 en las líneas **89** y **103**), porque en PostgreSQL **log_statement = 'mod'** registra todas las sentencias DDL además de las de modificación de datos.

3. **¿Qué información del diccionario debe mantenerse fuera del motor? ¿Por qué?**  
   Las **políticas de acceso detalladas, la clasificación formal de sensibilidad, el propietario de negocio asignado, las justificaciones de finalidad legal y la matriz de controles compensatorios o brechas**. Aunque **COMMENT** acepta texto libre, el SGBD no gobierna flujos de aprobación ni custodia normativa; además, exponer mapas de vulnerabilidades o controles pendientes en metadatos legibles por usuarios de base de datos facilitaría el reconocimiento interno a un actor no autorizado.
