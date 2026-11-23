He leído la política de uso de IA de la asignatura.

# Declaración de uso de IA · Lab 6 · E024

## Entrada 1
- **Herramienta:** Claude
- **Prompt (literal, copiado tal cual):**
```text
como veo en oracle quien ha bloqueado una cuenta con ACCOUNT LOCK y cuando, la cuenta es APP_ACADEMIA en la pdb FREEPDB1
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):** lo guardé en `scripts/lab6/08-auditoria-inc603.sql`; la consulta es esta:
```sql
SELECT event_timestamp, dbusername, os_username, client_program_name, action_name, sql_text
  FROM unified_audit_trail
 WHERE action_name = 'ALTER USER' AND UPPER(sql_text) LIKE '%APP_ACADEMIA%'
 ORDER BY event_timestamp DESC FETCH FIRST 5 ROWS ONLY;
```
- **Dónde lo usé (parte, script o pregunta):** Parte I, incidente INC-603 (paso 4, confirmar la hipótesis)
- **Propósito (para qué lo necesitaba):** saber quién y cuándo había bloqueado la cuenta de la aplicación antes de desbloquearla, para tener la causa en el postmortem y no quedarme en «estaba bloqueada»
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** busca en la auditoría unificada (UNIFIED_AUDIT_TRAIL) las sentencias ALTER USER cuyo texto menciona APP_ACADEMIA. Saca la hora, el usuario de la base que la lanzó, el usuario del sistema operativo, el programa desde el que se conectó, la acción y el texto de la sentencia. Ordena de la más reciente a la más antigua y se queda con las 5 últimas. Se ejecuta dentro de FREEPDB1 porque la auditoría de una PDB se guarda en la propia PDB. En mi caso salió una fila: SYS, desde sqlplus, `ALTER USER app_academia ACCOUNT LOCK` a las 00:00:07.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** docs/bitacora/lab6/evidencia/script/20261123T000055Z_08-auditoria-inc603.script.log

## Entrada 2
- **Herramienta:** Claude
- **Prompt (literal, copiado tal cual):**
```text
ayudame a ordenar los postmortems de la guardia con la plantilla del lab (deteccion, impacto, diagnostico, causa raiz, intervencion, validacion, accion preventiva), te paso mis notas de cada incidente
```
- **Código recibido (el fragmento, o la ruta del archivo donde está):** no aplica
- **Dónde lo usé (parte, script o pregunta):** docs/bitacora/lab6-guardia.md (Parte I.5)
- **Propósito (para qué lo necesitaba):** pasar las notas que tomé durante los tres incidentes a los siete campos de la plantilla del postmortem
- **Qué hace (con mis palabras; línea a línea si es SQL corto):** no es código. Me ayudó a colocar en cada campo lo que había anotado. Las horas, los SID, las sentencias y los valores son los de mis evidencias `*_08-*`.
- **Evidencia de ejecución (archivo de docs/bitacora/lab6/evidencia con mi cabecera):** no aplica
