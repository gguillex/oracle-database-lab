# Lab 4 · Respuestas

Cada respuesta cita la evidencia (archivo y valor) de `docs/bitacora/lab4/evidencia/`.

## Puntos de control y retos por Parte

### Parte A · Punto de control: Antes de seguir

> Anota en tu archivo de respuestas cuántos archivos salieron como FUERA y por qué Oracle los creó ahí. Si todo sale "dentro", tu imagen enlaza $ORACLE_HOME/dbs con el volumen: anótalo también.

Respuesta:

0 archivos FUERA. Todos quedaron dentro porque `$ORACLE_HOME/dbs` está enlazado a `/opt/oracle/oradata/dbconfig/FREE/dbs`, que pertenece al volumen persistente. Evidencia: inventario de la Parte A.

### Parte A · Reto: Tu primer informe de diagnóstico

> Imagina que este entorno es de un cliente. Escribe en docs/bitacora/lab4-respuestas.md un informe de cinco líneas como máximo: qué encontraste, qué riesgo tiene cada hallazgo (alto, medio, bajo) y en qué orden lo corregirías. Justifica el orden. Así empiezan los informes reales de auditoría de una base.

Respuesta:

Riesgo alto: los archivos de control están en la misma carpeta y podrían perderse juntos; riesgo medio: el ADR está fuera del volumen y se perderían trazas al recrear el contenedor; riesgo bajo: la configuración de creación de archivos depende de rutas explícitas. Primero aseguraría copias externas de control y datos, después persistiría el ADR y configuraría `DB_CREATE_FILE_DEST`. La copia fría actual es consistente y su SHA-256 se verifica correctamente.

### Parte B · Reto: Mínimo privilegio, de verdad

> Un compañero propone dar a C##OPS_RO el rol DBA "para que no le falte nada". Escribe en tus respuestas dos riesgos concretos de esa decisión y qué privilegio exacto le darías si necesitara leer el alert log (pista: lo harás en la Parte J con 11-ampliar-ops-ro.sql, y la verificación final comprueba que la cuenta no tiene privilegios ANY de escritura).

Respuesta:

Conceder DBA permitiría modificar objetos y configuración más allá de lo necesario y aumentaría el impacto de una cuenta comprometida. Para leer el alert log basta con `GRANT SELECT ON SYS.V_$DIAG_ALERT_EXT TO C##OPS_RO;`, además de sus privilegios de lectura ya concedidos. La verificación final confirmó cero privilegios ANY de escritura.

### Parte C · Reto: Que no vuelva a pasar

> Propón y aplica en tu entorno una medida que impida que un futuro CREATE TABLESPACE con ruta relativa vuelva a dejar archivos fuera del volumen. Pista: DB_CREATE_FILE_DEST y Oracle Managed Files (OMF). Escribe el comando, su SCOPE y qué cambiaría en el siguiente CREATE TABLESPACE tbs_x; sin cláusula DATAFILE. No olvides que es un cambio de configuración: va en su propio commit.

Respuesta:

Ejecutaría `ALTER SYSTEM SET db_create_file_dest='/opt/oracle/oradata/FREE' SCOPE=BOTH;` conectado como SYSDBA en CDB$ROOT, si esa ruta es la ubicación persistente elegida. Es un cambio de configuración y debe registrarse en su propio commit de trabajo. Después, `CREATE TABLESPACE tbs_x` sin cláusula DATAFILE usaría Oracle Managed Files dentro de ese destino, evitando una ruta relativa fuera del volumen. En este entorno `db_create_file_dest` estaba vacío.

### Parte E · Punto de control: Explica cada error con tus palabras

> ORA-01507 en NOMOUNT: v$database lee el control file, que aún no está abierto. Pero v$parameter sí responde: los parámetros ya están en la memoria de la instancia.

Respuesta:

En **NOMOUNT**, Oracle lee el SPFILE, reserva la SGA e inicia los procesos; `v$parameter` responde porque los parámetros ya están en memoria. `v$database` devuelve **ORA-01507** porque todavía no se ha abierto el control file. En **MOUNT**, Oracle abre los control files y conoce la estructura de la base —en la evidencia, los 16 datafiles—, pero aún no abre los datafiles para permitir consultas al diccionario; por eso `SELECT ... FROM DBA_TABLES` devuelve **ORA-01219**. En **OPEN**, se abren los datafiles y redo y ya se puede consultar el diccionario y los datos.

### Parte E · Reto: El parte del reinicio

> Tu responsable te pide un resumen del último reinicio para el informe semanal. Usando solo el alert log (o v$diag_alert_ext desde la Parte J), responde en tus respuestas: ¿a qué hora se pidió la parada, cuánto tardó en abrir la base, hubo recuperación de instancia y qué errores aparecieron? Clasifica cada error como "conocido" o "a investigar".

Respuesta:

La parada inmediata se solicitó a las **18:06:20.715 UTC** (OS id `923`) y terminó a las **18:06:26.427**, por lo que duró **5,712 segundos**. El arranque comenzó a las **18:06:26.568** (OS id `925`); el montaje terminó a las **18:06:27.614**, la apertura se inició a las **18:06:27.782** y la PDB `FREEPDB1` quedó abierta en lectura/escritura a las **18:06:28.892**. Desde el inicio del arranque hasta la apertura de la PDB transcurrieron **2,324 segundos**; desde la petición de parada hasta que la PDB quedó abierta, **8,177 segundos**. El alert log registra `Crash Recovery excluding pdb 2 / pdb 3 which was cleanly closed`: hubo comprobación/recuperación de instancia, excluyendo esas PDB cerradas limpiamente. **ORA-00800: conocido**, asociado a los intentos de ajustar la prioridad de VKTM/LGWR en el contenedor. **ORA-27301/27302/27303: no corresponden a este reinicio**: el alert log los fecha el **2026-07-05 22:02:54**, durante la construcción de la imagen, precedidos de `ORA-07427: spstp: cannot change directory to dbs.`

### Parte F · Reto: Una petición de cambio (change request) de verdad

> Un equipo de desarrollo pide subir open_cursors a 1000 "porque les sale ORA-01000". Antes de tocar nada, escribe en tus respuestas la petición de cambio como la presentarías en una empresa: valor actual y de dónde sale, valor propuesto, SCOPE y por qué, cómo lo pruebas, cómo lo deshaces (rollback) y qué evidencia guardas. Pista: ORA-01000 suele delatar cursores que la aplicación no cierra; subir el límite solo retrasa el problema.

Respuesta:

Solicitud: elevar `open_cursors` de 300 a 1000 para investigar ORA-01000. El valor observado era 300 en memoria y SPFILE. Antes del cambio comprobaría si la aplicación cierra cursores y mediría `V$OPEN_CURSOR` y `V$SQL`. Probaría en entorno controlado `ALTER SYSTEM SET open_cursors=1000 SCOPE=BOTH;`, si la política de cambios lo permite, y repetiría la carga comparando errores, cursores y consumo. Rollback: `ALTER SYSTEM SET open_cursors=300 SCOPE=BOTH;`. Guardaría solicitud aprobada, valores antes/después, SQL ejecutado y resultados. Subir el límite no sustituye corregir fugas de cursores.

