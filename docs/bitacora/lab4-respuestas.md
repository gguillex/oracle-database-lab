# Lab 4 · Respuestas

En cada respuesta indico de qué evidencia saco los datos (todas están en `docs/bitacora/lab4/evidencia/`).

## Puntos de control y retos por Parte

### Parte A · Punto de control: Antes de seguir

> Anota en tu archivo de respuestas cuántos archivos salieron como FUERA y por qué Oracle los creó ahí. Si todo sale "dentro", tu imagen enlaza $ORACLE_HOME/dbs con el volumen: anótalo también.

Respuesta:

Ninguno salió como FUERA. En mi imagen la carpeta `$ORACLE_HOME/dbs` es en realidad un enlace a `/opt/oracle/oradata/dbconfig/FREE/dbs`, que está dentro del volumen, así que aunque Oracle creara archivos ahí, se guardaban igualmente en el volumen. Lo vi en el inventario de la Parte A.

### Parte A · Reto: Tu primer informe de diagnóstico

> Imagina que este entorno es de un cliente. Escribe en docs/bitacora/lab4-respuestas.md un informe de cinco líneas como máximo: qué encontraste, qué riesgo tiene cada hallazgo (alto, medio, bajo) y en qué orden lo corregirías. Justifica el orden. Así empiezan los informes reales de auditoría de una base.

Respuesta:

Riesgo alto: los dos control files están en la misma carpeta, así que un mismo fallo se los puede llevar por delante a la vez. Riesgo medio: el ADR (donde están el alert log y las trazas) está fuera del volumen, y si se recrea el contenedor se pierde ese historial. Riesgo bajo: los archivos nuevos dependen de que alguien escriba bien la ruta. Lo arreglaría en ese orden: primero lo que puede hacer perder datos, después lo que hace perder información para investigar y por último lo que solo es una mala costumbre. La copia en frío que hice es consistente y su comprobación SHA-256 sale bien.

### Parte B · Reto: Mínimo privilegio, de verdad

> Un compañero propone dar a C##OPS_RO el rol DBA "para que no le falte nada". Escribe en tus respuestas dos riesgos concretos de esa decisión y qué privilegio exacto le darías si necesitara leer el alert log (pista: lo harás en la Parte J con 11-ampliar-ops-ro.sql, y la verificación final comprueba que la cuenta no tiene privilegios ANY de escritura).

Respuesta:

Con el rol DBA esa cuenta podría cambiar datos y configuración, cuando solo la queremos para mirar; y si alguien le robara la contraseña, tendría la base entera en sus manos. Para leer el alert log no hace falta tanto: basta con `GRANT SELECT ON SYS.V_$DIAG_ALERT_EXT TO C##OPS_RO;`, además de los permisos de lectura que ya tenía. La verificación final confirmó que la cuenta no tiene ningún privilegio ANY de escritura.

### Parte C · Reto: Que no vuelva a pasar

> Propón y aplica en tu entorno una medida que impida que un futuro CREATE TABLESPACE con ruta relativa vuelva a dejar archivos fuera del volumen. Pista: DB_CREATE_FILE_DEST y Oracle Managed Files (OMF). Escribe el comando, su SCOPE y qué cambiaría en el siguiente CREATE TABLESPACE tbs_x; sin cláusula DATAFILE. No olvides que es un cambio de configuración: va en su propio commit.

Respuesta:

Le diría a Oracle dónde tiene que crear los archivos por defecto, conectado como SYSDBA en la raíz: `ALTER SYSTEM SET db_create_file_dest='/opt/oracle/oradata/FREE' SCOPE=BOTH;` (BOTH para que valga ya y también tras reiniciar). Así, un `CREATE TABLESPACE tbs_x` sin indicar archivo lo crearía Oracle solo, con su propio nombre y dentro de esa carpeta del volumen, sin depender de que alguien escriba bien la ruta. Al ser un cambio de configuración, va en su propio commit. En mi entorno ese parámetro estaba vacío.

### Parte E · Punto de control: Explica cada error con tus palabras

> ORA-01507 en NOMOUNT: v$database lee el control file, que aún no está abierto. Pero v$parameter sí responde: los parámetros ya están en la memoria de la instancia.

Respuesta:

El arranque va por etapas. En **NOMOUNT** Oracle solo ha leído su configuración (el SPFILE), ha reservado memoria y ha arrancado sus procesos: por eso `v$parameter` contesta, pero `v$database` da **ORA-01507**, porque todavía no ha abierto el control file, que es donde está la información de la base. En **MOUNT** ya ha abierto el control file y sabe qué archivos tiene la base (en mi evidencia, 16 datafiles), pero aún no los ha abierto, así que preguntar por las tablas con `DBA_TABLES` da **ORA-01219**. En **OPEN** ya está todo abierto y se puede consultar todo.

### Parte E · Reto: El parte del reinicio

> Tu responsable te pide un resumen del último reinicio para el informe semanal. Usando solo el alert log (o v$diag_alert_ext desde la Parte J), responde en tus respuestas: ¿a qué hora se pidió la parada, cuánto tardó en abrir la base, hubo recuperación de instancia y qué errores aparecieron? Clasifica cada error como "conocido" o "a investigar".

Respuesta:

La parada se pidió a las **18:06:20.715 UTC** y terminó a las **18:06:26.427**: tardó unos **5,7 segundos**. El arranque empezó a las **18:06:26.568**, la base quedó montada a las **18:06:27.614** y la PDB `FREEPDB1` estaba abierta a las **18:06:28.892**. Es decir, desde que arrancó hasta que estuvo lista pasaron unos **2,3 segundos**, y en total, desde que se pidió parar hasta que volvió a estar disponible, unos **8,2 segundos**. El alert log dice que hubo una comprobación de recuperación, pero las PDB que se habían cerrado bien no la necesitaron. Errores: **ORA-00800, conocido**: el contenedor no deja cambiar la prioridad de algunos procesos de Oracle. **ORA-27301/27302/27303: no son de este reinicio**: llevan fecha del 5 de julio de 2026, de cuando se construyó la imagen.

### Parte F · Reto: Una petición de cambio (change request) de verdad

> Un equipo de desarrollo pide subir open_cursors a 1000 "porque les sale ORA-01000". Antes de tocar nada, escribe en tus respuestas la petición de cambio como la presentarías en una empresa: valor actual y de dónde sale, valor propuesto, SCOPE y por qué, cómo lo pruebas, cómo lo deshaces (rollback) y qué evidencia guardas. Pista: ORA-01000 suele delatar cursores que la aplicación no cierra; subir el límite solo retrasa el problema.

Respuesta:

