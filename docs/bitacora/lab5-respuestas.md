# Lab 5 · Respuestas

En cada respuesta indico de qué evidencia saco los datos (todas están en `docs/bitacora/lab5/evidencia/`). Las cifras son las de mi base; cuando no coinciden con las del enunciado, explico por qué.

## Puntos de control y retos por Parte

### Parte A · Buena práctica: Lee el paso 6

> En la copia del Lab 3 aparecían cinco datafiles fuera del volumen; ahora, ninguno. Anótalo en tus respuestas.

Respuesta:

A mí me salió "ninguno" en las dos copias, tanto en la del Lab 3 (`00-backup-lab3`) como en la del Lab 4 (`00-backup-lab4`). En mi imagen la carpeta `$ORACLE_HOME/dbs` ya estaba dentro del volumen (lo anoté en el Lab 4), así que nunca tuve archivos fuera. Lo que sí confirma la copia del Lab 4 es que mover los datafiles en aquel laboratorio no dejó nada suelto: la copia ocupa 670 MB comprimida y no tuvo que guardar ningún archivo aparte.

### Parte B · Reto: Comprueba el bfr de pedido con tus propias manos

Respuesta:

Contando bloque a bloque: hay 5220 bloques con pedidos y la media sale 191,6 filas por bloque. Casi todos tienen 191 o 192 (2301 y 2867 bloques), unos pocos 196 o 197, uno llega a 200 y el último solo tiene 2. Las estadísticas, en cambio, dicen `1 000 000 / 5320 = 188`. No coinciden por dos cosas. Primero, las estadísticas cuentan los 5320 bloques que tiene reservados la tabla, incluidos los de cabecera, y yo solo cuento los que tienen filas. Segundo, no todas las filas miden lo mismo (un importe o un código postal pueden ocupar un byte más o menos), así que en unos bloques caben más filas que en otros. El bloque de 2 filas es el último, el que quedó casi vacío al terminar la carga.

### Parte C · Reto: Calcula antes de medir

Respuesta:

1. A mano, suponiendo 30 bytes por entrada, caben `7996 / 30 = 266` entradas en cada hoja. Llenándolas al 90 % salen unas `100 000 / 266 / 0,9 ≈ 418` hojas, y con 543 hijos por bloque de rama basta una sola raíz: **altura 2**.
2. Al medirlo salió **altura 3**: 501 hojas y 3 bloques de rama. Me equivoqué porque cada entrada real ocupa 35,9 bytes, no 30, y las de rama 18,2, así que en un bloque de rama caben 441 hijos, no 543. Con 501 hojas ya no caben todas debajo de una sola raíz y hace falta un nivel más.
3. Los dos índices tienen 100 000 entradas, pero PK_CLIENTE ocupa 187 hojas casi llenas (99,6 %) y UX_CLI_EMAIL 501 hojas al 89,6 %. La diferencia está en cómo llegaron las claves. PK_CLIENTE se fue llenando durante la carga con números en orden (1, 2, 3…): Oracle llenaba cada hoja del todo y abría otra. UX_CLI_EMAIL se creó después, de golpe, y Oracle dejó un 10 % libre en cada hoja a propósito. Además, un email ocupa bastante más que un número, y por eso necesita casi el triple de hojas.

### Parte D · Reto: El índice cubriente que sí pedirías

Respuesta:

No lo haría. Q9 ya cuesta **5 lecturas** con IX_PED_FECHA, porque los 20 pedidos más recientes están juntos en uno o dos bloques. Para ahorrarme como mucho una o dos lecturas tendría que meter todas las columnas en el índice, que sería casi copiar entera una tabla de **42 MB** (el índice actual ocupa 22 MB). No compensa.

### Parte E · Reto: Dibuja tu curva

Respuesta (evidencia `04-agrupamiento-equilibrio`, sección 3):

Con los datos de la curva: el índice malo (IX_PED_CLIENTE) empieza a leer más que la tabla entera (5232 lecturas) hacia el 0,54 % de las filas (al 0,5 % lee 4875 y al 1 % ya 9920); el bueno (IX_PED_FECHA) aguanta hasta cerca del 66 % (al 50 % lee 3938 y al 100 %, 7875); y el optimizador deja de usar el índice mucho antes, entre el 0,1 % y el 0,2 %. No coinciden porque no miden lo mismo. Los cruces cuentan lecturas en memoria, donde saltar de un sitio a otro cuesta lo mismo que leer seguido. El optimizador, en cambio, piensa en el disco, donde los saltos del índice son mucho más caros que leer la tabla de corrido, y por eso se pasa antes a leer la tabla entera, justo donde dice la fórmula (0,11 %).

### Parte F · Reto: Revisión de código como en un equipo real

Respuesta:

El comentario que dejaría en el PR:

> **issue (blocking):** `SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL'` no puede usar los índices: al envolver las columnas en funciones, Oracle ya no puede buscar en ellos (regla 1), y al ser un OR, en cuanto una de las dos partes no tiene índice se lee la tabla entera (regla 5). Medido: 1487 lecturas, recorriendo toda la tabla.
> Propuesta: `telefono LIKE '600%' OR apellidos = 'Gil'`. "Que empiece por 600" sí se puede buscar en el índice, y los apellidos ya se guardan con la primera letra en mayúscula, así que `UPPER` sobra. Medido: 722 lecturas usando los dos índices, con las mismas 981 filas.
> **question:** ¿seguro que buscas a alguien que se apellide solo "Gil"? En la tabla los apellidos son "Primero Segundo", y `UPPER(apellidos) = 'GIL'` no encuentra a nadie. Si lo que quieres es el segundo apellido Gil (6121 clientes), eso es buscar "algo que termine en Gil", y ahí no hay índice normal que ayude.

Los dos índices los creé solo para la prueba y los borré después, como pide el reto.

### Parte G · Reto: Defiende tu propio índice

Respuesta:

Propongo un índice sobre el teléfono del cliente (`ix_cli_telefono`) para Q5, la consulta que identifica a quien llama al centro de atención por su email o su teléfono, que V005 deja sin resolver. Pasado por las cinco preguntas:

1. **¿Hace falta?** Sí: hoy Q5 lee 1486 bloques, la tabla entera, porque la parte del teléfono no tiene índice.
2. **¿Sirve?** Sí: hay 99 952 teléfonos distintos en 100 000 clientes, así que cada búsqueda devuelve una fila o poco más.
3. **¿Cuánto cuesta escribir?** Cada alta de cliente pasa de 10,3 a 12,1 bloques modificados (los 2 de más que cuesta cada índice) y de 1462 a 1644 bytes de redo. Como se dan de alta muchos menos clientes que pedidos, es asumible.
4. **¿Repite otro índice?** No, ninguno empieza por el teléfono.
5. **¿Y luego?** Con el índice, Q5 baja a 6 lecturas. Lo dejo como V006 en la rama `feat/10-v006-ix-cli-telefono`, sin fusionar, para que lo revise otra persona; en la base lo borré al terminar la prueba.

Mi conclusión es que compensa: pasa de 1486 a 6 lecturas a cambio de 2 bloques más por cada cliente nuevo.

### Parte H · Reto: Diagnostica sin ver el script

Respuesta:

Este reto necesita un índice estropeado que crea el profesor, y todavía no existe en mi base, así que no lo he podido hacer. Cuando esté, lo miraré igual que en la Parte H: con `grafico-indice.sh` para ver cómo están repartidas las hojas (vacío a la izquierda y lleno a la derecha es una cola; huecos por todas partes es fragmentación; todo entre el 60 y el 80 % es un índice normal), con `VALIDATE STRUCTURE` para contar las entradas borradas y las hojas reales, y buscando una consulta que lea de más. El diagnóstico irá como comentario en el Issue #10.

### Parte H · Punto de control: Antes de pasar a la durabilidad

Respuesta:

- Una búsqueda por clave primaria cuesta **4 lecturas** porque el índice tiene 3 niveles (raíz, rama y hoja) y después hay que ir al bloque de la tabla. Con `GATHER_PLAN_STATISTICS` salen 4; si solo pido el `id_pedido`, que ya está en el índice, salen 3 (`02-anatomia-indice`).
- IX_PED_CLIENTE pierde contra la tabla al 1 % porque los pedidos de cada cliente están desperdigados (CF 999 041): el 1 % son 10 000 filas en casi 10 000 bloques distintos (9920 lecturas), y leer la tabla entera son 5232 (`04-agrupamiento-equilibrio`).
- Q3 no usaba el índice porque comparaba un texto con un número, y Oracle convertía la columna entera a número (`TO_NUMBER("CODIGO_POSTAL")`), lo que inutiliza el índice (`05-sargabilidad`).
- Cada índice cuesta unos 2 bloques más por cada alta: 10,1 bloques con 4 índices y 20,2 con 9 (`06-indices`).
- La cola leía 226 bloques para sacar un solo mensaje porque tenía que atravesar todas las hojas vacías de la izquierda (`07b-patron-cola`; en el enunciado eran 253: depende de cuánto haya limpiado Oracle por su cuenta).

### Parte I · Punto de control: Interpreta la salida

Respuesta (evidencia `08-scn-checkpoint`):

Después del checkpoint, todos los archivos abiertos quedan marcados con el mismo número, 6 335 581, menos los dos de PDB$SEED, que se quedan en 2 098 101. PDB$SEED es una plantilla de solo lectura: nadie escribe en ella, así que el checkpoint no tiene nada que guardar ahí. En ese momento Oracle tenía 419 679 bloques de redo pendientes y calculaba 39 segundos de recuperación: era el redo de cargar TiendaSur y de las pruebas de índices de las Partes B a H. Con una carga diez veces mayor habría mucho más redo pendiente y la recuperación tras una caída tardaría más; lo que pone un límite a eso es `FAST_START_MTTR_TARGET`, que aquí está a 0 (sin objetivo).

### Parte I · Reto: El MTTR bajo carga

Respuesta:

Antes de actualizar las 20 000 filas había 419 679 bloques de redo pendientes; después del COMMIT, 435 042, es decir, 15 363 bloques más (unos 7,5 MB). El tiempo estimado de recuperación se quedó en 39 segundos porque Oracle no lo recalcula al momento. La relación es directa: cuanto más redo se acumula desde el último checkpoint, más tiene que repasar Oracle al arrancar tras una caída, y más tarda.

### Parte K · Reto: Dimensiona el redo de TiendaSur

Respuesta:

En la hora de las 10h, cuando cargué TiendaSur e hice las Partes B a H, se archivaron 10 grupos de redo con 1521 MB en total. Para que esa carga provocara como mucho 4 cambios, cada grupo tendría que medir `1521 / 4 ≈ 380 MB`, así que propondría **400 MB**. Los comandos serían estos (no los ejecuté, como pide el reto):

```sql
ALTER DATABASE ADD LOGFILE GROUP 4 ('/opt/oracle/oradata/FREE/redo04.log', '/opt/oracle/oradata/FREE/redo04b.log') SIZE 400M;
ALTER DATABASE ADD LOGFILE GROUP 5 ('/opt/oracle/oradata/FREE/redo05.log', '/opt/oracle/oradata/FREE/redo05b.log') SIZE 400M;
ALTER DATABASE ADD LOGFILE GROUP 6 ('/opt/oracle/oradata/FREE/redo06.log', '/opt/oracle/oradata/FREE/redo06b.log') SIZE 400M;
-- repetir hasta que los grupos 1, 2 y 3 estén INACTIVE (y archivados)
ALTER SYSTEM SWITCH LOGFILE;
ALTER SYSTEM CHECKPOINT;
SELECT group#, status, archived FROM v$log;
ALTER DATABASE DROP LOGFILE GROUP 1;
ALTER DATABASE DROP LOGFILE GROUP 2;
ALTER DATABASE DROP LOGFILE GROUP 3;
-- y después borrar redo0{1,2,3}.log y redo0{1,2,3}b.log del disco
```

### Parte L · Punto de control: Interpreta la salida