### Parte G · Punto de control: Interpreta el experimento

> ¿Por qué las lecturas lógicas son iguales en las dos rondas? (Pista: toda lectura física termina en una lógica: el bloque se trae a la caché y desde ahí se lee.)

Respuesta:

En esta ejecución las lecturas lógicas **no fueron iguales**: la primera ronda tuvo 463 lógicas y 267 físicas; la segunda, 247 lógicas y 0 físicas. La primera lectura tuvo que traer bloques desde almacenamiento y también leerlos lógicamente; en la segunda, los bloques necesarios ya estaban en caché. Además, las cifras de lecturas lógicas son el total de accesos a buffers que Oracle necesitó en cada ejecución y pueden variar entre rondas por el estado de la caché y el trabajo realizado; no hay que afirmar que sean iguales si la medición muestra 463 y 247.

### Parte G · Punto de control: Lee la salida como un DBA

> Las 60 000 matrículas necesitaban unos 2,5 MB para ordenarse en memoria (KB_OPTIMO). Con PGA automática los tuvo (OPTIMAL, 0 KB en TEMP, 40 ms). Con 64 KB, Oracle escribió 3 MB en TEMP y los releyó 6 veces (6 PASSES): el doble de tiempo con una tabla pequeña; con una grande, la diferencia es de minutos.

Respuesta:

Con PGA automática la ordenación quedó en OPTIMAL, usó 0 KB de TEMP y tardó 10 ms. Limitando la PGA a 64 KB necesitó 6 PASSES, escribió 2048 KB en TEMP y tardó 590 ms. La falta de memoria obliga a volcar datos al disco y releerlos, aumentando mucho el tiempo.

### Parte G · Reto: Encontrar a los culpables en una base real

> Escribe una consulta sobre V$SQL que agrupe por force_matching_signature y muestre las firmas con más de 50 cursores distintos: son las sentencias que la aplicación ejecuta con literales. Ejecútala justo después de 08-parse-y-pga.sql (deberías encontrar la de lab4_literal) y guárdala como scripts/lab4/08-reto-literales.sql con su salida en la evidencia. Es una consulta que usarás en cualquier empresa el primer día que te digan "la CPU de la base está al 100 %".

Respuesta:

```sql
SELECT force_matching_signature, COUNT(*) AS cursores,
       COUNT(DISTINCT sql_id) AS sql_distintos
FROM v$sql
WHERE force_matching_signature <> 0
GROUP BY force_matching_signature
HAVING COUNT(DISTINCT sql_id) > 50
ORDER BY cursores DESC;
```
La evidencia encontró una firma con 275 cursores asociada a `lab4_literal`, visible desde la raíz con `con_id=3`. Esto indica muchas sentencias que solo cambian los literales.

### Parte H · Reto: La sesión que más consume

> Abre dos terminales. En la primera, entra como SYSDBA (docker exec -it oralab-26ai sqlplus / as sysdba, ALTER SESSION SET CONTAINER = FREEPDB1;) y lanza una consulta que tarde unos segundos, por ejemplo SELECT COUNT(*) FROM admin_academia.aca_matriculas a, admin_academia.aca_matriculas b WHERE a.matricula_id < 3000;. Mientras corre, desde la segunda y como C##OPS_RO, localiza su SID, su SPID en Linux y cuánta PGA está usando (v$session + v$process). Anota los tres valores y la consulta que usaste: es la primera pregunta de cualquier diagnóstico de rendimiento.

Respuesta:

La consulta larga se ejecutó como `SYS` dentro de `FREEPDB1` con el filtro `a.matricula_id < 30000` y devolvió **1.799.940.000 filas en 52,57 s**. Mientras estaba activa, la sesión identificada fue **SID 56**, **SERIAL# 21925**, **CON_ID 3**, usuario `SYS`, **SPID 7304**, con **3,3 MB de PGA usada** y **3,7 MB asignados**. La consulta de diagnóstico, ejecutada desde la segunda terminal como `C##OPS_RO` mientras la primera consulta seguía corriendo, fue:
```sql
SELECT s.sid, s.serial#, s.con_id, s.username,
       p.spid, p.pga_used_mem, p.pga_alloc_mem
FROM v$session s
JOIN v$process p ON p.addr = s.paddr
WHERE s.status = 'ACTIVE'
  AND s.username IS NOT NULL
ORDER BY p.pga_used_mem DESC;
```
Evidencia: `script/…_09-reto-sesion.script.log`.

### Parte I · Punto de control: Interpreta tu salida

> ¿Por qué en el bloque 1 hay una fila con CON_ID 0 en V$LOG? ¿Por qué el redo no pertenece a ninguna PDB?

Respuesta:

`V$LOG` muestra `CON_ID=0` porque los grupos de redo son recursos comunes de la CDB, no pertenecen a una PDB concreta. Registran cambios del conjunto de la base de datos y permiten recuperar la CDB de forma coherente.

### Parte I · Reto: Diseña el acceso de un auditor externo

> Una auditora debe leer, durante una semana, las tablas de ADMIN_CLINICA y nada más, sin poder modificar datos. Escribe en tu bitácora el CREATE USER (¿común o local?, ¿en qué contenedor?), el GRANT mínimo y la sentencia que lo revoca el último día. Justifica cada decisión con lo observado en I.2. No lo ejecutes: es un diseño.

Respuesta:

Diseño en `FREEPDB1`: crear un usuario local y conceder `CREATE SESSION` más `READ` únicamente sobre cada tabla autorizada de `ADMIN_CLINICA`; no conceder permisos de escritura ni un privilegio más amplio de lo necesario. Ejemplo: `CREATE USER audit_clinica IDENTIFIED BY "<contraseña segura>"; GRANT CREATE SESSION TO audit_clinica; GRANT READ ON ADMIN_CLINICA.<tabla> TO audit_clinica;`. El último día se revocan los `READ` concedidos y, si la cuenta ya no debe existir, se ejecuta `DROP USER audit_clinica CASCADE`. La evidencia registra ORA-00942 al intentar acceder a `ADMIN_CLINICA`, por lo que antes de conceder permisos hay que comprobar el nombre real del esquema/las tablas y su existencia; no se concluye que el privilegio de esquema haya fallado como concepto.

### Parte J · Punto de control: Interpreta tu salida

> ¿Por qué el password file aparece como archivo relacionado si sin él no puedes entrar como SYSDBA por red?

Respuesta:

El password file es un archivo relacionado con la autenticación administrativa, no un archivo de datos de la base. Permite autenticar conexiones administrativas por red, por ejemplo como SYSDBA, y comprobar qué usuarios tienen privilegios administrativos.

### Parte J · Reto: Plan de copia a partir del inventario

> Con tu evidencia 11 calcula cuántos MB tendría una copia en frío completa (datafiles + control files + redo + SPFILE + password file) y cuáles de esos archivos sobrarían en una copia con RMAN. Escríbelo en la bitácora.