- **Qué se pide:** subir `open_cursors` de 300 (el valor actual, tanto en memoria como en el SPFILE) a 1000, porque la aplicación da ORA-01000.
- **Antes de tocarlo:** comprobaría si la aplicación cierra los cursores que abre, mirando `V$OPEN_CURSOR` y `V$SQL`. Lo más probable es que haya una fuga y que subir el límite solo retrase el problema.
- **Cómo lo pruebo:** en un entorno de pruebas, `ALTER SYSTEM SET open_cursors=1000 SCOPE=BOTH;` (si lo aprueban), repitiendo la misma carga y comparando errores y número de cursores.
- **Cómo lo deshago:** `ALTER SYSTEM SET open_cursors=300 SCOPE=BOTH;`.
- **Qué guardo:** la petición aprobada, los valores de antes y después, el SQL que ejecuté y los resultados.

### Parte G · Punto de control: Interpreta el experimento

> ¿Por qué las lecturas lógicas son iguales en las dos rondas? (Pista: toda lectura física termina en una lógica: el bloque se trae a la caché y desde ahí se lee.)

Respuesta:

En mi caso no salieron iguales: la primera ronda hizo 463 lecturas lógicas y 267 físicas, y la segunda 247 lógicas y ninguna física. En la primera, los bloques no estaban en memoria y había que traerlos del disco (física) y luego leerlos (lógica); en la segunda ya estaban todos en memoria. Que el total de lógicas no coincida se debe al estado de la caché y al trabajo extra de la primera vez, así que no puedo decir que sean iguales si mis números son 463 y 247.

### Parte G · Punto de control: Lee la salida como un DBA

> Las 60 000 matrículas necesitaban unos 2,5 MB para ordenarse en memoria (KB_OPTIMO). Con PGA automática los tuvo (OPTIMAL, 0 KB en TEMP, 40 ms). Con 64 KB, Oracle escribió 3 MB en TEMP y los releyó 6 veces (6 PASSES): el doble de tiempo con una tabla pequeña; con una grande, la diferencia es de minutos.

Respuesta:

Con memoria suficiente la ordenación se hizo entera en memoria (OPTIMAL), sin tocar el disco (0 KB en TEMP), y tardó 10 ms. Al limitar la memoria a 64 KB, Oracle tuvo que ir guardando trozos en disco (2048 KB en TEMP) y repasarlos 6 veces (6 PASSES), y tardó 590 ms. Es decir: cuando falta memoria, Oracle se apaña con el disco, pero sale muchísimo más lento.

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
Encontró una firma con 275 cursores, que es la de `lab4_literal`: la misma consulta repetida una y otra vez cambiando solo el valor. Cada una se analiza como si fuera nueva, y eso es justo lo que dispara la CPU.

### Parte H · Reto: La sesión que más consume

> Abre dos terminales. En la primera, entra como SYSDBA (docker exec -it oralab-26ai sqlplus / as sysdba, ALTER SESSION SET CONTAINER = FREEPDB1;) y lanza una consulta que tarde unos segundos, por ejemplo SELECT COUNT(*) FROM admin_academia.aca_matriculas a, admin_academia.aca_matriculas b WHERE a.matricula_id < 3000;. Mientras corre, desde la segunda y como C##OPS_RO, localiza su SID, su SPID en Linux y cuánta PGA está usando (v$session + v$process). Anota los tres valores y la consulta que usaste: es la primera pregunta de cualquier diagnóstico de rendimiento.

Respuesta:

Lancé la consulta pesada como `SYS` en `FREEPDB1` (con `a.matricula_id < 30000`); devolvió **1.799.940.000 filas en 52,57 s**. Mientras corría, desde la otra terminal y como `C##OPS_RO`, la encontré: **SID 56** (serial 21925, contenedor 3), proceso de Linux **7304**, usando **3,3 MB de memoria** (3,7 MB reservados). Usé esta consulta:
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

Porque el redo es uno solo para toda la base y lo comparten todas las PDB: ahí se apuntan los cambios de todos los contenedores juntos. No es de ninguna PDB en concreto, y por eso aparece con `CON_ID=0`, que significa "de todo el conjunto". Así se puede recuperar la base entera de forma coherente.

### Parte I · Reto: Diseña el acceso de un auditor externo

> Una auditora debe leer, durante una semana, las tablas de ADMIN_CLINICA y nada más, sin poder modificar datos. Escribe en tu bitácora el CREATE USER (¿común o local?, ¿en qué contenedor?), el GRANT mínimo y la sentencia que lo revoca el último día. Justifica cada decisión con lo observado en I.2. No lo ejecutes: es un diseño.

Respuesta:

Le crearía un usuario **local** en `FREEPDB1`, porque solo necesita esa PDB; uno común podría existir en todas. Solo le daría permiso para conectarse y para leer las tablas que tiene que auditar, nada de escribir:
`CREATE USER audit_clinica IDENTIFIED BY "<contraseña segura>"; GRANT CREATE SESSION TO audit_clinica; GRANT READ ON ADMIN_CLINICA.<tabla> TO audit_clinica;`
El último día le quitaría esos `READ` y, si ya no hace falta la cuenta, `DROP USER audit_clinica CASCADE`. En la evidencia vi un ORA-00942 al acceder a `ADMIN_CLINICA`, así que antes de dar los permisos comprobaría que el esquema y las tablas existen con ese nombre.

### Parte J · Punto de control: Interpreta tu salida

> ¿Por qué el password file aparece como archivo relacionado si sin él no puedes entrar como SYSDBA por red?

Respuesta:

Porque no guarda datos de la base: guarda quién puede entrar como administrador (por ejemplo SYSDBA) cuando se conecta desde fuera. Es imprescindible para administrar a distancia, pero si se pierde no se pierde ningún dato, solo esa forma de entrar. Por eso es un archivo "relacionado" y no parte de la base.

### Parte J · Reto: Plan de copia a partir del inventario

> Con tu evidencia 11 calcula cuántos MB tendría una copia en frío completa (datafiles + control files + redo + SPFILE + password file) y cuáles de esos archivos sobrarían en una copia con RMAN. Escríbelo en la bitácora.

Respuesta:

Sumando lo que pide el enunciado: **16 datafiles (3974 MB)** + **2 control files (36 MB)** + **3 redo (600 MB)** + SPFILE (**3584 bytes**) + password file (**2048 bytes**) ≈ **4610 MB**, unos **4,6 GB**. Si añadiera los **5 redo archivados (353 MB)**, serían unos **4963 MB**. Los **3 tempfiles (60 MB)** no los cuento: son espacio temporal que Oracle puede volver a crear vacío, y RMAN tampoco los copia. Los redo archivados no son lo mismo que los redo en uso: se guardan o no según cómo quieras poder recuperar. Evidencia: `spool/…_11-archivos.spool.log`, sección 2.

### Parte K · Punto de control: Interpreta tu volcado

> Comprueba que avsp = fseo - fsbo con tus números (en hexadecimal y en decimal).