Respuesta (evidencia `11-activar-archivelog`):

En mi caso los procesos que archivan (ARC0 a ARC3) ya estaban en marcha, porque la imagen de 26ai ya venía en modo ARCHIVELOG: el script dijo `Modo actual: ARCHIVELOG` y no tuvo que reiniciar. Lo que no tenía era zona de recuperación (FRA), y archivaba en `$ORACLE_HOME/dbs/arch` con nombres como `arch1_18_1237845575.dbf`. Al configurar la FRA, los archivados nuevos pasaron a guardarse en `/opt/oracle/oradata/fra/FREE/archivelog/2026_10_27/` con nombres que pone Oracle solo (`o1_mf_1_19_og0z2ds0_.arc`), como comprobé con `find`.

### Parte M · Punto de control: Interpreta la salida

Respuesta (evidencia `12-lectura-consistente`):

En el paso 1, la sesión A ya ha cambiado la fila en memoria a EGRESADO, pero la sesión B sigue viendo ACTIVO: Oracle le enseña cómo estaba la fila antes del cambio, reconstruyéndola con el undo de A (que en el paso 2 ocupa 1 bloque y 1 registro). En el paso 4, B no puede bloquear la fila porque A la tiene bloqueada para escribir (ORA-00054 y ORA-40097, que hasta dicen qué transacción la tiene: la 9.32.677). Para leer no hace falta bloquear; para escribir, sí. Y en el paso 6 se puede mirar cómo estaba la fila hace 40 segundos, aunque A ya confirmó, porque el undo sigue guardado: Oracle intenta conservarlo `UNDO_RETENTION = 900` segundos.

### Parte M · Reto: El coste de un DELETE en tu FRA

Respuesta:

La FRA pasó de 10 009 KB a 29 207 KB, es decir, creció 19 197 KB. Sumando todo el redo de las tres operaciones y sus ROLLBACK salen 18 560 KB (4865 + 358 + 1258 + 751 + 6627 + 4701). La diferencia, unos 640 KB, es lo que la base iba haciendo a la vez por su cuenta (procesos internos y las propias consultas de medida) más la cabecera de cada archivo archivado.

### Parte N · Punto de control: Interpreta la salida

Respuesta (evidencia `13-lgwr-dbwn`):

Justo después del COMMIT, ningún bloque de la tabla se había escrito en disco (0 escrituras de DBWn) y había **231 bloques modificados solo en memoria**. Lo que garantiza que el cambio no se pierda son los 1779 KB de redo que LGWR escribió en disco (en 2 escrituras) antes de decir "Commit complete". Con el checkpoint, DBWn escribió 346 bloques y en memoria ya no quedó ninguno pendiente. Son más de 231 porque el UPDATE también ensucia bloques de undo, y la cifra es de toda la base, no solo de esa tabla. El redo es grande para un UPDATE que no cambia ningún valor porque Oracle no mira si el valor es el mismo: apunta el cambio de las 20 000 filas igualmente (a mí me salieron 1,8 MB; en el enunciado 7,5 MB, porque allí se juntó con trabajo pendiente de partes anteriores).

### Parte O · Punto de control: Simulacro B

Respuesta (evidencia `14b-perdida-controlfile`):

La instancia llega a arrancar (lee su configuración, reserva memoria y lanza procesos), pero se para al **montar**, que es justo cuando tiene que abrir los control files. El alert log dice exactamente cuál falta: `ORA-00202: control file: '.../control03.ctl'` y `ORA-27037: unable to obtain file status`. Basta con copiar `control01.ctl` en su lugar porque las tres copias son idénticas y, con la base parada, ninguna está cambiando. Con la base abierta no se podría hacer, porque el control file se actualiza continuamente y la copia saldría a medias (y además, si una copia falla con la base abierta, la instancia se cae). Si se perdieran las tres, habría que restaurarlo con RMAN desde su copia automática (ahora hay una en la FRA desde el simulacro D) y abrir con RESETLOGS, o recrearlo con el script `CREATE CONTROLFILE` que guardé en la Parte J (`controlfile_lab5.trc`).

### Parte O · Punto de control: Simulacro D

Respuesta (evidencia `14d-perdida-datafile`):

Cada error dice una cosa: `ORA-01116` qué número de archivo no se puede abrir (el 16), `ORA-01110` cuál es (`academia01.dbf`) y `ORA-27041` con `No such file or directory` por qué: el archivo ya no está. A mí me tocó el **segundo camino**: cuando el script fue a reparar, Oracle ya había cerrado FREEPDB1 por su cuenta al detectar que faltaba el archivo (ORA-63999 en el alert log). La fila 104 salió EGRESADO aunque la copia se hizo antes del cambio, porque RMAN, después de restaurar el archivo, le aplicó todo el redo posterior a la copia. Tardé 8 s desde el fallo en volver a tenerlo funcionando, frente a los 61 s del simulacro C, y sin perder nada, frente a perder todo lo posterior a la copia en el C.

### Parte O · Reto: Escribe el runbook del simulacro D

Respuesta: está en `docs/runbooks/perdida-datafile.md`.

### Parte P · Punto de control: Clasifica cada error del bloque 5

Respuesta (evidencia `spool/..._15-healthcheck.spool.log`):

| Error | ¿Qué es? | De dónde viene |
|---|---|---|
| ORA-63999 data file suffered media failure | Efecto del laboratorio | Simulacro D: borré `academia01.dbf` |
| ORA-01110 data file 16 (academia01.dbf) | Efecto del laboratorio | Simulacro D |
| ORA-01113 file 25 needs media recovery (tiendasur01.dbf) | Efecto del laboratorio | Al volver a abrir FREEPDB1 tras el simulacro D, Oracle repasó sus archivos; la PDB terminó abierta sin problemas |
| ORA-00202 control03.ctl / ORA-205 al montar | Efecto del laboratorio | Simulacro B |
| ORA-00800 Set Priority Failed (LGWR, VKTM) | Ruido conocido | Ya lo vi en el Lab 4: el contenedor no deja cambiar la prioridad de esos procesos |
| ORA-16038, ORA-19809, ORA-19815 (no salen entre las 10 últimas filas) | Efecto del laboratorio | La FRA llena de la Parte L |