Respuesta:

La copia en frío que incluye los **16 datafiles (3974 MB)**, los **2 control files (36 MB)**, los **3 redo online (600 MB)**, el SPFILE (**3584 bytes**) y el password file (**2048 bytes**) suma aproximadamente **4610,005 MB** (unos **4,61 GB**, antes de redondear los tamaños pequeños). Si además se incluyeran los **5 redo archivados (353 MB)**, el inventario ascendería a aproximadamente **4963,005 MB**. Los **3 tempfiles (60 MB)** no se incluyen en esa suma; para RMAN son prescindibles como copia de contenido porque se pueden recrear. Los redo online y los archivados cumplen funciones distintas: los archivados se incluyen según la estrategia de recuperación y no deben confundirse con los redo online. Evidencia: `spool/…_11-archivos.spool.log`, sección 2.

### Parte K · Punto de control: Interpreta tu volcado

> Comprueba que avsp = fseo - fsbo con tus números (en hexadecimal y en decimal).

Respuesta:

`fsbo=0xc6` y `fseo=0x427`. La resta hexadecimal es `0x427 - 0x0c6 = 0x361`, que coincide con `avsp=0x361`. En decimal: 1063 − 198 = 865 bytes.

### Parte K · Reto: Abre otro bloque

> Elige un estudiante con ID mayor que 19 000 (estará en los últimos bloques llenos), averigua su bloque con DBMS_ROWID, cambia el ID en una copia de 12-bloque.sql y compara nrow, avsp y la ITL con los del bloque 782. ¿Ves también la limpieza diferida? Guarda la traza como evidencia extra.

Respuesta:

Elijo el estudiante **19001**, cuyo ROWID es `AAAR2kAAAAAAASKAAD` (fila 3) y cuyo bloque es el **1162**. Para un tablespace `BIGFILE`, hay que indicar el formato en `DBMS_ROWID.ROWID_BLOCK_NUMBER`:
```sql
SELECT DBMS_ROWID.ROWID_OBJECT(rowid) AS objeto,
       DBMS_ROWID.ROWID_RELATIVE_FNO(rowid) AS fichero_relativo,
       DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid, 'BIGFILE') AS bloque,
       DBMS_ROWID.ROWID_ROW_NUMBER(rowid) AS fila
FROM admin_academia.aca_estudiantes
WHERE <columna_ID_real> = 19001;
```
La comparación entre nuestro **bloque 1162** y el **bloque 783** (fila 101; el bloque 782 corresponde al profesor) queda así:

| Dato | Bloque 1162 (ID 19001) | Bloque 783 (ID 101) |
|---|---:|---:|
| ROWID / fila | `AAAR2kAAAAAAASKAAD`, fila 3 | `AAAR2kAAAAAAAMPAAF`, fila 5 |
| `nrow` | 85 | 90 |
| `fsbo / fseo` | `0xbc / 0x421` | `0xc6 / 0x427` |
| `avsp` | `0x365` (869 bytes) | `0x361` (865 bytes) |
| ITL, entrada `0x01` | `0x0008.001.0000027d`, flag `--U-`, Lck 85, FSC `0x0000.005edef` | `0x0008.001.0000027d`, flag `--U-`, Lck 90, FSC `0x0000.005edef` |
| Fila | `tl: 82`, VSIZE 72 | `tl: 78`, VSIZE 68 |

Se comprueba `avsp = fseo - fsbo` en ambos bloques: para el 1162, `0x421 - 0x0bc = 0x365`; para el 783, `0x427 - 0x0c6 = 0x361`. En decimal son 1057 − 188 = 869 bytes y 1063 − 198 = 865 bytes, respectivamente.

**Sí, se observa la limpieza diferida.** Las dos entradas ITL muestran el mismo Xid (`0x0008.001.0000027d`), el mismo flag `--U-` y el mismo SCN (`0x0000.005edef`). Eso indica que la información de la transacción sigue pendiente de limpieza en ambos bloques y Oracle la resolverá cuando corresponda al acceder a ellos.

### Parte L · Reto: Dimensiona ACA_MATRICULAS

> Antes de mirar: predice con la fórmula de la Unidad 3 cuántos bloques ocupa ACA_MATRICULAS (60 000 filas). Después consulta AVG_ROW_LEN y BLOCKS en DBA_TABLES y explica la diferencia con la tabla de L.2. ¿Cuánto tardaría un recorrido completo en un HDD a 150 MB/s?

Respuesta:

Para `ACA_MATRICULAS`, la evidencia real indica **60.000 filas**, `AVG_ROW_LEN (R) = 30` bytes, **370 bloques bajo la HWM**, **384 bloques asignados**, tamaño aproximado de **3 MB** y `PCT_FREE = 10`. Con bloques de 8192 bytes, el recorrido completo debe leer los bloques bajo la HWM; usando los 370 bloques medidos, el volumen lógico de bloques es `370 × 8192 = 3.031.040 bytes`, aproximadamente **2,89 MiB**. En un HDD que sostenga 150 MB/s, el mínimo teórico de transferencia es aproximadamente **0,020 segundos (20 ms)**, sin contar latencia, posicionamiento, sobrecarga de Oracle ni otros costes. La comparación con `ACA_ESTUDIANTES` debe mantener separados los valores medidos: esta última tiene `R = 76`, 244 bloques bajo la HWM y 256 asignados; `ACA_MATRICULAS` tiene `R = 30`, 370 bajo la HWM y 384 asignados.

### Parte N · Reto: Escribe tu informe de autopsia

> Crea docs/bitacora/lab4-autopsia.md con tus propios hallazgos (no copies la tabla de arriba: tu base puede ser distinta). Para cada uno: sección del script, evidencia (el valor exacto), riesgo, acción y prioridad. Termina con un resumen de tres líneas para un jefe que no es técnico.

Respuesta:

El informe de la autopsia está en `docs/bitacora/lab4-autopsia.md`. Sus tres primeros hallazgos son: **(1)** un solo miembro por grupo de redo y los dos control files en el mismo volumen; **(2)** la FRA sin configurar, con los archived logs almacenados en `$ORACLE_HOME/dbs`; y **(3)** Flashback desactivado (`FLASHBACK = NO`) aunque la base está en `ARCHIVELOG`. Estos hallazgos se presentan en ese orden de prioridad en la autopsia.

## Preguntas de comprobación

### Respaldo y diagnóstico (A)

**1. ¿Por qué la copia de la Parte A es consistente? ¿Qué pasaría si se tomara con la base abierta?**

Respuesta:

Una copia en frío tras `SHUTDOWN IMMEDIATE` es consistente porque Oracle ha cerrado la base y vaciado los cambios pendientes antes de copiar. Si se copia con la base abierta, los archivos pueden cambiar durante la copia y quedar en estados distintos; se necesitaría una técnica de backup en caliente compatible.

**2. ¿Para qué sirven manifiesto.txt y SHA256SUMS? ¿Qué comprueba restaurar-estado.sh antes de tocar nada?**

Respuesta:

`manifiesto.txt` registra los metadatos de la copia: el tipo de copia, el número de archivos fuera del volumen y los datos de contexto que escribe `backup-estado.sh` (por ejemplo, `tipo=copia en frio consistente (SHUTDOWN IMMEDIATE)` y `archivos_fuera_del_volumen=0`). No es el listado detallado de archivos. `SHA256SUMS` contiene las sumas SHA-256 de los archivos copiados. Antes de restaurar, `restaurar-estado.sh` ejecuta `sha256sum --check`; si falla la integridad, se detiene antes de vaciar o modificar el volumen, y pide confirmar el nombre del volumen salvo que se use `--si`.

**3. Define RPO y RTO con los datos de tu propia copia.**

Respuesta:

El RPO de esta copia es el punto temporal de la copia: se conserva el estado cerrado capturado alrededor de las 17:46:10 UTC del 26-10-2026. No se puede expresar como pérdida máxima de datos en minutos sin conocer la frecuencia de copias y el objetivo acordado. El RTO no se ha medido porque `restaurar-estado.sh` no se ejecutó.

### Correcciones del Lab 3 (C, D)

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?**

Respuesta:

Los datafiles de V000 se crearon bajo `$ORACLE_HOME/dbs` por usar una ruta relativa y tener `db_create_file_dest` vacío. Configurar `DB_CREATE_FILE_DEST` con un destino persistente y usar OMF habría evitado depender del directorio de trabajo.

**5. ¿Por qué ALTER TABLESPACE ... RENAME DATAFILE no basta para mover un archivo?**

Respuesta:

`ALTER TABLESPACE ... RENAME DATAFILE` cambia la referencia que Oracle guarda, pero no mueve físicamente el archivo. Primero hay que dejar el tablespace offline, moverlo con el sistema operativo, actualizar la ruta en Oracle y volver a ponerlo online.

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?**

Respuesta:

V000 es una migración ya aplicada: editarla alteraría el historial y podría producir resultados distintos en instalaciones nuevas y existentes. La corrección debe añadirse como una nueva migración, V003. En este laboratorio, V000 es `database/migrations/V000__setup_entornos_negocio.sql`; contiene las cinco contraseñas en las líneas 6, 12, 18, 24 y 30. La credencial antigua se invalida rotándola, no borrando una línea del historial versionado. La prueba de conexión con la contraseña antigua devolvió ORA-01017.

**7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?**

Respuesta:

La prueba de persistencia comprueba que la corrección sobrevive a recrear o reiniciar el entorno y no depende solo del estado temporal del contenedor. Se hace después de reubicar para verificar que las rutas nuevas y los datos continúan disponibles.

### Instancia, arranque y parámetros (E, F)

**8. Con tus evidencias: tres datos que pertenecen a la instancia y tres que pertenecen a la base de datos.**

Respuesta:

Instancia: nombre/estado `FREE`, hora de arranque `2026-10-26 18:01:20`, SGA de 1.603.398.928 bytes. Base de datos: DBID `1509902213`, fecha de creación `2026-07-05`, modo `ARCHIVELOG`.

**9. ¿Qué lee Oracle en NOMOUNT, en MOUNT y en OPEN? Relaciónalo con ORA-01507 y ORA-01219.**

Respuesta:

En NOMOUNT se leen parámetros y se inicia la instancia, pero no se abre el control file; por eso `v$database` da ORA-01507. En MOUNT se abre el control file y se conocen los 16 datafiles, pero no se pueden consultar tablas de usuario; `DBA_TABLES` da ORA-01219. En OPEN se abren los archivos y se permite acceder a los datos.

**10. Diferencia entre v$parameter y v$spparameter con el ejemplo de db_files de tu evidencia.**

Respuesta:

`V$PARAMETER` muestra el valor efectivo en memoria; `V$SPPARAMETER` muestra lo almacenado para el arranque siguiente. En la evidencia de `db_files`, el valor en memoria era 200 y el de SPFILE 300. El intento de modificarlo solo en memoria devolvió ORA-02095.

**11. ¿Por qué PROCESSES rechaza el cambio en memoria aunque v$parameter lo marque IMMEDIATE?**

Respuesta:

Aunque `v$parameter` mostraba `ISSYS_MODIFIABLE=IMMEDIATE`, el cambio real de `PROCESSES` falló con ORA-02097 y ORA-02095; cambiar `memory_size` dio ORA-62352. La prueba confirma que el parámetro no se puede aplicar dinámicamente en esa configuración y requiere reinicio/cambio persistente.

### Memoria y procesos (G, H)

**12. ¿Qué modelo de gestión de memoria usa tu instancia? Justifícalo con tres parámetros.**

Respuesta:

La instancia usa gestión automática de la SGA (ASMM), no AMM: `memory_target=0`, `sga_target=1536M` y `pga_aggregate_target=512M`. `db_cache_size=0` deja que Oracle gestione el tamaño de la caché dentro de la SGA.

**13. Explica las cifras de tu experimento de caché: lecturas lógicas, físicas y tasa de acierto.**

Respuesta:

Primera ronda: 463 lecturas lógicas y 267 físicas. Segunda ronda: 247 lógicas y 0 físicas. La segunda ejecución encontró los bloques en caché, por eso no necesitó lecturas físicas. No se debe comparar directamente el total de lógicas entre ambas rondas como si toda lectura lógica fuera física; la tasa de acierto de la segunda ronda fue del 100 % para las lecturas físicas observadas.

**14. Compara literales y variables de enlace (bind variables) con tus cifras de análisis (parse) y de V$SQL.**

Respuesta:

Con literales hubo 1008 hard parses, 410 ms y 450 cursores que ocuparon 16.097 KB. Con variables de enlace hubo 1 hard parse, 0 ms medidos y un cursor de 39 KB. Reutilizar el mismo SQL con binds reduce el análisis y el consumo de memoria.

**15. Relaciona el SPID de LGWR de v$process con el PID de /proc. ¿Por qué docker top muestra otro número?**

Respuesta:

LGWR tiene SPID 981 en `v$process` y `/proc` muestra el mismo PID 981 (`db_lgwr_FREE`), por lo que corresponden al mismo proceso dentro del contenedor. `docker top` muestra el PID del proceso visto desde el host, que puede ser diferente por los espacios de nombres de PID.

### Contenedores (I)

**16. Explica con tu evidencia por qué SYS ve 16 datafiles desde la raíz y 9 desde FREEPDB1.**

Respuesta:

Desde CDB$ROOT se ven los datafiles de todos los contenedores: 4 en CON_ID 1, 3 en CON_ID 2 y 9 en CON_ID 3, total 16. Dentro de FREEPDB1 solo se ven sus 9 archivos con CON_ID 3.

**17. ¿Por qué LAB4_ANALISTA recibe ORA-00942 y no "privilegios insuficientes" al consultar DBA_TABLES?**

Respuesta:

`DBA_TABLES` es una vista del diccionario; si el usuario no tiene visibilidad sobre la vista/objeto, Oracle puede devolver ORA-00942 como si el objeto no existiera. La evidencia de `LAB4_ANALISTA` registra ORA-00942 en `DBA_TABLES`, `V$SESSION` y la tabla consultada, además de ORA-01031 al intentar cambiar a la raíz.