Respuesta:

En mi volcado `fsbo=0xc6` y `fseo=0x427`. Restando: `0x427 - 0x0c6 = 0x361`, que es justo el `avsp`. En decimal: 1063 − 198 = 865 bytes libres en el bloque.

### Parte K · Reto: Abre otro bloque

> Elige un estudiante con ID mayor que 19 000 (estará en los últimos bloques llenos), averigua su bloque con DBMS_ROWID, cambia el ID en una copia de 12-bloque.sql y compara nrow, avsp y la ITL con los del bloque 782. ¿Ves también la limpieza diferida? Guarda la traza como evidencia extra.

Respuesta:

Elegí el estudiante **19001**: su ROWID es `AAAR2kAAAAAAASKAAD`, está en el **bloque 1162**, fila 3. Como el tablespace es BIGFILE, hay que decírselo a la función para que calcule bien el bloque:
```sql
SELECT DBMS_ROWID.ROWID_OBJECT(rowid) AS objeto,
       DBMS_ROWID.ROWID_RELATIVE_FNO(rowid) AS fichero_relativo,
       DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid, 'BIGFILE') AS bloque,
       DBMS_ROWID.ROWID_ROW_NUMBER(rowid) AS fila
FROM admin_academia.aca_estudiantes
WHERE <columna_ID_real> = 19001;
```
Lo comparé con el bloque de mi estudiante 101, que en mi base es el **783** (el 782 es el del ejemplo del profesor):

| Dato | Bloque 1162 (ID 19001) | Bloque 783 (ID 101) |
|---|---:|---:|
| ROWID / fila | `AAAR2kAAAAAAASKAAD`, fila 3 | `AAAR2kAAAAAAAMPAAF`, fila 5 |
| Filas en el bloque (`nrow`) | 85 | 90 |
| `fsbo / fseo` | `0xbc / 0x421` | `0xc6 / 0x427` |
| Espacio libre (`avsp`) | `0x365` (869 bytes) | `0x361` (865 bytes) |
| ITL, entrada `0x01` | `0x0008.001.0000027d`, flag `--U-`, Lck 85, SCN `0x0000.005edef` | `0x0008.001.0000027d`, flag `--U-`, Lck 90, SCN `0x0000.005edef` |
| Tamaño de la fila | 82 bytes (datos: 72) | 78 bytes (datos: 68) |

En los dos se cumple `avsp = fseo - fsbo`: 1057 − 188 = 869 y 1063 − 198 = 865.

**Sí, también se ve la limpieza diferida.** Los dos bloques tienen apuntada la misma transacción, con el mismo flag `--U-` y el mismo SCN: Oracle no los limpió al terminar esa transacción, sino que deja esa tarea para la próxima vez que alguien los lea.

### Parte L · Reto: Dimensiona ACA_MATRICULAS

> Antes de mirar: predice con la fórmula de la Unidad 3 cuántos bloques ocupa ACA_MATRICULAS (60 000 filas). Después consulta AVG_ROW_LEN y BLOCKS en DBA_TABLES y explica la diferencia con la tabla de L.2. ¿Cuánto tardaría un recorrido completo en un HDD a 150 MB/s?

Respuesta:

`ACA_MATRICULAS` tiene **60.000 filas** de **30 bytes** de media, ocupa **370 bloques** con datos (**384** reservados), unos **3 MB**, y deja un 10 % libre en cada bloque. Leerla entera son `370 × 8192 = 3.031.040 bytes`, unos **2,89 MiB**; en un disco duro que lea a 150 MB/s eso son unos **20 ms**, sin contar el tiempo que tarda el cabezal en colocarse ni el trabajo de Oracle. Frente a `ACA_ESTUDIANTES` (filas de 76 bytes, 244 bloques con datos y 256 reservados) tiene más filas pero mucho más pequeñas, y por eso ocupa algo más de bloques sin ser una tabla grande.

### Parte N · Reto: Escribe tu informe de autopsia

> Crea docs/bitacora/lab4-autopsia.md con tus propios hallazgos (no copies la tabla de arriba: tu base puede ser distinta). Para cada uno: sección del script, evidencia (el valor exacto), riesgo, acción y prioridad. Termina con un resumen de tres líneas para un jefe que no es técnico.

Respuesta:

El informe está en `docs/bitacora/lab4-autopsia.md`. Lo más importante que encontré, por orden: **(1)** cada grupo de redo tiene una sola copia y los dos control files están en el mismo sitio; **(2)** no hay zona de recuperación (FRA) configurada y los archivados se van guardando en `$ORACLE_HOME/dbs` sin límite; y **(3)** Flashback está desactivado (`FLASHBACK = NO`) aunque la base archiva el redo.

## Preguntas de comprobación

### Respaldo y diagnóstico (A)

**1. ¿Por qué la copia de la Parte A es consistente? ¿Qué pasaría si se tomara con la base abierta?**

Respuesta:

Porque se hace con la base parada: con `SHUTDOWN IMMEDIATE` Oracle termina lo que tiene pendiente, lo escribe todo y cierra los archivos, así que lo que se copia es una foto fija y coherente. Si copiara con la base abierta, los archivos seguirían cambiando mientras los copio y cada uno quedaría en un momento distinto; para eso hacen falta otras técnicas de copia en caliente.

**2. ¿Para qué sirven manifiesto.txt y SHA256SUMS? ¿Qué comprueba restaurar-estado.sh antes de tocar nada?**

Respuesta:

`manifiesto.txt` es la ficha de la copia: qué tipo de copia es, cuántos archivos había fuera del volumen y algunos datos de contexto (en la mía, `tipo=copia en frio consistente (SHUTDOWN IMMEDIATE)` y `archivos_fuera_del_volumen=0`). `SHA256SUMS` guarda una "huella" de cada archivo copiado. Antes de restaurar, `restaurar-estado.sh` comprueba esas huellas con `sha256sum --check`: si algún archivo ha cambiado o está dañado, se para sin tocar nada. Además pide confirmar el nombre del volumen, salvo que se use `--si`.

**3. Define RPO y RTO con los datos de tu propia copia.**

Respuesta:

El RPO es cuántos datos podría perder: con esta copia, todo lo que haya pasado después de las 17:46:10 UTC del 26-10-2026, que es cuando se hizo. No puedo darlo en minutos sin saber cada cuánto se harían las copias. El RTO es cuánto tardaría en volver a tener el servicio, y no lo he medido porque no llegué a restaurar.

### Correcciones del Lab 3 (C, D)

**4. ¿Dónde creó Oracle los datafiles de V000 y por qué? ¿Qué parámetro habría evitado el problema?**

Respuesta:

Los creó en `$ORACLE_HOME/dbs` porque en V000 la ruta era relativa y no había ninguna carpeta por defecto configurada (`db_create_file_dest` estaba vacío). Si se hubiera configurado `DB_CREATE_FILE_DEST` con una carpeta del volumen, Oracle los habría creado ahí directamente.

**5. ¿Por qué ALTER TABLESPACE ... RENAME DATAFILE no basta para mover un archivo?**

Respuesta:

Porque solo cambia la ruta que Oracle tiene apuntada, pero no mueve el archivo de sitio. Hay que hacerlo en orden: dejar el tablespace fuera de servicio, mover el archivo con el sistema operativo, decirle a Oracle la ruta nueva y volver a ponerlo en servicio.

**6. ¿Por qué no se edita V000 y se crea V003? ¿Por qué invalidar una contraseña es mejor que borrarla del archivo?**

Respuesta:

Porque V000 ya se aplicó: si la cambio, una base nueva y una antigua acabarían distintas aunque digan tener las mismas migraciones. Los arreglos se hacen con una migración nueva, V003. Y borrar la contraseña del archivo no sirve de nada, porque sigue en el historial de Git (en `database/migrations/V000__setup_entornos_negocio.sql` estaban las cinco, en las líneas 6, 12, 18, 24 y 30); lo que la deja inútil es invalidarla. Lo comprobé: entrar con la contraseña antigua dio ORA-01017.

**7. ¿Qué demuestra la prueba de persistencia y por qué se ejecuta después de reubicar?**

Respuesta:

Demuestra que el arreglo aguanta un reinicio o que se recree el contenedor, y que no funcionaba solo "porque sí" en ese momento. Se hace justo después de reubicar porque es cuando hay que comprobar que las rutas nuevas y los datos siguen ahí.

### Instancia, arranque y parámetros (E, F)

**8. Con tus evidencias: tres datos que pertenecen a la instancia y tres que pertenecen a la base de datos.**

Respuesta:

De la instancia (lo que está en marcha en memoria): su nombre y estado (`FREE`), la hora a la que arrancó (`2026-10-26 18:01:20`) y su memoria compartida, 1.603.398.928 bytes. De la base de datos (lo que está guardado en disco): su identificador (DBID `1509902213`), cuándo se creó (`2026-07-05`) y que archiva el redo (`ARCHIVELOG`).

**9. ¿Qué lee Oracle en NOMOUNT, en MOUNT y en OPEN? Relaciónalo con ORA-01507 y ORA-01219.**

Respuesta:

En NOMOUNT solo lee su configuración y arranca; todavía no ha abierto el control file, y por eso preguntar a `v$database` da ORA-01507. En MOUNT ya ha abierto el control file y sabe que la base tiene 16 datafiles, pero aún no los ha abierto, así que consultar `DBA_TABLES` da ORA-01219. En OPEN abre todos los archivos y ya se puede trabajar con los datos.

**10. Diferencia entre v$parameter y v$spparameter con el ejemplo de db_files de tu evidencia.**

Respuesta:

`V$PARAMETER` dice el valor que se está usando ahora mismo y `V$SPPARAMETER` el que está guardado para el próximo arranque. Con `db_files` se ve bien: en memoria valía 200 y en el SPFILE 300. Cuando intenté cambiarlo solo en memoria, dio ORA-02095, porque ese parámetro no se puede cambiar en caliente.

**11. ¿Por qué PROCESSES rechaza el cambio en memoria aunque v$parameter lo marque IMMEDIATE?**

Respuesta:

Aunque `v$parameter` decía que se podía cambiar al momento (`IMMEDIATE`), al intentarlo dio ORA-02097 y ORA-02095 (y cambiar `memory_size` dio ORA-62352). Es decir, en esta configuración no se puede cambiar en caliente: hay que guardarlo para el siguiente arranque y reiniciar. La prueba real manda más que lo que dice la vista.

### Memoria y procesos (G, H)

**12. ¿Qué modelo de gestión de memoria usa tu instancia? Justifícalo con tres parámetros.**

Respuesta:

Oracle reparte solo la memoria compartida (ASMM), pero no toda la memoria (eso sería AMM). Se ve en tres parámetros: `memory_target=0` (no gestiona toda la memoria en bloque), `sga_target=1536M` (sí gestiona la parte compartida) y `pga_aggregate_target=512M` (la memoria de las sesiones va aparte). Además, `db_cache_size=0` deja que Oracle decida cuánto dedica a la caché.

**13. Explica las cifras de tu experimento de caché: lecturas lógicas, físicas y tasa de acierto.**

Respuesta:

En la primera ronda hubo 463 lecturas lógicas y 267 físicas; en la segunda, 247 lógicas y ninguna física. La segunda vez todo lo necesario ya estaba en memoria, así que no tuvo que ir al disco ni una vez: acertó el 100 % en la caché. Las lógicas no se pueden comparar como si fueran físicas: lógica es leer de memoria, física es tener que ir al disco antes.

**14. Compara literales y variables de enlace (bind variables) con tus cifras de análisis (parse) y de V$SQL.**

Respuesta:

Con los valores escritos dentro de la consulta (literales), Oracle tuvo que analizar 1008 consultas como si fueran nuevas, tardó 410 ms y guardó 450 versiones que ocupaban 16.097 KB. Con variables de enlace la analizó una sola vez, el tiempo fue despreciable (0 ms) y ocupó un único cursor de 39 KB. Reutilizar la misma consulta ahorra CPU y memoria.

**15. Relaciona el SPID de LGWR de v$process con el PID de /proc. ¿Por qué docker top muestra otro número?**

Respuesta:

Oracle dice que LGWR es el proceso 981 y, dentro del contenedor, `/proc` también tiene el 981 (`db_lgwr_FREE`): es el mismo. `docker top` enseña otro número porque lo mira desde fuera, desde el ordenador anfitrión, y el contenedor tiene su propia numeración de procesos.

### Contenedores (I)

**16. Explica con tu evidencia por qué SYS ve 16 datafiles desde la raíz y 9 desde FREEPDB1.**

Respuesta:

Desde la raíz se ve toda la base: 4 archivos de la propia raíz, 3 de la plantilla PDB$SEED y 9 de FREEPDB1, en total 16. Dentro de FREEPDB1 solo se ven los suyos, que son 9.

**17. ¿Por qué LAB4_ANALISTA recibe ORA-00942 y no "privilegios insuficientes" al consultar DBA_TABLES?**

Respuesta:

Porque Oracle no le dice a un usuario sin permisos que el objeto existe: le contesta como si no existiera (ORA-00942). Así no da pistas de lo que hay. En la evidencia, `LAB4_ANALISTA` recibió ORA-00942 en `DBA_TABLES`, en `V$SESSION` y en la tabla que consultó, y ORA-01031 al intentar pasar a la raíz.

