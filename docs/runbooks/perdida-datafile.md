# Runbook: pérdida de un datafile de negocio (oralab-26ai)

Para quien esté de guardia y no haya hecho el simulacro D del Lab 5. Tiempo esperado: menos de 5 minutos.

## 1. Cómo se reconoce

Una consulta falla con estos tres errores juntos (y el alert log dice lo mismo):

- `ORA-01116: error in opening database file N` → qué número de archivo falla.
- `ORA-01110: data file N: '/opt/oracle/oradata/FREE/FREEPDB1/xxx01.dbf'` → la ruta exacta.
- `ORA-27041: unable to open file` + `Linux-x86_64 Error: 2: No such file or directory` → la causa en el sistema operativo: el archivo no está.

Puede aparecer también `ORA-63999: data file suffered media failure`. Significa que Oracle ha cerrado **la PDB entera** para protegerla (la CDB y las demás PDB siguen abiertas).

## 2. Comprobaciones antes de tocar nada

```sql
-- como SYSDBA en CDB$ROOT: bash scripts/ops/sysdba.sh ... o docker exec -it oralab-26ai sqlplus / as sysdba
SELECT log_mode FROM v$database;                       -- tiene que ser ARCHIVELOG
SELECT name, open_mode FROM v$pdbs;                     -- ¿FREEPDB1 sigue READ WRITE o está MOUNTED?
SELECT file#, name FROM v$datafile WHERE file# = N;     -- confirmar archivo y número
```
```text
RMAN> LIST BACKUP OF DATAFILE N;                        -- tiene que existir al menos una copia
```

- Si **no** está en ARCHIVELOG o **no** hay copia de RMAN: este runbook no sirve. Para aquí y avisa (sección 5): toca restaurar la última copia en frío (`scripts/ops/restaurar-estado.sh`) y se pierde lo posterior.
- Si el archivo es de `SYSTEM` o del undo de la raíz: tampoco es este runbook (hay que montar la CDB y recuperar con la base cerrada).

## 3. Reparación

**Camino A: FREEPDB1 sigue en READ WRITE** (solo el tablespace afectado está caído):

```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE N OFFLINE;
```
```text
RMAN> RESTORE DATAFILE N;
RMAN> RECOVER DATAFILE N;
```
```sql
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER DATABASE DATAFILE N ONLINE;
```

**Camino B: FREEPDB1 está MOUNTED (ORA-63999)**:

1. Espera a que `v$pdbs` diga `MOUNTED` del todo. Si lanzas RMAN mientras se está cerrando, falla (`ORA-01089`).
2. `RMAN> RESTORE DATAFILE N;` y `RMAN> RECOVER DATAFILE N;`
3. `ALTER SESSION SET CONTAINER = FREEPDB1; ALTER DATABASE DATAFILE N ONLINE;`
4. `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;`

Si al poner el archivo ONLINE sale `ORA-01113: file N needs media recovery`, te has saltado el `RECOVER`: hazlo y repite el ONLINE.

## 4. Cómo saber que ha funcionado

- `SELECT name, open_mode FROM v$pdbs;` → FREEPDB1 en `READ WRITE`. Hasta que no lo diga, el incidente no está cerrado.
- `SELECT file#, status FROM v$datafile WHERE file# = N;` → `ONLINE`.
- Una consulta de control sobre una tabla de ese tablespace (en academia: `SELECT COUNT(*) FROM admin_academia.aca_estudiantes;` → 20000).
- `bash scripts/ops/ro.sh scripts/lab5/15-healthcheck.sql` → los ORA-01113/ORA-01110/ORA-63999 del bloque 5 son la huella del incidente, no un problema nuevo.

## 5. A quién avisar

- Al empezar: al responsable de la base (en el laboratorio, el profesor o quien revise el Issue) con el número de archivo y el camino (A o B).
- Al terminar: comentario en el Issue con hora del fallo, hora de vuelta (RTO), RPO (0 si RECOVER terminó bien) y la causa de que el archivo desapareciera. Si nadie sabe por qué ha desaparecido, abre otro Issue: el runbook arregla el síntoma, no la causa.