**18. ¿Qué diferencia hay entre C##LAB4_AUDITOR y C##OPS_RO? ¿Qué sentencia los igualaría?**

Respuesta:

`C##LAB4_AUDITOR` ve `CON_ID` 0 y 1; `C##OPS_RO` tiene `CONTAINER_DATA=ALL` y privilegios de observación. Para que el auditor vea los datos de todos los contenedores desde la raíz, la sentencia del bloque 6 es `ALTER USER C##LAB4_AUDITOR SET CONTAINER_DATA = ALL CONTAINER = CURRENT;` (ejecutada en `CDB$ROOT`), además de los privilegios de lectura correspondientes.

**19. ¿Qué ventaja tiene GRANT READ ANY TABLE ON SCHEMA frente a conceder tabla por tabla? ¿Y qué riesgo?**

Respuesta:

`READ ANY TABLE ON SCHEMA` permite lectura de las tablas del esquema sin conceder acceso a todos los esquemas ni dar permiso de escritura tabla por tabla. El riesgo es que incluye todas las tablas del esquema, incluso las nuevas que se creen después, por lo que el alcance puede ser mayor de lo necesario.

**20. ¿Qué valor tiene COMMON_USER_PREFIX en tu base y qué consecuencia tuvo en el bloque 3a de 10-ciclo-vida-pdb?**

Respuesta:

`COMMON_USER_PREFIX=C##`. En el bloque **3a**, `CREATE USER lab4_local` se ejecutó desde `CDB$ROOT` sin el prefijo reservado y devolvió **ORA-65096**: el nombre no cumple el prefijo exigido para un usuario común. En el bloque **3b**, `CREATE USER c##lab4_comun` se ejecutó desde `FREEPDB1` y devolvió **ORA-65094**, porque un usuario común no se crea desde una PDB. Son dos errores distintos y corresponden a contextos distintos.

### Archivos (J)

**21. Clasifica los archivos de tu evidencia 11 en "son la base de datos" y "relacionados". ¿Dónde va el password file y por qué?**

Respuesta:

Archivos de la base: 16 datafiles, 3 tempfiles, 2 control files y 3 redo logs. Relacionados: SPFILE, password file, ADR y los cinco archived logs/autobackups inventariados. El password file está relacionado porque sirve para autenticación administrativa y no almacena datos de usuario.

**22. Explica por qué academia01.dbf mide 104 865 792 bytes en Linux si v$datafile dice 100 MB.**

Respuesta:

Oracle muestra **100 MiB**, es decir, `100 × 1.048.576 = 104.857.600` bytes. Linux informa `104.865.792` bytes: la diferencia es **8.192 bytes**, exactamente **un bloque Oracle** de 8 KB. Por tanto, no es solo una diferencia de unidades; el tamaño físico medido incluye un bloque adicional respecto a los 100 MiB que muestra `V$DATAFILE`.

**23. ¿Qué dos puntos únicos de fallo (single points of failure) ves en los control files y en el redo de tu base?**

Respuesta:

Los dos control files están en la misma carpeta, por lo que un fallo de ese almacenamiento puede perder ambos. Además, cada grupo de redo tiene un solo miembro, así que no hay una segunda copia del redo en otra ubicación.

**24. ¿Por qué el ADR fuera del volumen es un problema operativo aunque la base no pierda datos?**

Respuesta:

El ADR guarda alert log, trazas y diagnósticos. Al estar en `/opt/oracle/diag`, fuera del volumen persistente, recrear el contenedor podría borrar evidencia necesaria para investigar fallos aunque los datafiles sigan intactos.

### Bloque y fila (K)

**25. Descompón el ROWID de tu estudiante 101 en objeto, bloque y fila, y comprueba cada trozo con DBMS_ROWID.**

Respuesta:

El ROWID es `AAAR2kAAAAAAAMPAAF`. Sus componentes, obtenidos con `DBMS_ROWID`, son: **objeto** `73124`, **archivo relativo** `1024` (archivo 16), **bloque** `783` y **número de fila** `5`. Se puede comprobar con `DBMS_ROWID.ROWID_OBJECT`, `DBMS_ROWID.ROWID_RELATIVE_FNO`, `DBMS_ROWID.ROWID_BLOCK_NUMBER` y `DBMS_ROWID.ROWID_ROW_NUMBER` aplicados al ROWID.

**26. Del volcado: ¿qué significan nrow, fsbo, fseo y avsp? Demuestra que avsp = fseo - fsbo con tus números.**

Respuesta:

`nrow` es el número de filas del bloque; `fsbo` marca el comienzo del espacio libre; `fseo` señala el final del espacio ocupado por filas; `avsp` es el espacio libre disponible. Con los valores del volcado: `0x427 - 0x0c6 = 0x361`; en decimal, `1063 - 198 = 865` bytes, igual a `avsp`.

**27. Explica la línea de la ITL con Lck = 90 y Flag --U-. ¿Qué es la limpieza diferida de bloques (delayed block cleanout)?**

Respuesta:

`Lck=90` indica que esa entrada ITL tiene 90 bloqueos de fila asociados a la transacción. Coincide con `nrow=90`: la transacción había bloqueado las 90 filas del bloque. El flag `--U-` indica que la entrada está marcada como usada. La limpieza diferida (*delayed block cleanout*) ocurre cuando Oracle actualiza posteriormente la información de commit de las filas/bloque, en vez de limpiar todos los ITL al terminar la transacción.

**28. Calcula los 78 bytes de la fila 101 a partir de cabecera, bytes de longitud y datos.**

Respuesta:

La fila ocupa 78 bytes: 3 bytes de cabecera de fila + 7 bytes de longitud (uno por cada una de las 7 columnas) + 68 bytes de datos (`VSIZE=68`). Total: `3 + 7 + 68 = 78` bytes, que coincide con `tl:78` del volcado.

### Capacidad y coste (L)

**29. Calcula bfr y b de ACA_ESTUDIANTES con la fórmula de la Unidad 3 y explica por qué la tabla real tiene 244 bloques.**

Respuesta:

Con `PCTFREE=10`, `R=76`, tamaño de bloque 8192 y la cabecera usada en la Unidad 3, la evidencia de cálculo da bfr=95 y b=211; con el ajuste de Oracle da bfr=93 y b=216. La tabla tiene 244 bloques bajo HWM y 256 asignados porque el cálculo es una estimación y la ocupación real depende de cabeceras, distribución de filas, extents y espacio reservado.

**30. Con tus cifras de 5a, 5b y 5c, ¿cuánto cuesta una lectura lógica, una física aleatoria y un bloque secuencial?**

Respuesta:

Las medidas son: lectura lógica ≈ **1,38 μs**, lectura física aleatoria ≈ **5,2 μs** por bloque (`db file sequential read`) y recorrido secuencial de **4595 bloques en 17 ms**, equivalente a unos **3,7 μs por bloque** de media en esa prueba. No hay que confundir los 5 μs de espera de una lectura física de un bloque con el coste medio por bloque del recorrido multibloque. Son resultados del contenedor, no cifras universales para un HDD real.