**18. ¿Qué diferencia hay entre C##LAB4_AUDITOR y C##OPS_RO? ¿Qué sentencia los igualaría?**

Respuesta:

`C##LAB4_AUDITOR` solo ve los datos de la raíz (contenedores 0 y 1), mientras que `C##OPS_RO` ve los de todos los contenedores (`CONTAINER_DATA=ALL`) y tiene permisos para observar. Para que el auditor viera lo mismo, desde `CDB$ROOT`: `ALTER USER C##LAB4_AUDITOR SET CONTAINER_DATA = ALL CONTAINER = CURRENT;`, además de los permisos de lectura que necesite.

**19. ¿Qué ventaja tiene GRANT READ ANY TABLE ON SCHEMA frente a conceder tabla por tabla? ¿Y qué riesgo?**

Respuesta:

La ventaja es que con una sola orden das lectura a todas las tablas de un esquema, sin ir una a una y sin abrir otros esquemas. El riesgo es que también vale para las tablas que se creen en el futuro, así que el usuario puede acabar viendo más de lo que se pensó al principio.

**20. ¿Qué valor tiene COMMON_USER_PREFIX en tu base y qué consecuencia tuvo en el bloque 3a de 10-ciclo-vida-pdb?**

Respuesta:

Vale `C##`: los usuarios comunes tienen que empezar así. En el bloque **3a** intenté crear `lab4_local` desde la raíz sin ese prefijo y dio **ORA-65096**, porque desde la raíz solo se crean usuarios comunes y el nombre no lo cumple. En el **3b** pasó lo contrario: crear `c##lab4_comun` desde `FREEPDB1` dio **ORA-65094**, porque un usuario común no se puede crear desde una PDB.

### Archivos (J)

**21. Clasifica los archivos de tu evidencia 11 en "son la base de datos" y "relacionados". ¿Dónde va el password file y por qué?**

Respuesta:

Son la base de datos: los 16 datafiles, los 3 tempfiles, los 2 control files y los 3 redo logs. Son relacionados: el SPFILE, el password file, el ADR y los cinco archivados y copias automáticas. El password file va en relacionados porque solo sirve para identificar a los administradores; no guarda datos.

**22. Explica por qué academia01.dbf mide 104 865 792 bytes en Linux si v$datafile dice 100 MB.**

Respuesta:

Oracle dice 100 MiB, que son 104.857.600 bytes. Linux dice 104.865.792. La diferencia son 8.192 bytes, exactamente un bloque de Oracle: el archivo tiene un bloque más, de cabecera, que Oracle no cuenta en el tamaño que enseña.

**23. ¿Qué dos puntos únicos de fallo (single points of failure) ves en los control files y en el redo de tu base?**

Respuesta:

Primero, los dos control files están en la misma carpeta: si falla ese disco, se pierden los dos a la vez. Segundo, cada grupo de redo tiene una sola copia: si se estropea, no hay otra de la que tirar.

**24. ¿Por qué el ADR fuera del volumen es un problema operativo aunque la base no pierda datos?**

Respuesta:

Porque ahí se guardan el alert log y las trazas, que es lo que miras cuando algo falla. Al estar en `/opt/oracle/diag`, fuera del volumen, si se recrea el contenedor se pierden. Los datos siguen a salvo, pero te quedas sin pistas para investigar qué pasó.

### Bloque y fila (K)

**25. Descompón el ROWID de tu estudiante 101 en objeto, bloque y fila, y comprueba cada trozo con DBMS_ROWID.**

Respuesta:

El ROWID es `AAAR2kAAAAAAAMPAAF`, que es como la dirección exacta de la fila. Desmontado con `DBMS_ROWID` da: **objeto** `73124` (la tabla), **archivo relativo** `1024` (el archivo 16), **bloque** `783` y **fila** `5` dentro del bloque. Cada trozo sale con `ROWID_OBJECT`, `ROWID_RELATIVE_FNO`, `ROWID_BLOCK_NUMBER` y `ROWID_ROW_NUMBER`.

**26. Del volcado: ¿qué significan nrow, fsbo, fseo y avsp? Demuestra que avsp = fseo - fsbo con tus números.**

Respuesta:

`nrow` es cuántas filas hay en el bloque; `fsbo` es dónde empieza el hueco libre y `fseo` dónde termina (ahí empiezan las filas); `avsp` es el espacio libre que queda. Con mis números: `0x427 - 0x0c6 = 0x361`, es decir, 1063 − 198 = 865 bytes, que es justo el `avsp`.

**27. Explica la línea de la ITL con Lck = 90 y Flag --U-. ¿Qué es la limpieza diferida de bloques (delayed block cleanout)?**

Respuesta:

La ITL es la lista de transacciones que han tocado el bloque. `Lck=90` dice que esa transacción bloqueó 90 filas, que son todas las del bloque (`nrow=90`). El flag `--U-` indica que la transacción ya terminó, pero que el bloque todavía no se ha "limpiado". La limpieza diferida consiste en eso: al hacer COMMIT, Oracle no recorre todos los bloques para quitar las marcas, y lo deja para la siguiente vez que alguien lea el bloque. Así el COMMIT es más rápido.

**28. Calcula los 78 bytes de la fila 101 a partir de cabecera, bytes de longitud y datos.**

Respuesta:

3 bytes de cabecera de la fila, más 7 bytes que indican lo que mide cada una de las 7 columnas, más 68 bytes de datos (`VSIZE=68`): `3 + 7 + 68 = 78` bytes, lo mismo que dice el volcado (`tl:78`).

### Capacidad y coste (L)

**29. Calcula bfr y b de ACA_ESTUDIANTES con la fórmula de la Unidad 3 y explica por qué la tabla real tiene 244 bloques.**

Respuesta:

Con filas de 76 bytes, bloques de 8 KB y un 10 % reservado, la fórmula de la Unidad 3 da 95 filas por bloque y 211 bloques; con el ajuste de Oracle, 93 filas por bloque y 216 bloques. En la realidad ocupa 244 bloques con datos (256 reservados) porque la fórmula es una aproximación: no tiene en cuenta del todo las cabeceras, que no todos los bloques quedan igual de llenos ni cómo reserva Oracle el espacio por trozos.

**30. Con tus cifras de 5a, 5b y 5c, ¿cuánto cuesta una lectura lógica, una física aleatoria y un bloque secuencial?**

Respuesta:

Una lectura de memoria (lógica) costó unos **1,38 μs**; una lectura de disco de un bloque suelto, unos **5,2 μs**; y leer 4595 bloques seguidos llevó **17 ms**, unos **3,7 μs por bloque**. Son cifras de mi contenedor, que tiene detrás cachés del ordenador: en un disco duro de verdad la lectura física sería muchísimo más lenta.

**31. Recalcula el umbral de rentabilidad de la sección 5d suponiendo un HDD (Bw = 150 MB/s, lat = 5 ms).**