Ninguno es un problema real. Los 21 cambios de archivo de redo en una hora sí me preocuparían en una base de verdad: aquí los causaron la carga de TiendaSur y las pruebas, pero en producción querrían decir que el redo es pequeño para el trabajo que hay o que algún proceso está haciendo cambios masivos. Y si el bloque 7 saliera vacío en producción, es que no hay ninguna copia: ese mismo día haría una copia completa con RMAN, activaría la copia automática del control file y dejaría programada una copia diaria.

### Parte P · Reto: Un umbral que dispare una alerta

Respuesta:

Esta consulta devuelve una fila solo cuando hay que avisar a alguien: si la FRA pasa del 85 % o si no hay ninguna copia de RMAN terminada en las últimas 24 horas.

```sql
SELECT 'ALERTA: ' || LISTAGG(motivo, ' | ') WITHIN GROUP (ORDER BY motivo) AS alerta
  FROM (SELECT 'FRA al ' || ROUND(100 * space_used / space_limit, 1) || ' % (umbral 85 %)' AS motivo
          FROM v$recovery_file_dest WHERE space_limit > 0 AND space_used / space_limit > 0.85
        UNION ALL
        SELECT 'ninguna copia RMAN completada en 24 h' FROM dual
         WHERE NOT EXISTS (SELECT 1 FROM v$rman_backup_job_details WHERE status = 'COMPLETED' AND end_time > SYSDATE - 1))
HAVING COUNT(*) > 0;
```

Ahora mismo no devuelve nada, que es lo correcto. Para comprobar que funciona, bajé el umbral al 0,1 % y saltó: `ALERTA: FRA al 1,8 % (umbral de PRUEBA 0,1 %)`.

## Game day: RTO y RPO de los cuatro simulacros

| Simulacro | Qué se rompió | Cuánto tardé en volver (RTO) | Cuántos datos perdí (RPO) | Qué me sorprendió | Qué cambiaría |
|---|---|---|---|---|---|
| A | Caída brusca, como un corte de luz (SHUTDOWN ABORT) | Lo que tarda en arrancar: a los pocos segundos ya estaba abierta (< 10 s) | Nada | Solo tuvo que rehacer 10 KB de redo y 6 bloques, porque justo antes había habido un checkpoint | Fijar un objetivo de recuperación (`FAST_START_MTTR_TARGET`) para que no dependa de la suerte |
| B | Se borra una copia del control file | Un par de minutos, casi todo en parar y arrancar | Nada | Que el alert log diga exactamente qué archivo falta | Poner cada copia en un disco distinto; aquí las tres están en el mismo |
| C | Se borra una tabla sin papelera (`DROP ... PURGE`) | 61 s restaurando la copia completa de 1,4 GB | Todo lo hecho desde la copia (aquí 1 s porque la copia era de justo antes; en la vida real, horas) | Tener que restaurar la base entera por una sola tabla de 60 000 filas | Recuperar solo esa tabla con RMAN (`RECOVER TABLE`), ahora que la base archiva el redo |
| D | Desaparece el archivo `academia01.dbf` | 8 s desde el fallo | Nada | Que Oracle cerrara FREEPDB1 entera por su cuenta antes de que yo hiciera nada | Mirar siempre el estado de la PDB antes de reparar, como dice el runbook |

Lo que más me llevo: en el C el tiempo depende de lo grande que sea la base, y en el D solo de lo que se ha roto. Y gracias al redo archivado se pasa de perder "todo lo posterior a la última copia" a no perder nada.

## Retrospectiva sin culpables: la FRA llena

```
## Incidente: la base deja de archivar porque la FRA se llena (laboratorio, provocado a propósito en la Parte L)
- Impacto: dos grupos de redo se quedaron sin archivar. Si se hubiera seguido trabajando, las sesiones se
  habrían quedado esperando sin dar error ("log file switch (archiving needed)"). No se perdió ningún dato.
- Cómo se detectó: la sesión dio ORA-16038 y ORA-19809; antes, el alert log ya había avisado con ORA-19815
  al 91,41 % y al 100 %.
- Causa: el límite de la FRA se bajó a 2 MB, menos de lo que había que archivar. Además, antes de configurar
  la FRA la base archivaba en $ORACLE_HOME/dbs/arch sin límite y sin que nadie lo vigilara
  (18 archivados, 2247 MB).
- Cómo se arregló: devolviendo el límite a 4 GB; la base volvió a archivar sola. La verificación final
  comprueba que la configuración guardada sigue en 4 GB.
- Qué cambia: la consulta de alerta del reto de la Parte P avisa antes de llegar al 85 %, y antes de repetir
  cargas grandes hay que mirar cuánto ocupa la FRA. Queda pendiente borrar con RMAN los archivados viejos
  de dbs/arch.
- Qué aprendí: la primera vez no falló porque el archivado cupo por muy poco. El aviso llegó antes que el
  problema, pero sin un runbook que lo mire nadie se habría enterado.
```

## Preguntas de comprobación

### Punto de partida y banco de medida (A, B)

**1. Compara el paso 6 de tu copia lab4-final con el de la copia lab3-final. ¿Qué demuestra la diferencia?**

Respuesta:

En mi caso no hay diferencia: las dos dicen `ninguno: el volumen contiene toda la base de datos` (`lab4/evidencia/script/..._00-backup-lab3` y `lab5/evidencia/script/..._00-backup-lab4`). Mi imagen ya tenía `$ORACLE_HOME/dbs` dentro del volumen, así que el Lab 3 no me dejó ningún archivo fuera. Lo que sí demuestra es que la copia de lab4-final se basta sola: si mañana restauro el volumen, no me falta ningún archivo de la base.

**2. Calcula el factor de bloqueo (bfr) de CLIENTE y de PEDIDO con sus estadísticas. ¿Por qué PEDIDO cabe casi el triple de filas por bloque?**

Respuesta:

Con los datos de `01-perfil-tiendasur`: en CLIENTE caben `100 000 / 1517 = 66` filas por bloque y en PEDIDO `1 000 000 / 5320 = 188`. En PEDIDO caben casi el triple porque cada pedido ocupa 32 bytes de media y cada cliente 102 (lleva DNI, email, nombre, apellidos, teléfono y ciudad). Cuántas filas caben en un bloque depende de lo que mide cada fila.

**3. ¿Por qué el banco de medida ejecuta cada sentencia dos veces y mide solo la segunda?**

Respuesta:

Porque la primera vez Oracle hace trabajo que luego ya no repite: analizar la consulta, traer los bloques del disco a la memoria o terminar de limpiar bloques que quedaron pendientes de la carga. En la Parte C se nota: la primera búsqueda por clave primaria puede leer 5 bloques y la segunda 4. Midiendo siempre la segunda, comparo en igualdad de condiciones y los números salen iguales cada vez.

### Anatomía y tipos de índice (C, D)

**4. Con tu evidencia 02: altura, número de hojas y factor de ramificación (fan-out) real de IX_PED_CLIENTE. ¿Qué altura tendría con mil millones de filas?**

Respuesta:

Tiene 3 niveles, 2216 hojas y 6 bloques de rama. Cada bloque de rama apunta de media a `(2216 + 6 − 1) / 6 = 370` hijos (como mucho podría apuntar a 543). Con mil millones de filas necesitaría unas 2 208 969 hojas y tendría **4 niveles**: encontrar una fila costaría 5 lecturas en vez de 4 (`02-anatomia-indice`, sección 2). Que con mil veces más datos solo haga falta un nivel más es lo que hace tan útiles a los índices.

**5. En el volcado de la hoja de PK_CLIENTE, localiza una entrada y descompón el ROWID que guarda en bloque y fila. ¿Por qué no aparece el número de archivo?**

Respuesta:

La primera entrada de la hoja es `row#0[1200] ... data:(6): 00 00 03 1b 00 00` con la clave `c1 02`. La clave `c1 02` es el número 1 (el cliente 1), y los 6 bytes son su dirección: los 4 primeros dicen el bloque (0x31B, el 795) y los 2 últimos la posición dentro del bloque (la 0). El propio script lo confirma: el cliente 1 está en el bloque 795, posición 0. No aparece el número de archivo porque el tablespace de TiendaSur es de tipo BIGFILE, con un único archivo, así que no hace falta guardarlo; por eso la dirección ocupa 6 bytes en vez de 10.

**6. Elige tres pruebas de la Parte D y explica, con las lecturas lógicas medidas, por qué un tipo de índice gana al otro.**

Respuesta (evidencia `03-tipos-indice`):

- **Historial del cliente (Q7):** con el índice que solo tiene el cliente lee 15 bloques y además tiene que ordenar los resultados. Con un índice de cliente y fecha baja a 7, porque los pedidos ya salen ordenados. Y si el índice incluye también las columnas que se piden (cubriente), baja a 3, porque ni siquiera tiene que ir a la tabla.
- **Informe con varios filtros (Q14):** sin índices bitmap lee la tabla entera, 4073 lecturas; con un bitmap por columna, Oracle los combina y se queda en 528. Además, el bitmap de región ocupa 114 hojas, frente a las 1954 de un índice normal.
- **Validar una sesión (Q15):** con tabla e índice normal son 4 lecturas, con la tabla organizada como índice (IOT) 3, y con el clúster hash 1, porque la propia clave dice en qué bloque está la fila. Pero el hash no sirve para buscar por rangos: limpiar las sesiones caducadas tuvo que leer 2770 bloques.

### Agrupamiento, equilibrio y sargabilidad (E, F)

**7. ¿Por qué IX_PED_FECHA tiene un clustering factor cercano al número de bloques e IX_PED_CLIENTE cercano al de filas? ¿Lo arreglaría un REBUILD?**

Respuesta:

Los pedidos se cargaron en orden de fecha, así que recorrer el índice de fecha es como recorrer la tabla bloque a bloque: el CF sale 5220, que es casi el número de bloques. Los clientes, en cambio, se repartieron al azar, así que cada pedido de un cliente está en un bloque distinto: el CF sale 999 041, casi uno por fila. El cálculo a mano da exactamente lo mismo (`04-agrupamiento-equilibrio`, sección 2). Reconstruir el índice no lo arreglaría, porque el problema no está en el índice sino en cómo están colocadas las filas en la tabla. Solo cambiaría reordenando la tabla por cliente, y entonces sería la fecha la que quedaría desordenada.

**8. Según tu curva de la Parte E, ¿a partir de qué porcentaje deja de compensar cada índice? Compáralo con la fórmula de la Unidad 3.**

Respuesta:

El índice malo (por cliente) ya lee más que la tabla entera al 1 % (9920 lecturas frente a 5232), y el cruce exacto está hacia el 0,54 %, que es lo que dice la fórmula: `1 / 188 = 0,53 %`. El índice bueno (por fecha) aguanta mucho más: al 50 % todavía lee 3938, y solo pierde al 100 % (7875), porque lee los bloques seguidos. El optimizador abandona el índice bastante antes, entre el 0,1 % y el 0,2 %, porque piensa en el disco, donde saltar de un sitio a otro sale caro; con la fórmula de disco sale 0,11 %.

**9. Explica por qué Q4b ('Gonz%') usa el índice y aun así lee más bloques que un recorrido completo.**

Respuesta (evidencia `05-sargabilidad`):

Q4b usa el índice porque "empieza por Gonz" es un rango que se puede buscar en un índice ordenado por apellidos. Pero lee **2024** bloques, más que los 1486 de leer la tabla entera. El motivo es que "Gonz…" es el 2 % de los clientes (2056 filas), y como los apellidos no están ordenados en la tabla (CF de 84 964 para 1517 bloques), cada fila está en un bloque distinto. Con filas tan desperdigadas, el índice solo compensa por debajo del 1,5 % (1/66 en CLIENTE). Que una consulta pueda usar el índice no quiere decir que le convenga: aquí lo correcto sería leer la tabla entera.

