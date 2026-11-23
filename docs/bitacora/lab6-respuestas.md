# Lab 6 · Respuestas

Las evidencias están en `docs/bitacora/lab6/evidencia/`. Cuando digo "evidencia 05" me refiero a los archivos que empiezan por 05 en `script/` o `spool/`. Los postmortems de la guardia están en `lab6-guardia.md`.

## Línea base y ruido conocido

El día que empecé (22 de noviembre) la lista de turno daba 4 errores ORA- en 24 h (evidencia 01, turno). Los 4 son ORA-00800 "Set Priority Failed" de VKTM y LGWR, dos por cada arranque de ese día (el docker start y el arranque después de la copia lab6-inicio). No salen errores de los simulacros del Lab 5 porque fueron el 27 de octubre.

Errores que ya sé que son normales en mi entorno:
- ORA-00800 Set Priority Failed: sale en cada arranque porque el contenedor no deja subir la prioridad de esos procesos. En el ADR es el único problema que hay (ORA 800, 50 incidentes).
- ORA-65019: me salió en validar-arranque, pero lo provoqué yo en el paso 2 de 02-estados-pdb al reabrir la PDB sin cerrarla.
- Los de DBMS_QOPATCH que salen en el enunciado a mí no me salen.

Una cosa que me llamó la atención: la sección 4 de validar-arranque dice "desde el último arranque" pero me sacó también errores de arranques anteriores. Creo que es por la zona horaria, porque SQLcl usa la hora de mi Ubuntu (UTC+1) y la ventana empieza una hora antes.

## Partes A-C

1. Tenía 4 errores ORA- en 24 h, todos ORA-00800 de los dos arranques de ese día. No es una alarma por sí solo porque cada arranque mete dos de esos. Habría que preocuparse si sube sin reinicios o si aparece un error distinto.

2. La ventana del miércoles (WEDNESDAY_WINDOW) empieza a las 22:00 y dura 4 horas (evidencia 01, spool de automatizacion). En ella corren las tres tareas de AutoTask: estadísticas del optimizador, Segment Advisor y SQL Tuning Advisor.

3. Después del SCOPE = SPFILE, V$SPPARAMETER decía db_files = 250 y V$PARAMETER seguía en 200 (evidencia 02, parametros). El archivo tenía el valor nuevo pero la instancia seguía con el viejo, porque db_files es estático (por eso antes dio ORA-02095 con SCOPE = MEMORY). Sin el RESET, en el siguiente reinicio habría arrancado con 250.

4. RESET quita la línea del SPFILE y deja el valor por defecto, no el anterior. Con db_files servía porque no estaba fijado: en mi copia init_desde_spfile.ora no aparece. Con processes no, porque sí estaba fijado (línea 31 de esa copia: `*.processes=200`). Un RESET de processes lo habría cambiado al valor por defecto en el próximo arranque.

5. C##OPS_RO recibió ORA-01109: database not open (evidencia 02, estados-pdb, paso 4). La instancia decía "Database opened" porque eso es el CDB, pero FREEPDB1 se quedó en MOUNTED al no tener estado guardado. El listener conocía el servicio freepdb1 pero la PDB estaba cerrada.

## Partes D-E

6. La sesión de la aplicación tenía SID 227, SPID 4096 y el evento PL/SQL lock timer, porque estaba en el SLEEP (evidencia 03, sesiones). USERNAME solo dice APP_ACADEMIA, que es la misma cuenta para toda la aplicación. Con MODULE (matriculas), ACTION (cierre-periodo) y CLIENT_IDENTIFIER (ana.garcia@ucam) sé qué estaba haciendo y para quién.

7. Después de CANCEL SQL la aplicación tenía 1 transacción abierta y seguía conectada ("sigo viva"). Después de KILL SESSION ya no quedaba ninguna sesión. La fila 101 quedó en ACTIVO porque el UPDATE no estaba confirmado y al matar la sesión se deshizo.

8. En mi imagen common_user_prefix vale C## (evidencia 03, cuenta-app), no vacío como en el enunciado. Una cuenta común tiene que empezar por C##, como C##OPS_RO. APP_ACADEMIA no lo lleva porque es local.

9. Mis cifras (evidencia 04, tres-miradas):

| Vista | OPS_RO en raíz | OPS_RO en FREEPDB1 | APP_ACADEMIA |
|---|---|---|---|
| ALL_TABLES de ADMIN_ACADEMIA | 0 | 0 | 1 |
| DBA_USERS | 37 | 47 | ORA-00942 |
| CDB_USERS | 37 y 47 | 47 | ORA-00942 |
| V$DATAFILE | 17 | 10 | ORA-00942 |

V$DATAFILE da 17 desde la raíz y 10 desde la PDB aunque es el mismo usuario, porque las V$ también se filtran por contenedor. La aplicación da ORA-00942 en todo lo de catálogo porque no tiene ningún privilegio para verlo.

10. La carga costó 5388 lecturas lógicas por recorrido y 0,46 s de DB time (evidencia 04, deltas). DB CPU también fue 0,46, así que no hubo esperas: todo fue CPU porque los bloques ya estaban en caché.