Respuesta:

En un disco duro, leer un bloque de 8 KB a 150 MB/s cuesta unos 0,053 ms, pero cada vez que hay que saltar a otro sitio se pagan además unos 5 ms de espera. Leer `b` bloques seguidos cuesta unos `5 + b × 0,053` ms (una espera y luego todo de corrido); leerlos sueltos, `b × 5,053` ms (una espera por cada uno). Igualando, sale `b ≈ 1`: en cuanto hay que leer dos bloques o más, compensa leerlos seguidos. Es una aproximación: depende de si la espera se paga por cada lectura o por cada petición de varios bloques.

**32. ¿Por qué la "lectura física" sale en microsegundos en el contenedor? ¿Invalida eso el método?**

Respuesta:

Porque el disco del contenedor es virtual y el sistema operativo del ordenador guarda en su propia memoria lo que se ha leído hace poco: lo que Oracle llama "lectura física" muchas veces viene en realidad de esa memoria, y por eso tarda microsegundos. El método sigue valiendo, pero las cifras no se pueden extrapolar a un disco real: para eso habría que medir en el disco de verdad.

### Filas migradas y encadenadas (M)

**33. Diferencia migración (row migration) y encadenamiento (row chaining): causa, cómo se detecta y cómo se cura.**

Respuesta:

Una fila **migrada** es una que cabía en su bloque, pero al actualizarla creció y ya no cabe: Oracle la mueve a otro bloque y deja en el original una nota con la nueva dirección. Una fila **encadenada** es una que es tan grande que no cabe en ningún bloque y se reparte entre varios. Las dos se detectan con `CHAIN_CNT` y con la estadística de lecturas de filas partidas. La migración se arregla reorganizando la tabla (`ALTER TABLE ... MOVE`) y reconstruyendo después los índices; el encadenamiento de filas enormes muchas veces no tiene arreglo.

**34. Explica el 3,2 de lecturas lógicas por búsqueda de la sección 4 a partir del 20 % de filas migradas.**

Respuesta:

Si el 20 % de las filas están migradas, una de cada cinco búsquedas llega al bloque original, encuentra la nota con la dirección nueva y tiene que hacer un salto más. Por eso, en lugar de 3 lecturas por búsqueda, sale un poco más: mi medida dio 3200 lecturas lógicas en 1000 búsquedas (3,2 de media) y 200 saltos extra (`table fetch continued row`).

**35. ¿Por qué ALTER TABLE ... MOVE deja el índice UNUSABLE? ¿Qué harías en producción?**

Respuesta:

Porque `MOVE` cambia de sitio todas las filas, y el índice sigue apuntando a las direcciones antiguas: ya no sirve y Oracle lo marca como inutilizable. En producción lo haría en una ventana de mantenimiento, revisando antes qué depende de esa tabla y reconstruyendo los índices justo después. En la práctica, tras el `REBUILD` la PK volvió a estar VALID.

### Autopsia y trabajo profesional (N, O)

**36. Elige tres hallazgos de tu autopsia (15) y escribe para cada uno riesgo, acción y prioridad.**

Respuesta:

1) **Prioridad 1: redo y control files (riesgo alto).** Hay tres grupos de redo con una sola copia cada uno y los dos control files están en la misma carpeta (`/opt/oracle/oradata/FREE/`). Si se estropea el redo que se está usando, se pueden perder cambios ya confirmados; si falla ese disco, se pierden los dos control files. **Qué haría:** añadir una segunda copia a cada grupo de redo en otro sitio (mejor en otro disco) y llevar una copia del control file fuera de esa carpeta.

2) **Prioridad 2: no hay FRA (riesgo alto).** `db_recovery_file_dest` está vacío, el tamaño a 0, y hay cinco archivados (353 MB) acumulándose en `$ORACLE_HOME/dbs`. Pueden crecer hasta llenar el disco, y entonces la base se para porque no puede archivar. **Qué haría:** configurar la FRA con un tamaño máximo y llevar ahí los archivados (es lo que se hace en el Lab 5).

3) **Prioridad 3: Flashback desactivado (riesgo medio).** `FLASHBACK = NO` aunque la base ya archiva el redo. Sin Flashback, para deshacer un error humano habría que restaurar una copia entera. **Qué haría:** activarlo en cuanto esté la FRA, porque la necesita.

Son los tres primeros hallazgos de `docs/bitacora/lab4-autopsia.md`, en el mismo orden. Las estadísticas de altura de los índices y los errores ORA ya conocidos quedan detrás, como prioridades 4 y 5.

**37. ¿Por qué C##OPS_RO y no SYSTEM para observar? ¿Qué no puede hacer C##OPS_RO?**

Respuesta:

Porque para mirar no hace falta poder cambiar nada: con `C##OPS_RO` solo se puede leer, y si alguien se equivoca o le roban la contraseña, el daño es mínimo. SYSTEM, en cambio, puede hacerlo casi todo. `C##OPS_RO` no puede modificar datos ni tiene ningún privilegio ANY de escritura; la verificación final lo confirmó.

**38. ¿Qué dos vías de exposición de contraseñas corrige este laboratorio respecto al Lab 3?**

Respuesta:

La primera: las contraseñas estaban escritas tal cual en la migración `database/migrations/V000__setup_entornos_negocio.sql` (cinco, en las líneas 6, 12, 18, 24 y 30). La segunda: el script de despliegue entraba como `sys/$ORACLE_PWD@...`, con la contraseña en la línea de comandos, donde cualquiera podía verla. Ahora `08-aplicar-migraciones.sh` entra con `/ as sysdba`, sin contraseña, y las antiguas de V000 ya no funcionan (dan ORA-01017).

## Preguntas tipo examen

Van en el orden del enunciado. Cuando la pregunta pide dos opciones, pongo las dos letras.

**P1.** Un DBA ejecuta SHUTDOWN IMMEDIATE y copia todos los datafiles, control files y redo logs online. ¿Qué afirmaciones son correctas sobre esta copia? (Elige dos.)

Letra: **A y D**
Justificación: tras `SHUTDOWN IMMEDIATE` la base está cerrada y todo coherente, así que la copia es consistente (A), y si se vuelven a poner los archivos en su sitio se puede arrancar con normalidad (D).

**P2.** Un tablespace de usuario tiene su datafile en un disco que se va a retirar. La base es Standard Edition y puede tener una breve indisponibilidad de ese tablespace. ¿Qué secuencia es correcta?

Letra: **B**
Justificación: se deja el tablespace fuera de servicio, se copia el archivo, se le dice a Oracle la ruta nueva con RENAME DATAFILE y se vuelve a poner en servicio.

**P-D1.** Un propietario de esquema solo debe poseer objetos; nadie debe poder iniciar sesión con él, ni siquiera conociendo una contraseña antigua. ¿Qué sentencia lo consigue?