### Coste de escritura y mantenimiento (G, H)

**10. Con tu evidencia 06: bloques modificados por INSERT con 4, 9 y 5 índices. ¿Qué índices de la propuesta del compañero rechazaste y con qué dato?**

Respuesta:

Cada alta de pedido modifica 10,1 bloques con los 4 índices de hoy, 20,2 con los 9 de la propuesta del compañero y 12,1 con los 5 de V005 (`06-indices`). Rechacé:
- **El de canal**, porque ninguna consulta habitual lo usó y cada canal es de media un tercio de la tabla: buscar por él no ahorra nada.
- **El de estado**, porque cada estado es de media un 25 % de los pedidos; para los pendientes es mucho mejor el índice parcial, que solo guarda el 2 % de las filas (54 hojas).
- **El de fecha y cliente**, porque nadie lo usó y además repite al de fecha, que es el que usan Q2, Q8 y Q9.
- **El de cliente y fecha**, porque ya lo cubre el índice cubriente, que empieza igual y además evita ir a la tabla.

Del compañero solo aproveché la idea del índice por código postal, que sí usa Q3 una vez bien escrita (cada código postal es un 0,009 % de los pedidos; 106 lecturas).

**11. Distingue, con tus gráficos de la Parte H, un índice con divisiones 50/50, uno con divisiones 90/10 y uno con patrón cola.**

Respuesta (evidencias `07a-grafico-*` y `07b-grafico-IX_COLA-antes`):

- **Claves al azar (IX_AZAR):** las hojas se partieron 595 veces por la mitad. Quedan llenas de media al 75 %, repartidas entre el 40 y el 99 %, y el mapa mezcla `=` y `-` por todo el ancho.
- **Claves en orden (IX_CRECIENTE):** 398 divisiones, todas dejando la hoja vieja llena. Casi todas las hojas están entre el 90 y el 99 % y el mapa es todo `#`.
- **Cola (IX_COLA):** de 425 hojas, 224 están vacías. El mapa `[                                =###############################]` está vacío a la izquierda y lleno a la derecha, con 70 497 entradas borradas que siguen ocupando sitio.

**12. ¿Qué remedio elegirías para el patrón cola en producción, en horario de servicio, y por qué?**

Respuesta:

`ALTER INDEX ... COALESCE`. Se hace sin parar el servicio ni bloquear la tabla, y arregló el problema por completo: las hojas bajaron de 425 a 201 y sacar el siguiente mensaje pasó de 226 lecturas a 2 (`07c-remedios`). Si además quisiera devolver el espacio sobrante usaría SHRINK SPACE (de 4 a 1,69 MB). Reconstruir el índice no aporta nada más aquí y gasta el doble de espacio y mucho redo. A largo plazo, lo suyo sería partir la tabla por fechas y vaciar trozos enteros en lugar de borrar fila a fila.

### SCN, control files, redo y FRA (I a L)

**13. Con tu evidencia 08: ¿qué valores compara Oracle al abrir para decidir si hace falta recuperación?**

Respuesta:

Compara dos números para cada archivo: el que tiene apuntado en el control file (hasta dónde cree que está guardado ese archivo) y el que está escrito en la cabecera del propio archivo. En mi evidencia, después del checkpoint, los dos valen 6 335 581 en system01, sysaux01 y academia01: coinciden, así que no haría falta recuperar nada. Si no coincidieran, o si la base no se hubiera cerrado bien, Oracle aplicaría el redo desde ese punto.

**14. ¿Qué protege la multiplexación del control file en el mismo volumen y qué no? ¿Cómo se haría en producción?**

Respuesta:

Protege de perder o estropear uno de los archivos: en el simulacro B borré `control03.ctl` y lo arreglé copiando `control01.ctl`, sin perder nada. Lo que no protege es perder el disco entero, porque las tres copias están en la misma carpeta (`/opt/oracle/oradata/FREE`) y se irían juntas; tampoco un error que Oracle escriba igual en las tres. En producción pondría cada copia en un disco distinto (y si se puede, en una controladora distinta) y activaría la copia automática del control file en RMAN.

**15. Explica los estados CURRENT, ACTIVE e INACTIVE con tu evidencia 10 y por qué Oracle rechaza los tres borrados del paso 4.**

Respuesta:

- **CURRENT** es el grupo de redo en el que se está escribiendo ahora (tras el segundo cambio, el grupo 3, secuencia 18).
- **ACTIVE** es uno que ya no se usa pero cuyos cambios todavía no están todos guardados en los datafiles, así que haría falta si la base se cayera (el 1 y el 2 después de los cambios).
- **INACTIVE** es uno cuyos cambios ya están guardados y, como la base archiva, también copiados (al principio, los grupos 2 y 3, secuencias 14 y 15).

Oracle no deja borrar el grupo CURRENT (ORA-01623) ni una copia suya (ORA-01609), porque es donde está escribiendo. El tercer intento a mí me dio ORA-01624, no el ORA-01567 del enunciado: mi base tiene 3 grupos de 200 MB en vez de 2 de 20 MB, así que borrar uno no dejaba menos de dos; pero el grupo elegido estaba ACTIVE y Oracle lo protege porque podría necesitarlo para recuperarse. Por la misma razón, después de dos cambios `redo01b.log` todavía aparecía INVALID: el grupo 1 aún no había vuelto a usarse.

**16. Describe la cadena de causas del escenario de la FRA llena, desde ORA-19815 hasta que la base deja de aceptar cambios.**

Respuesta:

1. La FRA se acerca a su límite y Oracle avisa en el alert log con ORA-19815 (en mi evidencia, al 91,41 % y al 100 %).
2. Cuando toca guardar la copia del siguiente grupo de redo, no hay sitio: ORA-19809 y ORA-16038, y ese grupo se queda sin archivar.
3. Mientras la base archiva, un grupo no se puede volver a usar hasta que esté copiado. Así que, cuando Oracle da la vuelta y necesita ese grupo, se queda esperando.
4. Desde ese momento, cualquier sesión que intente cambiar algo se queda colgada sin dar error, y las conexiones nuevas reciben ORA-00257.

