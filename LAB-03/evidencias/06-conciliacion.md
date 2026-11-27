# Actividad 7 — Registro de cambios y conciliación

**Script ejecutado:** 04-registro-cambios.sql
**Bitácora contrastada:** Vista **dba.bitacora** / archivo redactado [E5-bitacora-postgresql.log](E5-bitacora-postgresql.log).

## Verificación de solicitud autorizada (**CAM-2026-014**)

```text
    folio     |   aprobado_por    | dentro_de_ventana
--------------+-------------------+-------------------
 CAM-2026-014 | Comité de cambios | t
```

## Tabla de conciliación (Bitácora **dba.bitacora** vs. **gobierno.solicitudes_cambio**)

| Línea **dba.bitacora** | Momento (UTC) | Usuario | Sentencia observada | Folio que lo autoriza | ¿Autorizado? | Hallazgo / Clasificación |
|---|---|---|---|---|---|---|
| (Ausente) | Previo a línea 20 | **postgres** | **CREATE OR REPLACE VIEW dba.bitacora ...** (y **init.sql** inicial) | Ninguno | No documentado | **Hueco de evidencia (Media):** Se ejecutó cuando **log_statement** aún valía **none**; no quedó huella en bitácora. |
| **23** | **2026-11-27 03:11:25.465** | **postgres** | **REVOKE UPDATE ON public.clientes FROM soporte_ana;** | Ninguno | Preparación LAB-01 | **Preparación de laboratorio** (ajuste de mínimo privilegio hacia **E2**). En operación real requeriría folio de **POL-01**/**POL-06**. |
| **24** | **2026-11-27 03:11:25.466** | **postgres** | **GRANT UPDATE ON public.clientes TO app_ventas;** | Ninguno | Preparación LAB-01 | **Preparación de laboratorio** (en producción sin folio sería hallazgo de acceso no autorizado). |
| **25** | **2026-11-27 03:11:25.467** | **postgres** | **ALTER TABLE public.clientes ADD COLUMN segmento VARCHAR(20);** | Ninguno | Preparación LAB-01 | **Preparación de laboratorio** (cambio de esquema de LAB-01 sin registro previo en **gobierno.solicitudes_cambio**). |
| **26** | **2026-11-27 03:11:25.469** | **postgres** | **CREATE ROLE rol_temporal LOGIN PASSWORD '<REDACTED>';** | Ninguno | No autorizado | **Hallazgo (Alta):** Creación de rol sin folio y exposición de contraseña en texto claro dentro de la bitácora del servidor (mitigada en exportación **E5**). |
| **34** (+35-36) | **2026-11-27 03:11:25.707** | **app_ventas** | **ALTER TABLE public.clientes DISABLE TRIGGER trg_auditoria_clientes;** (**ERROR: must be owner**) | Ninguno | No autorizado (rechazado) | **Hallazgo (Alta):** Intento no autorizado de un usuario aplicativo por deshabilitar el control de auditoría; bloqueado por privilegios mínimos. |
| **40** | **2026-11-27 03:11:25.821** | **postgres** | **ALTER TABLE public.clientes DISABLE TRIGGER trg_auditoria_clientes;** | Ninguno | **No** | **Hallazgo crítico / Alta:** Desactivación efectiva del disparador de auditoría por el superusuario, seguida del cambio directo al RFC de María García (**id = 2**, línea 41) sin rastro en **auditoria.cambios_clientes**. |
| **42** | **2026-11-27 03:11:25.824** | **postgres** | **ALTER TABLE public.clientes ENABLE TRIGGER trg_auditoria_clientes;** | Ninguno | **No** | Parte del mismo incidente de evasión temporal de auditoría (línea 40). |
| **60–70** | **2026-11-27 03:12:26.885–898** | **postgres** | **COMMENT ON TABLE / COLUMN public.clientes ...** | Actividad 3 (LAB-03) | Documentación operativa | Cambio de metadatos descriptivos ejecutado dentro de la práctica de diccionario; registrado por **log_statement = 'mod'**. |
| **77–89** | **2026-11-27 03:13:23.082–094** | **postgres** | **CREATE SCHEMA gobierno; CREATE TABLE gobierno.solicitudes_cambio ...** | Actividad 7 (LAB-03) | Implantación de control | Creación de la infraestructura base de registro de cambios (anterior a la existencia del propio registro). |
| **102** (+103) | **2026-11-27 03:13:23.098** | **postgres** | **ALTER TABLE public.clientes ADD COLUMN IF NOT EXISTS canal_alta VARCHAR(20);** | ****CAM-2026-014**** | **Sí** (**dentro_de_ventana = t**) | **— (Conforme):** Cambio aprobado por Comité de cambios y ejecutado dentro de su ventana autorizada. |

## Respuestas a las preguntas de análisis

1. **¿Qué cambios de la bitácora no tienen folio? Clasifícalos: ¿son de preparación del laboratorio o representan hallazgos?**  
   - **Preparación del laboratorio / arranque de controles:** **REVOKE**/**GRANT** iniciales (líneas 23–24), **ADD COLUMN segmento** (línea 25), **COMMENT ON** (líneas 60–70) y creación de **gobierno.solicitudes_cambio** (líneas 77–89).  
   - **Hallazgos reales de auditoría:** **CREATE ROLE rol_temporal** con contraseña en texto claro (línea 26), el intento fallido de **app_ventas** por deshabilitar el trigger (línea 34) y la desactivación efectiva del trigger por **postgres** para modificar el RFC de María García sin dejar rastro en **auditoria.cambios_clientes** (líneas 40–42).

2. **La desactivación del disparador del LAB-01 (Actividad 14), ¿qué tan grave es como hallazgo? ¿Por qué? ¿Qué distingue la línea 163 (aquí línea 34) de la 169 (aquí línea 40)?**  
   Es de severidad **Alta**, porque anula el control específico diseñado para auditar quién y cómo modificó los datos sensibles de **clientes** (**valores_antes** y **valores_despues**), creando un punto ciego deliberado en **auditoria.cambios_clientes**.  
   La diferencia clave es que en la **línea 34** (equivalente a la 163 del PDF) el usuario **app_ventas** **falló** (**ERROR: must be owner of table clientes**), demostrando que el principio de mínimo privilegio impidió al aplicativo evadir el control; mientras que en la **línea 40** (equivalente a la 169 del PDF) el superusuario **postgres** **sí logró deshabilitarlo** y ejecutar el **UPDATE** sobre **id = 2** (línea 41) antes de volver a activarlo (línea 42).

3. **¿Qué limitación tiene esta conciliación si **log_statement** estuvo en **none** durante algún periodo?**  
   La conciliación pierde **completitud**: cualquier DDL, **GRANT**, **REVOKE** o modificación ejecutada mientras **log_statement = 'none'** (como ocurrió con la creación de la vista **dba.bitacora**) simplemente no aparece en el archivo de registro, impidiendo demostrar por ausencia de evidencia que no ocurrieron otros cambios no autorizados en ese lapso.

4. **¿Quién debería realizar la conciliación: el DBA que hizo los cambios u otra persona?**  
   **Otra persona independiente** (como **Auditoría Interna** o un revisor distinto al DBA ejecutor), por el principio de **segregación de funciones**. El DBA puede preparar y exportar las consultas con hash, pero quien ejecutó los cambios y tiene privilegios de superusuario no debe ser juez único de su propio cumplimiento.