**31. Recalcula el umbral de rentabilidad de la sección 5d suponiendo un HDD (Bw = 150 MB/s, lat = 5 ms).**

Respuesta:

Con bloques de 8 KB y `Bw = 150 MB/s`, el tiempo de transferencia secuencial por bloque es `8 KB / 150 MB/s ≈ 0,053 ms`. Sumando la latencia de 5 ms, el coste aproximado de una lectura aleatoria es `5,053 ms`. Para un recorrido secuencial de `b` bloques, `T_sec ≈ 5 ms + b × 0,053 ms`; para lecturas aleatorias, `T_aleat ≈ b × 5,053 ms`. Igualando ambos: `b × 5,053 = 5 + b × 0,053`, por lo que `b ≈ 1` bloque. Así, desde aproximadamente dos bloques consecutivos, el recorrido secuencial resulta más rentable que realizar lecturas aleatorias independientes. El resultado es aproximado y depende de si la latencia se paga por operación o por petición multibloque.

**32. ¿Por qué la "lectura física" sale en microsegundos en el contenedor? ¿Invalida eso el método?**

Respuesta:

El contenedor usa almacenamiento virtual y cachés del sistema operativo, por lo que una lectura etiquetada como física puede completarse desde la caché del host y medirse en microsegundos. No invalida el método, pero sí limita la extrapolación a un HDD real; para estimar producción hay que medir en el almacenamiento objetivo y controlar cachés.

### Filas migradas y encadenadas (M)

**33. Diferencia migración (row migration) y encadenamiento (row chaining): causa, cómo se detecta y cómo se cura.**

Respuesta:

La migración ocurre cuando una fila ya no cabe en su bloque tras una actualización: Oracle la mueve a otro bloque y deja un puntero en el original. El encadenamiento ocurre cuando una fila es demasiado grande para un bloque y se reparte entre varios. Se detectan con `CHAIN_CNT` y estadísticas de fetch; se puede corregir migración con `ALTER TABLE ... MOVE` y reconstruir índices, mientras que el encadenamiento de filas grandes puede ser inevitable.

**34. Explica el 3,2 de lecturas lógicas por búsqueda de la sección 4 a partir del 20 % de filas migradas.**

Respuesta:

Con un 20 % de filas migradas, parte de las búsquedas requiere una lectura para localizar el puntero y otra para obtener la fila; por eso aumenta el trabajo por fila. La medición de la práctica dio 3200 lecturas lógicas por 1000 búsquedas, es decir, 3,2 por búsqueda, y 200 eventos `table fetch continued row`.

**35. ¿Por qué ALTER TABLE ... MOVE deja el índice UNUSABLE? ¿Qué harías en producción?**

Respuesta:

`ALTER TABLE ... MOVE` reorganiza el segmento y cambia la ubicación física de las filas, por lo que los índices dejan de apuntar a las ubicaciones válidas y pueden quedar UNUSABLE. En producción programaría la operación en una ventana de mantenimiento, comprobaría dependencias y reconstruiría inmediatamente los índices afectados; la práctica dejó la PK VALID tras REBUILD.

### Autopsia y trabajo profesional (N, O)

**36. Elige tres hallazgos de tu autopsia (15) y escribe para cada uno riesgo, acción y prioridad.**

Respuesta:

1) **Prioridad 1 — redo y control files (riesgo alto):** hay tres grupos de redo con un solo miembro por grupo y los dos control files están en `/opt/oracle/oradata/FREE/`. Si se corrompe el redo del grupo `CURRENT`, pueden perderse transacciones confirmadas; si falla ese volumen, se pierden ambos control files. **Acción:** añadir un segundo miembro a cada grupo de redo en otra ruta (preferiblemente otro disco) y mover una copia del control file fuera de `FREE/`.

2) **Prioridad 2 — FRA sin configurar (riesgo alto):** `db_recovery_file_dest` está vacío y `db_recovery_file_dest_size = 0`; hay cinco archived logs (353 MB) en `$ORACLE_HOME/dbs`. Pueden crecer sin límite y llenar el disco, impidiendo que ARCn archive y deteniendo el servicio. **Acción:** configurar `db_recovery_file_dest` y `db_recovery_file_dest_size` y llevar allí los archivados; está previsto para el Lab 5.

3) **Prioridad 3 — Flashback desactivado (riesgo medio):** `FLASHBACK = NO` mientras `LOG_MODE = ARCHIVELOG`. Sin Flashback, un error humano puede requerir restaurar una copia para recuperar el estado anterior. **Acción:** activar Flashback Database una vez configurada la FRA, de la que depende.

Estos son los tres primeros hallazgos de `docs/bitacora/lab4-autopsia.md`, respetando el orden de prioridad de la autopsia. Los hallazgos de estadísticas de `ALTURA_MAX` y los errores ORA conocidos quedan como hallazgos secundarios (prioridades 4 y 5).

**37. ¿Por qué C##OPS_RO y no SYSTEM para observar? ¿Qué no puede hacer C##OPS_RO?**

Respuesta:

`C##OPS_RO` permite observar con privilegios de lectura acotados y reduce el riesgo de usar una cuenta administrativa para tareas rutinarias. No puede modificar datos ni tiene privilegios ANY de escritura; la verificación final confirmó cero privilegios ANY de escritura.

**38. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?**

Respuesta:

Se corrigen dos vías: las contraseñas escritas en claro dentro de la migración versionada `database/migrations/V000__setup_entornos_negocio.sql` (cinco contraseñas en las líneas 6, 12, 18, 24 y 30) y la autenticación administrativa escrita como `sys/$ORACLE_PWD@...` en el script de despliegue. La versión corregida usa `/ as sysdba` en `08-aplicar-migraciones.sh`; la credencial antigua de V000 dejó de autenticar y devolvió ORA-01017.

## Preguntas tipo examen

Respuestas ordenadas según el identificador del enunciado. Se respetan los enunciados originales: cuando la pregunta pide elegir dos opciones, se indican ambas letras.

**P1.** Un DBA ejecuta SHUTDOWN IMMEDIATE y copia todos los datafiles, control files y redo logs online. ¿Qué afirmaciones son correctas sobre esta copia? (Elige dos.)

Letra: **A y D**
Respuesta correcta: la copia tras `SHUTDOWN IMMEDIATE` es consistente; una copia ordinaria con la base abierta no garantiza consistencia. 
Justificación: A describe la consistencia de una copia en frío tras SHUTDOWN IMMEDIATE; D indica que, una vez restaurados los archivos consistentes en sus ubicaciones, puede arrancarse la base normalmente.

**P2.** Un tablespace de usuario tiene su datafile en un disco que se va a retirar. La base es Standard Edition y puede tener una breve indisponibilidad de ese tablespace. ¿Qué secuencia es correcta?