En mi prueba lo corté antes de llegar ahí, devolviendo los 4 GB. En la evidencia 11 hay dos ejecuciones: en la primera no saltó nada porque la FRA estaba vacía y lo archivado cupo en los 2 MB; al repetirla, con 1,8 MB ya ocupados, salió toda la cadena.

### Undo, WAL y simulacros (M a P)

**17. Explica, con los pasos 1 a 4 de tu evidencia 12, la frase "lectores no bloquean a escritores".**

Respuesta:

La sesión A cambió la fila 101 y no confirmó, así que tiene la tabla y la fila bloqueadas para escribir (paso 3). Aun así, la sesión B pudo leer esa fila sin esperar y vio el valor de antes, ACTIVO (paso 1), que Oracle le reconstruye con el undo de A (paso 2). Leer no necesita bloquear nada. Solo cuando B quiso modificar la misma fila (`FOR UPDATE WAIT 3`) chocó con A y recibió ORA-00054 (paso 4). Es decir: quien lee no frena a nadie ni se queda esperando; solo se estorban dos que quieren escribir en la misma fila.

**18. ¿Por qué un DELETE genera más undo que un INSERT? ¿Por qué el ROLLBACK también genera redo?**

Respuesta (evidencia `12-undo-y-redo`):

Para deshacer un INSERT basta con apuntar "borra esta fila" (140 bloques de undo para 10 000 filas). Para deshacer un DELETE hay que guardar la fila entera, con todos sus datos y sus entradas en los índices, para poder volver a ponerla (428 bloques, el triple). Y el ROLLBACK también genera redo porque deshacer es volver a modificar los bloques, y cualquier modificación se apunta en el redo: deshacer el DELETE generó 4701 KB.

**19. Con tu evidencia 13: ¿dónde está la garantía de durabilidad justo después del COMMIT? ¿Y después del checkpoint?**

Respuesta:

Justo después del COMMIT, la garantía está solo en el redo: LGWR había escrito 1779 KB en disco, pero ningún bloque de la tabla estaba guardado todavía (0 escrituras de DBWn y 231 bloques cambiados solo en memoria). Si se hubiera ido la luz en ese momento, el redo habría servido para rehacer el cambio. Después del checkpoint, el cambio ya está también en los propios archivos de datos: DBWn escribió 346 bloques y no quedó ninguno pendiente. A partir de ahí, ese redo ya no hace falta para recuperarse de una caída (solo para recuperar un archivo perdido, y para eso queda archivado).

**20. Simulacro A: explica roll forward y roll back con las filas 102 y 103 y las líneas del alert log.**

Respuesta (evidencia `14a-caida-instancia`):

Al volver a arrancar, Oracle empezó a recuperarse solo (`Beginning crash recovery of 1 threads`) desde el último punto guardado (`logseq 27 block 4022, scn 6339731`). Primero **rehízo**: leyó 10 KB de redo y volvió a aplicar los cambios de 6 bloques que no habían llegado al disco, incluidos los de las dos filas y el undo de la transacción que no se confirmó. Después **deshizo**: con ese undo, quitó lo que no estaba confirmado. Resultado: la fila 102 se quedó en EGRESADO porque se había hecho COMMIT, y la 103 volvió a ACTIVO porque no. La base abrió sola, en la secuencia 28, sin que yo hiciera nada.

**21. Simulacros C y D: tu RTO y tu RPO en cada uno. ¿Por qué son tan distintos?**

Respuesta:

En el C tardé 61 s y perdí todo lo hecho desde la copia (aquí solo 1 s, porque la copia se hizo justo antes). En el D tardé 8 s y no perdí nada. La diferencia es qué se restaura: en el C tuve que volver a poner la base entera (1,4 GB) para recuperar una sola tabla, así que el tiempo depende del tamaño de la base y se pierde lo posterior a la copia. En el D solo restauré el archivo roto y después Oracle le aplicó todo el redo guardado, así que el tiempo depende solo de lo que se rompió y no se pierde nada.

**22. Clasifica cada error ORA- del bloque 5 de tu runbook: incidente real, efecto del laboratorio o ruido conocido.**

Respuesta: está en la tabla del punto de control de la Parte P. Todos los ORA- del bloque 5 los provocaron mis propias pruebas (simulacros B y D y la FRA llena), salvo ORA-00800, que es ruido conocido del contenedor desde el Lab 4. Ninguno es un problema real.

## Preguntas tipo examen de cada Parte

**B1.** Letra: **B**. Si Oracle esperaba 25 000 filas y salieron 20, es que no sabía que esa columna está muy desequilibrada: le falta el histograma. Sin él supone que todos los valores salen lo mismo (V004 lo evita poniendo histograma en el estado, Parte B).

**C1.** Letra: **C**. BLEVEL 2 son 3 niveles de índice; más el bloque de la tabla, 4 lecturas, como medí en la Parte C.

**C2.** Letra: **C**. Con 500 hijos por bloque, dos niveles de rama solo llegan a 250 000 hojas; para 2 000 000 hacen falta tres niveles de rama más las hojas: 4 niveles.

**D1.** Letra: **B**. Pocos valores distintos, carga de noche y filtros combinados: un bitmap por columna, que Oracle combina (en la Parte D bajó de 4073 a 528 lecturas).

**D2.** Letras: **A y C**. El cubriente evita ir a la tabla (Q7 en 3 lecturas), pero cada cambio en sus columnas cuesta más (con V005, cambiar el estado pasó a 8,1 bloques).

**E1.** Letra: **B**. Con las filas tan desordenadas, el índice solo compensa por debajo del 0,8 % (1/125), y el 3 % está muy por encima: mejor leer la tabla entera. Reconstruir el índice no lo arregla (Parte E).

**F1.** Letra: **B**. Comparar un texto con un número hace que Oracle convierta la columna a número y ya no pueda usar el índice (Q3, Parte F).

**F2.** Letras: **A y C**. Las dos dejan la columna tal cual y abarcan el día entero; la B solo encuentra la medianoche, y la D y la E siguen tocando la columna.

