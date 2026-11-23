# Lab 6 · Guardia: postmortems

Los tres incidentes los abrí con 08-guardia.sh y no usé limpiar. Antes de tocar nada pasé 08-diagnostico.sql con C##OPS_RO y después lo volví a pasar para comprobar. Las evidencias son las que empiezan por 08.

## INC-601 · La pantalla de secretaría se queda colgada
- Detección: 23:56 UTC. Ana García avisa de que al guardar la ficha del alumno 101 se le queda colgada la pantalla.
- Impacto: Ana no pudo guardar durante más o menos un minuto. El resto funcionaba; la lista de turno daba 1 sesión bloqueada.
- Diagnóstico: la sesión 177 de Ana estaba en enq: TX - row lock contention y la bloqueaba la 176. La 176 era APP_ACADEMIA con módulo matriculas y acción cierre-periodo, en PL/SQL lock timer (dormida) pero con una transacción abierta de 1 fila.
- Causa raíz: el proceso de cierre de periodo cambió la fila del alumno 101 y se quedó esperando sin hacer commit, así que tenía la fila bloqueada. No era un problema de la base ni del ordenador de Ana.
- Intervención: ALTER SYSTEM KILL SESSION '176,1927' IMMEDIATE. CANCEL SQL no valía porque deja la transacción abierta (lo vimos en la Parte D), y la 176 solo tenía una fila sin confirmar, así que deshacerla era inmediato.
- Validación: al repetir el diagnóstico ya no había esperas ni bloqueos, y la fila 101 estaba en ACTIVO.
- Acción preventiva: que el cierre de periodo haga commit antes de quedarse esperando y que no se lance en horario de secretaría. Y mirar en la guardia las sesiones que llevan mucho rato en enq: TX.

## INC-602 · La aplicación no conecta: ORA-12514
- Detección: 23:58 UTC. El equipo de matrículas dice que la aplicación no conecta y da ORA-12514.
- Impacto: la aplicación no pudo conectar durante algo más de un minuto (en el alert log el servicio se para a las 23:58:31 y lo arranqué a las 23:59:36). Lo que entraba por freepdb1 no se vio afectado.
- Diagnóstico: la base no estaba caída, la lista de turno daba FREE abierta y FREEPDB1 en READ WRITE. En lsnrctl status no salía academia_app y en el diagnóstico (sección 6) salía con ARRANCADO = NO. Con app.sh me salía el mismo ORA-12514.
- Causa raíz: alguien paró el servicio academia_app y no había nada que avisara de que un servicio estaba parado.
- Intervención: DBMS_SERVICE.START_SERVICE('academia_app') en FREEPDB1. No hacía falta reiniciar nada.
- Validación: academia_app vuelve a salir READY en el listener, la sección 6 lo da como arrancado y la aplicación entra con app.sh.
- Acción preventiva: hice SAVE STATE para que el servicio vuelva solo tras un reinicio (lo de la Parte C), y añadiría a la lista de turno la comprobación de servicios parados.

## INC-603 · La aplicación no entra: ORA-28000
- Detección: 00:00 UTC. Matrículas dice que la aplicación da ORA-28000 y que no han cambiado la contraseña. El turno de tarde dice que hoy se ejecutó el script de bajas.
- Impacto: la aplicación no pudo entrar durante aproximadamente un minuto.
- Diagnóstico: en la sección 7, APP_ACADEMIA salía en LOCKED, no en LOCKED(TIMED), y su perfil DEFAULT permite 10 intentos. Así que no se bloqueó por fallos de contraseña sino porque alguien hizo ACCOUNT LOCK. En la auditoría salió que SYS ejecutó ALTER USER app_academia ACCOUNT LOCK a las 00:00:07 desde sqlplus.
- Causa raíz: el script de bajas no distingue entre cuentas de personas y cuentas de aplicación, y bloqueó la de la aplicación.
- Intervención: ALTER USER app_academia ACCOUNT UNLOCK. No cambié la contraseña porque no hacía falta.
- Validación: la sección 7 ya no sale con ninguna cuenta y la aplicación entra con app.sh.
- Acción preventiva: que el script de bajas solo bloquee cuentas de personas (por ejemplo las de PRF_PERSONAS) y que alguien revise la lista antes de lanzarlo.