Letra: **B**
Justificación: Poner el tablespace OFFLINE NORMAL, copiar el archivo, actualizar la ruta con RENAME DATAFILE y volver a ONLINE.

**P-D1.** Un propietario de esquema solo debe poseer objetos; nadie debe poder iniciar sesión con él, ni siquiera conociendo una contraseña antigua. ¿Qué sentencia lo consigue?

Letra: **C**
Justificación: NO AUTHENTICATION impide autenticarse con contraseña; es la opción que cumple el requisito incluso si alguien conoce una contraseña antigua.

**P3.** Un DBA consulta v$instance y v$database en una base abierta. ¿Qué dos afirmaciones son correctas? (Elige dos.)

Letra: **A y C**
Justificación: STARTUP_TIME cambia al arrancar la instancia; CREATED indica cuándo se creó la base.

**P4.** La instancia está en estado NOMOUNT. ¿Qué dos operaciones puede realizar el DBA en este estado? (Elige dos.)

Letra: **A y C**
Justificación: En NOMOUNT pueden consultarse parámetros y recrearse el control file; aún no se puede consultar el diccionario normal.

**P5.** ¿En qué etapa debe estar la base para ejecutar ALTER DATABASE ARCHIVELOG?

Letra: **B**
Justificación: ALTER DATABASE ARCHIVELOG requiere la base montada, no abierta.

**P6.** Un DBA ejecuta ALTER SYSTEM SET open_cursors = 500; en una instancia que arrancó con SPFILE. ¿Cuál es el resultado?

Letra: **B**
Justificación: Con SPFILE y sin SCOPE explícito, el cambio dinámico usa BOTH: memoria y SPFILE.

**P7.** Conectado a FREEPDB1, un DBA ejecuta `ALTER SYSTEM SET processes = 300 SCOPE = SPFILE;`. ¿Qué ocurre?

Letra: **C**
Justificación: Desde FREEPDB1 falla con ORA-65040 porque PROCESSES es un parámetro de instancia.

**P8.** ¿Qué dos sentencias permiten recuperar una instancia que no arranca por un valor erróneo escrito en el SPFILE? (Elige dos.)

Letra: **A y C**
Justificación: Se arranca temporalmente con un PFILE válido y después se recrea el SPFILE desde ese PFILE.

**P9.** Una instancia tiene MEMORY_TARGET = 0, SGA_TARGET = 2G y DB_CACHE_SIZE = 512M. ¿Qué afirmación es correcta?

Letra: **B**
Justificación: Con MEMORY_TARGET=0 se usa ASMM; DB_CACHE_SIZE fija un mínimo para la caché dentro de la SGA gestionada.

**P10.** ¿Qué dos estructuras forman parte de la PGA de un proceso servidor dedicado? (Elige dos.)

Letra: **A y D**
Justificación: La sort area y la memoria de sesión de un servidor dedicado son privadas de la PGA.

**P-G1.** Una aplicación ejecuta miles de veces por minuto la misma consulta cambiando solo un literal en el WHERE. V$SQL muestra miles de cursores casi idénticos y la CPU de análisis es alta. ¿Cuál es la solución definitiva recomendada?

Letra: **B**
Justificación: Las variables de enlace permiten reutilizar cursores y reducir hard parses.

**P-G2.** En V$SQL_WORKAREA, una ordenación muestra LAST_EXECUTION = '6 PASSES' y LAST_TEMPSEG_SIZE de varios MB. ¿Qué significa?

Letra: **B**
Justificación: 6 PASSES y TEMP indican que el workarea no cupo en memoria y tuvo que realizar pasadas usando TEMP.

**P11.** Un usuario ejecuta COMMIT. ¿Qué proceso debe completar su escritura antes de que el COMMIT devuelva el control?

Letra: **C**
Justificación: LGWR debe escribir el redo del COMMIT antes de devolver el control.

**P12.** ¿Qué dos procesos de background son obligatorios en cualquier instancia de Oracle? (Elige dos.)

Letra: **B y D**
Justificación: PMON y SMON son procesos esenciales de background.

**P13.** Conectado como SYS a CDB$ROOT ejecutas SELECT con_id, COUNT(*) FROM v$datafile GROUP BY con_id; y obtienes filas para CON_ID 1, 2 y 3. Después ejecutas ALTER SESSION SET CONTAINER = FREEPDB1; y repites la consulta. ¿Qué obtienes?

Letra: **B**
Justificación: Desde FREEPDB1 la consulta muestra únicamente los datafiles de CON_ID 3.

**P14.** Un usuario común C##AUDIT tiene CREATE SESSION y SELECT_CATALOG_ROLE concedidos con CONTAINER = ALL. Conectado a la raíz, consulta CDB_TABLESPACES y solo ve filas de CON_ID 1. ¿Qué sentencia le permite ver las de todas las PDB desde la raíz?

Letra: **B**
Justificación: CONTAINER_DATA=ALL con CONTAINER=CURRENT permite al usuario común ver filas de todas las PDB desde la raíz, sujeto a sus privilegios.

**P15.** ¿Qué dos afirmaciones sobre GRANT READ ANY TABLE ON SCHEMA hr TO analista; (23ai y posteriores) son correctas? (Elige dos.)

Letra: **A y D**
Justificación: El privilegio cubre tablas actuales y futuras del esquema HR y no concede lectura de otros esquemas.

**P16.** ¿Qué dos archivos forman parte de la base de datos Oracle (database) y no son solo archivos relacionados? (Elige dos.)

Letra: **B y D**
Justificación: Los control files y los online redo logs forman parte de los archivos físicos de la base.

**P17.** Una base en NOARCHIVELOG tiene dos control files en el mismo disco y un único miembro por grupo de redo. Se pierde ese disco. ¿Qué es cierto?

Letra: **C**
Justificación: Al perderse el disco en NOARCHIVELOG, con los control files y redo sin redundancia, solo queda restaurar la última copia disponible y se pierden cambios posteriores.

**P18.** En un tablespace BIGFILE, DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) sin segundo argumento devuelve un número que no coincide con el volcado del bloque. ¿Por qué?

Letra: **B**
Justificación: Sin el formato explícito la función interpreta el ROWID como SMALLFILE; para BIGFILE se debe pasar 'BIGFILE'.

**P19.** Una tabla se crea con PCTFREE 10 en un tablespace con ASSM. ¿Qué dos afirmaciones son correctas? (Elige dos.)

Letra: **A y B**
Justificación: PCTFREE marca el espacio reservado para crecimiento de filas y el umbral a partir del que el bloque deja de recibir nuevas filas; ASSM administra el espacio mediante bitmaps, pero no es una de las opciones correctas aquí.

**P20.** Una tabla tiene r = 2 000 000 de filas de R = 180 bytes, bloques de 8192 bytes con 96 bytes de cabecera y PCTFREE 10. Según la Unidad 3, ¿cuántos bloques necesita?

Letra: **B**
Justificación: La fórmula simplificada de la práctica da 40 filas por bloque y 2.000.000/40 = 50.000 bloques.

**P21.** Una sesión lee una tabla con un recorrido completo y el evento de espera dominante es "db file scattered read". ¿Qué indica?