Letra: **C**
Justificación: con NO AUTHENTICATION la cuenta no tiene contraseña con la que entrar, así que da igual que alguien conozca una antigua.

**P3.** Un DBA consulta v$instance y v$database en una base abierta. ¿Qué dos afirmaciones son correctas? (Elige dos.)

Letra: **A y C**
Justificación: STARTUP_TIME cambia cada vez que arranca la instancia; CREATED es la fecha en que se creó la base y no cambia.

**P4.** La instancia está en estado NOMOUNT. ¿Qué dos operaciones puede realizar el DBA en este estado? (Elige dos.)

Letra: **A y C**
Justificación: en NOMOUNT se pueden mirar los parámetros y volver a crear el control file, pero todavía no se puede consultar el diccionario.

**P5.** ¿En qué etapa debe estar la base para ejecutar ALTER DATABASE ARCHIVELOG?

Letra: **B**
Justificación: hay que tener la base montada pero no abierta.

**P6.** Un DBA ejecuta ALTER SYSTEM SET open_cursors = 500; en una instancia que arrancó con SPFILE. ¿Cuál es el resultado?

Letra: **B**
Justificación: si se arrancó con SPFILE y no se dice SCOPE, el cambio se aplica en memoria y se guarda en el SPFILE a la vez.

**P7.** Conectado a FREEPDB1, un DBA ejecuta `ALTER SYSTEM SET processes = 300 SCOPE = SPFILE;`. ¿Qué ocurre?

Letra: **C**
Justificación: PROCESSES es de toda la instancia y no se puede cambiar desde una PDB: da ORA-65040.

**P8.** ¿Qué dos sentencias permiten recuperar una instancia que no arranca por un valor erróneo escrito en el SPFILE? (Elige dos.)

Letra: **A y C**
Justificación: se arranca con un PFILE que esté bien y después se vuelve a crear el SPFILE a partir de él.

**P9.** Una instancia tiene MEMORY_TARGET = 0, SGA_TARGET = 2G y DB_CACHE_SIZE = 512M. ¿Qué afirmación es correcta?

Letra: **B**
Justificación: con MEMORY_TARGET a 0 Oracle reparte solo la memoria compartida (ASMM), y DB_CACHE_SIZE marca lo mínimo que tendrá la caché.

**P10.** ¿Qué dos estructuras forman parte de la PGA de un proceso servidor dedicado? (Elige dos.)

Letra: **A y D**
Justificación: la zona para ordenar y la memoria de la sesión son privadas de cada proceso, así que van en su PGA.

**P-G1.** Una aplicación ejecuta miles de veces por minuto la misma consulta cambiando solo un literal en el WHERE. V$SQL muestra miles de cursores casi idénticos y la CPU de análisis es alta. ¿Cuál es la solución definitiva recomendada?

Letra: **B**
Justificación: con variables de enlace la consulta es siempre la misma, se analiza una vez y se reutiliza.

**P-G2.** En V$SQL_WORKAREA, una ordenación muestra LAST_EXECUTION = '6 PASSES' y LAST_TEMPSEG_SIZE de varios MB. ¿Qué significa?

Letra: **B**
Justificación: no cupo en memoria y tuvo que apoyarse en el disco (TEMP), repasando los datos varias veces.

**P11.** Un usuario ejecuta COMMIT. ¿Qué proceso debe completar su escritura antes de que el COMMIT devuelva el control?

Letra: **C**
Justificación: LGWR tiene que haber escrito el redo en disco antes de dar el COMMIT por hecho.

**P12.** ¿Qué dos procesos de background son obligatorios en cualquier instancia de Oracle? (Elige dos.)

Letra: **B y D**
Justificación: PMON y SMON siempre tienen que estar; sin ellos la instancia no funciona.

**P13.** Conectado como SYS a CDB$ROOT ejecutas SELECT con_id, COUNT(*) FROM v$datafile GROUP BY con_id; y obtienes filas para CON_ID 1, 2 y 3. Después ejecutas ALTER SESSION SET CONTAINER = FREEPDB1; y repites la consulta. ¿Qué obtienes?

Letra: **B**
Justificación: dentro de FREEPDB1 solo se ven sus propios archivos, los del contenedor 3.

**P14.** Un usuario común C##AUDIT tiene CREATE SESSION y SELECT_CATALOG_ROLE concedidos con CONTAINER = ALL. Conectado a la raíz, consulta CDB_TABLESPACES y solo ve filas de CON_ID 1. ¿Qué sentencia le permite ver las de todas las PDB desde la raíz?

Letra: **B**
Justificación: con CONTAINER_DATA=ALL (y CONTAINER=CURRENT) un usuario común ve desde la raíz los datos de todas las PDB, siempre dentro de sus permisos.

**P15.** ¿Qué dos afirmaciones sobre GRANT READ ANY TABLE ON SCHEMA hr TO analista; (23ai y posteriores) son correctas? (Elige dos.)

Letra: **A y D**
Justificación: sirve para las tablas que hay y para las que se creen después en HR, y no da acceso a ningún otro esquema.

**P16.** ¿Qué dos archivos forman parte de la base de datos Oracle (database) y no son solo archivos relacionados? (Elige dos.)

Letra: **B y D**
Justificación: los control files y los redo logs en uso son parte de la base; sin ellos no funciona.

**P17.** Una base en NOARCHIVELOG tiene dos control files en el mismo disco y un único miembro por grupo de redo. Se pierde ese disco. ¿Qué es cierto?

Letra: **C**
Justificación: sin copias en otro sitio y sin redo archivado, solo queda restaurar la última copia y se pierde todo lo que pasó después.

**P18.** En un tablespace BIGFILE, DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) sin segundo argumento devuelve un número que no coincide con el volcado del bloque. ¿Por qué?

Letra: **B**
Justificación: si no le dices que es BIGFILE, la función interpreta el ROWID como si fuera de un tablespace normal y calcula mal el bloque.

**P19.** Una tabla se crea con PCTFREE 10 en un tablespace con ASSM. ¿Qué dos afirmaciones son correctas? (Elige dos.)

Letra: **A y B**
Justificación: PCTFREE reserva espacio para que las filas puedan crecer y marca cuándo el bloque deja de aceptar filas nuevas.

**P20.** Una tabla tiene r = 2 000 000 de filas de R = 180 bytes, bloques de 8192 bytes con 96 bytes de cabecera y PCTFREE 10. Según la Unidad 3, ¿cuántos bloques necesita?

Letra: **B**
Justificación: caben 40 filas por bloque, y 2.000.000 / 40 = 50.000 bloques.

**P21.** Una sesión lee una tabla con un recorrido completo y el evento de espera dominante es "db file scattered read". ¿Qué indica?