## Partes F-G

11. TBS_ACADEMIA_HIST recién creado: 10 MB asignados, 3,9 MB libres y 40 MB de máximo (evidencia 05, almacenamiento). Para alertar usaría el porcentaje sobre el máximo (15,16 %), porque el libre puede estar casi a cero y aun así el tablespace puede crecer hasta 40 MB.

12. Insertó SYS, pero el segmento iba a ser de CARGA_HIST y era ella la que no tenía cuota. La cuota la paga el dueño. En el ORA-01536 ampliar el tablespace no servía porque había sitio; lo que estaba lleno era la cuota de 2 MB.

13. Estuvo suspendida unos 14 segundos, de 23:44:07 a 23:44:21 (evidencia 05, resumable). En el alert log quedó una línea de "was suspended" y otra de "was resumed" para la sesión carga-historico.

14. Antes del DELETE: 20000 filas, 2944 bloques, 23 MB. Después del DELETE: 2000 filas pero los mismos 2944 bloques y 23 MB. Después del SHRINK: 2000 filas, 304 bloques y 2,4 MB, y la cuota usada bajó a 2,4 MB (evidencia 05, hwm-shrink). El DELETE no devuelve espacio porque los bloques siguen por debajo de la HWM; el SHRINK mueve las filas y baja la HWM.

15. El perfil DEFAULT tenía FAILED_LOGIN_ATTEMPTS 10, PASSWORD_LIFE_TIME 180, PASSWORD_LOCK_TIME 1, PASSWORD_GRACE_TIME 7, INACTIVE_ACCOUNT_TIME 365 y sin función de verificación (evidencia 06, gobierno-acceso). En PRF_PERSONAS:
- 3 intentos fallidos: una persona no se equivoca tantas veces seguidas, y si pasa puede ser alguien probando contraseñas. Lo vi con Ana, que se quedó en LOCKED(TIMED).
- INACTIVE_ACCOUNT_TIME 90: si alguien de secretaría no entra en tres meses, seguramente ya no está, y la cuenta se bloquea sola aunque nadie tramite la baja.

16. Ana leyó 60000 matrículas porque su rol incluye ROL_LECTURA_ACADEMIA, que tiene SELECT ANY TABLE ON SCHEMA admin_academia, y eso vale para todas las tablas del esquema (evidencia 06, probar-acceso). Al cambiar el nombre le salió ORA-41900, falta el privilegio UPDATE, porque solo puede cambiar la columna ESTADO.

## Partes H-I

17. Con la columna nueva no se invalidó nada porque nadie la usaba (Oracle mira las dependencias por columna). Al ampliar email_institucional solo se invalidó V_CONTACTO_LAB6. Al ampliar nombres se invalidó V_ACTIVOS_LAB6 y también la función F_TOTAL_ACTIVOS_LAB6, porque depende de esa vista (evidencia 07, objetos).

18. Duplicar la SGA no mejoraría nada: con 3072 MB el ESTD_DB_TIME_FACTOR sigue en 1. La PGA tendría sobreasignaciones por debajo de 384 MB (con 256 y 128 MB salen 2) (evidencia 07, memoria).

19. 247 lecturas lógicas. Lo dice la línea FETCH de la traza con `cr=247`, y en tkprof sale 247 en la columna query (evidencia 07, adr-trazas).

20. Guardia (evidencia 08):
- INC-601: Ana (SID 177) esperaba en enq: TX bloqueada por la SID 176 de APP_ACADEMIA (cierre-periodo) con una fila sin confirmar. Maté la 176 con KILL SESSION. La fila 101 quedó en ACTIVO y ya no había bloqueos.
- INC-602: la base estaba abierta pero academia_app estaba parado y no salía en el listener. Lo arranqué con DBMS_SERVICE.START_SERVICE y guardé el estado. La aplicación volvió a entrar.
- INC-603: APP_ACADEMIA estaba en LOCKED (no TIMED) y en la auditoría salía un ACCOUNT LOCK hecho por SYS. La desbloqueé con ACCOUNT UNLOCK y la aplicación volvió a entrar.

## Preguntas tipo examen de las partes

B1: B · C1: B · C2: A y C · D1: B · E1: B · F1: C · G1: B se queda solo con CREATE TABLE, el SELECT cae en cascada · G2: deja leer todas las tablas del esquema ventas, también las nuevas.

## Simulacro

- S1: B (Parte B)
- S2: C (Parte C)
- S3: B (Parte C)
- S4: B y C (Parte C)
- S5: C (Parte C)
- S6: B (Parte C)
- S7: A (Parte D)
- S8: B (Parte D)
- S9: C (Parte D)
- S10: C (Parte D)
- S11: B (Parte E)
- S12: A y C (Parte E)
- S13: B (Parte F)
- S14: A y C (Parte F)
- S15: A y C (Parte F)
- S16: B (Parte F)
- S17: B (Parte G)
- S18: B (Parte G)
- S19: A y B (Parte H)
- S20: B (Parte H)
- S21: C (Parte H)
- S22: C (Parte I)