Letra: **B**
Justificación: db file scattered read corresponde a lecturas físicas multibloque hacia la buffer cache.

**P22.** Tras actualizar muchas filas de una tabla, la estadística "table fetch continued row" crece. ¿Qué dos acciones son adecuadas? (Elige dos.)

Letra: **A y C**
Justificación: LIST CHAINED ROWS identifica filas afectadas; MOVE con un PCTFREE mayor puede reorganizarlas, y después hay que reconstruir índices afectados.

**P23.** Una fila mide 12 000 bytes y el tablespace usa bloques de 8 KB. ¿Qué es cierto?

Letra: **B**
Justificación: Una fila de 12.000 bytes supera el espacio útil de un bloque de 8 KB y queda encadenada en varios bloques; MOVE no puede hacer que quepa en uno.

**P24.** Necesitas un informe diario del estado de una base de producción (archivos, espacio, errores del alert log) con el mínimo riesgo. ¿Qué enfoque sigue el mínimo privilegio?

Letra: **B**
Justificación: Un usuario común de solo lectura con CONTAINER_DATA y el permiso puntual para V_$DIAG_ALERT_EXT sigue el mínimo privilegio.

**P25.** ¿Qué contenedor de una CDB es una plantilla de solo lectura que se usa para crear PDB nuevas?

Letra: **B**
Justificación: PDB$SEED es la plantilla de solo lectura para crear nuevas PDB.

**P26.** Conectado a FREEPDB1 ejecutas CREATE USER c##rep IDENTIFIED BY ...;. ¿Qué ocurre si COMMON_USER_PREFIX vale C##?

Letra: **C**
Justificación: Desde una PDB, intentar crear un usuario con el prefijo reservado C## devuelve ORA-65094.

**P27.** ¿Qué secuencia elimina una PDB abierta junto con sus archivos?

Letra: **B**
Justificación: Primero se cierra la PDB y después se elimina con INCLUDING DATAFILES.

**P28.** ¿Qué dos vistas devuelven información aunque la base esté solo en MOUNT? (Elige dos.)

Letra: **A y C**
Justificación: V$DATAFILE y V$LOG responden en MOUNT porque la instancia ya tiene abierto el control file; las vistas DBA requieren OPEN.

**P29.** `V$FIXED_VIEW_DEFINITION` muestra que `V$LOG` lee `X$KCCLE`. ¿Qué indica el prefijo KCC?

Letra: **A**
Justificación: KCC identifica estructuras internas relacionadas con el control file.

**P30.** En una CDB, ¿dónde se definen las vistas CDB_?

Letra: **B**
Justificación: Las vistas CDB_ se definen en CDB$ROOT y también en cada PDB; desde una PDB muestran solo las filas de ese contenedor.

**P31.** ¿Qué afirmación sobre los tempfiles es correcta?

Letra: **B**
Justificación: Los tempfiles no se respaldan como datafiles ordinarios; su contenido se recrea si se pierden.

**P32.** Con la base abierta, un DBA borra por error el único SPFILE desde el sistema operativo. ¿Qué es cierto?

Letra: **B**
Justificación: Borrar el SPFILE no detiene una instancia ya arrancada; puede recrearse con CREATE SPFILE FROM MEMORY.

**P33.** ¿Qué vista muestra qué usuarios están en el password file y con qué privilegios administrativos?

Letra: **B**
Justificación: V$PWFILE_USERS lista usuarios del password file y privilegios administrativos.

**P34.** ¿Qué dos elementos forman parte de la cabecera de un bloque de datos de Oracle? (Elige dos.)

Letra: **A y B**
Justificación: La cabecera del bloque incluye ITL y el directorio de filas.

**P35.** Un tablespace se gestiona localmente con AUTOALLOCATE y bloques de 8 KB. Un segmento nuevo crece. ¿Qué tamaños de extensión verás primero?

Letra: **B**
Justificación: Con AUTOALLOCATE y bloques de 8 KB se observan primero extensiones de 8 bloques (64 KB) y después de 128 bloques (1 MB).

**P36.** ¿Qué significa SEGMENT_SPACE_MANAGEMENT = AUTO en DBA_TABLESPACES?

Letra: **B**
Justificación: AUTO significa ASSM: el espacio libre del segmento se gestiona mediante mapas de bits.

**P37.** Desde 23ai, CREATE TABLESPACE t DATAFILE '/u02/t01.dbf' SIZE 100M; sin más cláusulas crea un tablespace...

Letra: **B**
Justificación: Según el enunciado, desde 23ai la sentencia sin cláusula de tipo crea un tablespace BIGFILE gestionado localmente.

**P38.** Una consulta hace 4 lecturas lógicas por ejecución y 0 físicas. ¿Qué es cierto?

Letra: **A**
Justificación: Cuatro lecturas lógicas y cero físicas indican que los bloques necesarios estaban en la buffer cache.

**P39.** ¿Qué dos factores reducen el factor de bloqueo (bfr) de una tabla? (Elige dos.)

Letra: **A y B**
Justificación: Más PCTFREE y un mayor tamaño medio de fila reducen el número de filas que caben en cada bloque.

**P40.** Un DBA ejecuta ALTER SYSTEM FLUSH BUFFER_CACHE; en producción "para medir". ¿Cuál es la consecuencia más probable?

Letra: **B**
Justificación: Vaciar la buffer cache provoca más lecturas físicas hasta que se recalienta y puede generar picos de latencia.

**P41.** ¿Cuál es la diferencia entre una fila migrada y una encadenada?

Letra: **B**
Justificación: La fila migrada cabía originalmente en un bloque y se trasladó al crecer; la encadenada necesita varios bloques para almacenarse.

**P42.** Tras ALTER TABLE ventas MOVE; las consultas por clave van más lentas y DBA_INDEXES muestra STATUS = UNUSABLE. ¿Qué haces?

Letra: **A**
Justificación: Después de MOVE hay que reconstruir los índices que quedaron UNUSABLE.

**P43.** ¿Qué vista permite leer el alert log con SQL?

Letra: **A**
Justificación: V$DIAG_ALERT_EXT permite consultar el alert log mediante SQL.

**P44.** DBA_TABLESPACE_USAGE_METRICS muestra un tablespace al 92 % de su tamaño máximo. ¿Qué dos acciones son razonables? (Elige dos.)

Letra: **A y B**
Justificación: Ampliar el tablespace o añadir un datafile y revisar los segmentos que crecen son acciones razonables antes de llegar al límite.

**P45.** En una CDB, ¿qué dos elementos son compartidos por todas las PDB? (Elige dos.)

Letra: **A y B**
Justificación: La SGA/procesos de background y los online redo logs se comparten a nivel de CDB.

**P46.** Un usuario local de una PDB con solo CREATE SESSION ejecuta ALTER SESSION SET CONTAINER = CDB$ROOT;. ¿Qué ocurre?

Letra: **B**
Justificación: El usuario local no tiene privilegios para cambiar al contenedor raíz y recibe ORA-01031.