Letra: **B**
Justificación: está leyendo del disco muchos bloques de golpe, que es lo típico de leer una tabla entera.

**P22.** Tras actualizar muchas filas de una tabla, la estadística "table fetch continued row" crece. ¿Qué dos acciones son adecuadas? (Elige dos.)

Letra: **A y C**
Justificación: LIST CHAINED ROWS dice qué filas están afectadas, y MOVE con más espacio libre por bloque las reorganiza (después hay que reconstruir los índices).

**P23.** Una fila mide 12 000 bytes y el tablespace usa bloques de 8 KB. ¿Qué es cierto?

Letra: **B**
Justificación: la fila no cabe en un bloque de 8 KB, así que siempre irá repartida en varios; reorganizar no lo arregla.

**P24.** Necesitas un informe diario del estado de una base de producción (archivos, espacio, errores del alert log) con el mínimo riesgo. ¿Qué enfoque sigue el mínimo privilegio?

Letra: **B**
Justificación: un usuario común de solo lectura que vea todos los contenedores y tenga permiso solo para leer el alert log es lo justo y necesario.

**P25.** ¿Qué contenedor de una CDB es una plantilla de solo lectura que se usa para crear PDB nuevas?

Letra: **B**
Justificación: PDB$SEED es la plantilla de la que salen las PDB nuevas.

**P26.** Conectado a FREEPDB1 ejecutas CREATE USER c##rep IDENTIFIED BY ...;. ¿Qué ocurre si COMMON_USER_PREFIX vale C##?

Letra: **C**
Justificación: desde una PDB no se pueden crear usuarios con el prefijo de los comunes: da ORA-65094 (me pasó en el bloque 3b).

**P27.** ¿Qué secuencia elimina una PDB abierta junto con sus archivos?

Letra: **B**
Justificación: primero se cierra la PDB y luego se borra con INCLUDING DATAFILES.

**P28.** ¿Qué dos vistas devuelven información aunque la base esté solo en MOUNT? (Elige dos.)

Letra: **A y C**
Justificación: V$DATAFILE y V$LOG sacan la información del control file, que ya está abierto en MOUNT; las vistas DBA necesitan la base abierta.

**P29.** `V$FIXED_VIEW_DEFINITION` muestra que `V$LOG` lee `X$KCCLE`. ¿Qué indica el prefijo KCC?

Letra: **A**
Justificación: KCC son las estructuras internas del control file.

**P30.** En una CDB, ¿dónde se definen las vistas CDB_?

Letra: **B**
Justificación: están en la raíz y en cada PDB; desde una PDB solo enseñan lo de esa PDB.

**P31.** ¿Qué afirmación sobre los tempfiles es correcta?

Letra: **B**
Justificación: no hace falta copiarlos como los demás archivos: si se pierden, se vuelven a crear vacíos.

**P32.** Con la base abierta, un DBA borra por error el único SPFILE desde el sistema operativo. ¿Qué es cierto?

Letra: **B**
Justificación: la instancia ya arrancada sigue funcionando, y el SPFILE se puede volver a crear con lo que tiene en memoria (CREATE SPFILE FROM MEMORY).

**P33.** ¿Qué vista muestra qué usuarios están en el password file y con qué privilegios administrativos?

Letra: **B**
Justificación: V$PWFILE_USERS enseña quién está en el password file y con qué privilegios.

**P34.** ¿Qué dos elementos forman parte de la cabecera de un bloque de datos de Oracle? (Elige dos.)

Letra: **A y B**
Justificación: en la cabecera están la lista de transacciones (ITL) y el directorio de filas.

**P35.** Un tablespace se gestiona localmente con AUTOALLOCATE y bloques de 8 KB. Un segmento nuevo crece. ¿Qué tamaños de extensión verás primero?

Letra: **B**
Justificación: primero reserva trozos de 8 bloques (64 KB) y, cuando el segmento crece, de 128 bloques (1 MB).

**P36.** ¿Qué significa SEGMENT_SPACE_MANAGEMENT = AUTO en DBA_TABLESPACES?

Letra: **B**
Justificación: el espacio libre de cada segmento lo controla Oracle solo, con mapas de bits (ASSM).

**P37.** Desde 23ai, CREATE TABLESPACE t DATAFILE '/u02/t01.dbf' SIZE 100M; sin más cláusulas crea un tablespace...

Letra: **B**
Justificación: desde 23ai, si no se dice otra cosa, el tablespace se crea BIGFILE y gestionado localmente.

**P38.** Una consulta hace 4 lecturas lógicas por ejecución y 0 físicas. ¿Qué es cierto?

Letra: **A**
Justificación: todo lo que necesitaba ya estaba en memoria; no tuvo que ir al disco.

**P39.** ¿Qué dos factores reducen el factor de bloqueo (bfr) de una tabla? (Elige dos.)

Letra: **A y B**
Justificación: si reservas más espacio libre (PCTFREE) o las filas son más grandes, caben menos filas en cada bloque.

**P40.** Un DBA ejecuta ALTER SYSTEM FLUSH BUFFER_CACHE; en producción "para medir". ¿Cuál es la consecuencia más probable?

Letra: **B**
Justificación: vacía la memoria y todo el mundo tiene que volver a leer del disco hasta que se llena otra vez: picos de lentitud.

**P41.** ¿Cuál es la diferencia entre una fila migrada y una encadenada?

Letra: **B**
Justificación: la migrada cabía y se tuvo que mudar al crecer; la encadenada no cabe en ningún bloque y va repartida.

**P42.** Tras ALTER TABLE ventas MOVE; las consultas por clave van más lentas y DBA_INDEXES muestra STATUS = UNUSABLE. ¿Qué haces?

Letra: **A**
Justificación: tras un MOVE los índices quedan inservibles y hay que reconstruirlos.

**P43.** ¿Qué vista permite leer el alert log con SQL?

Letra: **A**
Justificación: V$DIAG_ALERT_EXT deja leer el alert log con consultas normales.

**P44.** DBA_TABLESPACE_USAGE_METRICS muestra un tablespace al 92 % de su tamaño máximo. ¿Qué dos acciones son razonables? (Elige dos.)

Letra: **A y B**
Justificación: darle más espacio (agrandarlo o añadir un archivo) y mirar qué está creciendo, antes de que se llene del todo.

**P45.** En una CDB, ¿qué dos elementos son compartidos por todas las PDB? (Elige dos.)

Letra: **A y B**
Justificación: la memoria compartida con los procesos de fondo y el redo son de toda la CDB.

**P46.** Un usuario local de una PDB con solo CREATE SESSION ejecuta ALTER SESSION SET CONTAINER = CDB$ROOT;. ¿Qué ocurre?

Letra: **B**
Justificación: un usuario local no tiene permiso para pasar a la raíz y recibe ORA-01031.