**G1.** Letra: **B**. Hacerlo invisible: Oracle deja de usarlo pero lo sigue manteniendo, y se vuelve atrás al momento con VISIBLE (Parte G).

**G2.** Letra: **B**. Cada índice suma unos 2 bloques por alta: 500 × 2 = 1000 bloques más por segundo.

**H1.** Letra: **B**. COALESCE arregla la cola sin parar el servicio y gastando poco (de 226 a 2 lecturas, Parte H).

**H2.** Letras: **A y C**. Reparte las inserciones para que no se peleen por la misma hoja, pero ya no sirve para buscar por rangos (866 lecturas frente a 4, Parte H).

**I1.** Letra: **B**. Compara el número que tiene el control file con el de la cabecera de cada archivo (Parte I).

**J1.** Letra: **B**. Si falla una copia del control file con la base abierta, la instancia se para; hay que reponerla (o quitarla de la lista) y arrancar.

**J2.** Letras: **A y C**. Guarda dónde están los datafiles y el redo, y hasta dónde está guardado cada uno; lo vi en el `CREATE CONTROLFILE` de la Parte J.

**K1.** Letra: **C**. Un grupo ACTIVE tiene cambios que aún podrían hacer falta si la base se cae (por eso me dio ORA-01624 en la Parte K).

**L1.** Letra: **B**. Primero hay que decirle el tamaño y luego la ruta (me dio ORA-19802 al hacerlo al revés, Parte L).

**L2.** Letras: **A y C**. Darle más espacio si hay disco, o copiar los archivados con RMAN y borrarlos; nunca borrarlos a mano con rm (yo lo arreglé subiendo a 4 GB).

**M1.** Letra: **C**. Ve el valor de antes, reconstruido con el undo (paso 1 de la Parte M).

**M2.** Letra: **C**. El DELETE: 428 bloques de undo, frente a 140 del INSERT y 71 del UPDATE (Parte M).

**M3.** Letras: **B y D**. Guardar el undo más tiempo y con más espacio, y garantizarlo si el informe es crítico.

**N1.** Letra: **A**. Que el redo está escrito en disco; los datos todavía no (0 bloques escritos tras el COMMIT, Parte N).

**N2.** Letras: **B y C**. En un checkpoint y cuando se queda sin memoria libre; nunca por un COMMIT.

**O1.** Letra: **B**. Oracle rehace y deshace solo y la base abre sin ayuda (simulacro A).

**O2.** Letras: **B y D**. Copiar una de las copias buenas en su sitio, o quitarla de la lista de control files (simulacro B).

**O3.** Letra: **B**. Poner el archivo fuera de servicio, restaurarlo, aplicarle el redo y volver a ponerlo en servicio, todo con la base abierta (simulacro D y runbook).

**O4.** Letra: **D**. Con RMAN se puede recuperar solo esa tabla tal como estaba antes del borrado, sin tocar lo demás; la papelera no sirve porque se borró con PURGE.

## Simulacro de examen 1Z0-182 (S1-S26)

| Pregunta | Letra | Por qué | Dónde lo comprobé |
|---|---|---|---|
| S1 | B | Si el CF es casi igual a las filas, casi cada fila está en un bloque distinto | Parte E (IX_PED_CLIENTE, CF 999 041) |
| S2 | A y C | Un índice sobre la función, o aplicar la función al dato que llega y no a la columna | Parte D (Q1 con índice funcional) y Parte F (Q1 reescrita) |
| S3 | B | Oracle convierte la columna a número y el índice deja de servir | Parte F, regla 3 |
| S4 | B | Bitmap: pocos valores distintos y carga de noche | Parte D, Q14 |
| S5 | B | Puede "saltar" por cada país (SKIP SCAN) | Parte D, Q6 solo por ciudad |
| S6 | B | Hacerlo invisible y observar | Parte G, pregunta 5 |
| S7 | A y C | COALESCE y SHRINK SPACE, los dos sin parar el servicio | Parte H (`07c-remedios`) |
| S8 | B | Reparte las inserciones, pero ya no sirve para rangos | Parte H (866 frente a 4 lecturas) |
| S9 | C | Cambiar una columna que no está en ningún índice solo toca la tabla | Parte G (cambiar el estado: 2 bloques) |
| S10 | B | Cuántos hijos caben por bloque depende de lo que mide la clave | Parte C (reto UX_CLI_EMAIL: 441 frente a 543) |
| S11 | A y C | La IOT guarda las filas dentro del propio índice y se ahorra ir a la tabla | Parte D, Q15 (3 lecturas frente a 4) |
| S12 | B | El número del control file frente al de la cabecera del archivo | Parte I |
| S13 | C | CKPT es quien apunta el checkpoint | Partes I y N |
| S14 | B y E | En NOMOUNT solo contestan las vistas de la instancia y de los parámetros | Parte O, simulacro B (estado STARTED) |
| S15 | B | Parar, montar, activar ARCHIVELOG y abrir | Parte L |
| S16 | B | CLEAR LOGFILE GROUP vuelve a crear el grupo | Parte K |
| S17 | A y C | Para que otros lean el valor de antes y para mirar al pasado (flashback) | Parte M, pasos 1 y 6 |
| S18 | B | El undo también puede perderse en una caída, así que hay que poder rehacerlo | Parte M |
| S19 | A | El redo está escrito en disco | Parte N |
| S20 | A | Más checkpoints pequeños y recuperación más rápida | Parte I |
| S21 | B | No se puede archivar porque la FRA está llena | Parte L |
| S22 | B | Lo primero, poner ese archivo fuera de servicio | Parte O, simulacro D y runbook |
| S23 | B | Si es SYSTEM, hay que hacerlo con la base montada | Parte O |
| S24 | B | Sin ARCHIVELOG solo queda la última copia en frío y se pierde lo posterior | Parte O, simulacro C |
| S25 | B y D | Más undo y garantizar que se conserve | Parte M |
| S26 | A | V$RECOVERY_AREA_USAGE | Parte L |
