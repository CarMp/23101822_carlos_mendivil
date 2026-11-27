# Actividad 1 — Calidad de datos desde la operación

**Fuente de ejecución:** [01-verificaciones-calidad.sql](../sql/01-verificaciones-calidad.sql) sobre la base **comercial** en **dba-u3-pg** (PostgreSQL 16).
Los registros simulados (**id = 7** y **id = 8**) se conservan intactos en **public.clientes** como parte de la evidencia de auditoría.

## Resultados observados en PostgreSQL

- **Duplicados por correo normalizado:** **ana.lopez@example.test** (2 registros: **id** **1, 7**).
- **RFC no válido o ausente:** **id = 7** (**LOAA850315AB**, 12 caracteres — falta homoclave), **id = 8** (**NULL**).
- **Correo no válido:** **id = 8** (**sin-correo**).
- **Edad fuera de rango (**< 18** o **> 120**):** **id = 8** (**-3**).
- **Completitud:** **total = 8**, **sin_telefono = 0**, **sin_rfc = 1** (**id = 8**).
- **Teléfono / Código postal fuera de formato:** **id = 8** (**telefono = '667'**, **codigo_postal = '8000'**).

## Registro de hallazgos de calidad

| # | Hallazgo | Registros | Regla de calidad | ¿Quién decide la corrección? | Acción propuesta |
|---|---|---|---|---|---|
| C1 | Posible cliente duplicado (diferencia de mayúsculas y tilde en nombre/ciudad) | **1, 7** | Unicidad del correo (**lower(correo)**) | Gerencia Comercial (propietario del dato) | Confirmar con el cliente si corresponde a la misma persona; fusionar/desactivar el duplicado tras aprobación y evaluar índice único sobre **lower(correo)**. |
| C2 | RFC incompleto (12 caracteres, falta homoclave) | **7** | Formato del RFC (**^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$**) | Gerencia Comercial / Área de Facturación | Solicitar constancia de situación fiscal al cliente para capturar el RFC oficial y aprobar la actualización o restricción **CHECK**. |
| C3 | Correo con formato inválido, RFC ausente (**NULL**), edad negativa (**-3**), teléfono incompleto (**667**) y CP de 4 dígitos (**8000**) | **8** | Formato de correo, rango de edad (**18..120**), formato de teléfono/CP y completitud de RFC | Gerencia Comercial (propietario del dato) y responsable de captura/ventas | Contactar al cliente para validar y completar sus datos reales; no sobrescribir desde DBA sin instrucción formal y agregar validaciones en aplicación y BD. |
| C4 | Ausencia de reglas preventivas (**CHECK** / **UNIQUE** funcional) en **public.clientes** | Tabla completa | Integridad de dominio y unicidad | Gerencia Comercial (aprueba regla de negocio) y DBA (implementa) | Definir catálogo de restricciones aceptadas (formato RFC, correo, rango de edad, índice único en **lower(correo)**) mediante solicitud de cambio formal. |

## Respuestas a las preguntas de análisis

1. **¿Por qué el DBA no debe corregir por su cuenta el RFC del registro 7?**  
   Porque el DBA es **custodio**, no **propietario** del dato. El DBA puede detectar y reportar el error técnico de formato, pero no conoce ni tiene autoridad para decidir cuál es el RFC oficial correcto del cliente ni la información fiscal de respaldo; modificarlo unilateralmente alteraría datos de negocio sin autorización y rompería la trazabilidad de responsabilidades.

2. **¿Qué restricción (**CHECK**, **UNIQUE**) habría evitado cada hallazgo? ¿Quién debería aprobar agregarla?**  
   - **C1 (correo duplicado):** un índice único funcional **CREATE UNIQUE INDEX uq_clientes_correo_lower ON public.clientes (lower(correo));** (ya que **UNIQUE(correo)** simple no evita diferencias de mayúsculas/minúsculas).  
   - **C2 (RFC inválido):** **CHECK (rfc ~ '^[A-ZÑ&]{3,4}[0-9]{6}[A-Z0-9]{3}$')**.  
   - **C3 (correo inválido, edad negativa, teléfono/CP inválidos):** **CHECK (correo ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')**, **CHECK (edad BETWEEN 18 AND 120)**, **CHECK (telefono ~ '^[0-9]{10}$')** y **CHECK (codigo_postal ~ '^[0-9]{5}$')**.  
   La incorporación de estas restricciones debe aprobarla el **propietario del dato (Gerencia Comercial)** —y el Comité de Cambios para producción— porque pueden rechazar capturas incompletas de operación (por ejemplo, si el negocio permite prospectos sin RFC al alta).

3. **Si el DBA corrige un dato, ¿qué mecanismo del LAB-01 (Parte B) dejará evidencia del cambio?**  
   El disparador **trg_auditoria_clientes** sobre **public.clientes**, que ejecuta la función **auditoria.fn_registrar_cambio_cliente()** y registra automáticamente en **auditoria.cambios_clientes** el **usuario_sesion**, **momento**, **aplicacion**, **operacion**, **id_cliente**, **valores_antes** y **valores_despues**, complementado por la bitácora del servidor PostgreSQL cuando **log_statement = 'mod'**.
