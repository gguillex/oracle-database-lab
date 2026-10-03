# Lab 3 — Respuestas de comprobación

Autor: Guillermo Garcia Andugar · Issue #3

## Docker

**1. ¿Qué diferencia hay entre una imagen y un contenedor?**
La imagen es una plantilla de solo lectura (por ejemplo `hello-world` o `alpine:3.20`) y el contenedor es una instancia en ejecución creada a partir de ella. En G2 la misma imagen `hello-world` generó un contenedor nuevo cada vez que hice `docker run`; en G4 `docker run -it --name prueba alpine:3.20 sh` creó un contenedor con su propio sistema de archivos, en el que pude entrar, mientras la imagen seguía intacta.

**2. En G5 `nota.txt` desapareció y en G6 no. ¿Por qué?**
En G5 el archivo se escribió en la capa de escritura del propio contenedor: al hacer `docker rm prueba` esa capa se borró con él, y `prueba2` arrancó limpio desde la imagen. En G6 se escribió en `/datos`, montado sobre el volumen con nombre `datos-prueba`, que vive fuera del ciclo de vida del contenedor; por eso el segundo contenedor encontró el dato.

**3. `docker ps` vs `docker ps -a`; ¿qué significa `Exited (0)`?**
`docker ps` solo lista los contenedores en marcha; `docker ps -a` lista todos, también los detenidos. `Exited (0)` indica que el proceso principal terminó correctamente (código 0); un código distinto de 0 significa que terminó con error.

**4. En `-p 8181:8181`, ¿qué número es de mi equipo y cuál del contenedor? ¿Qué pasaría con `-p 80:8080` en nginx?**
El formato es `anfitrión:contenedor`: el primero es el puerto de mi equipo y el segundo el del contenedor. Con `-p 80:8080`, mi puerto 80 se reenviaría al 8080 del contenedor, pero nginx escucha en el 80, así que la página no cargaría.

**5. ¿Por qué Oracle se queda en marcha y hello-world termina solo?**
Un contenedor vive lo que vive su proceso principal. El de `hello-world` imprime un mensaje y termina; el de Oracle es el motor de base de datos, que se queda escuchando conexiones indefinidamente.

**6. ¿Qué es el digest y por qué lo registramos si usamos `:latest`?**
El digest (`sha256:...`) es la huella exacta e inmutable de una imagen. `:latest` es una etiqueta móvil que apunta a versiones distintas con el tiempo; registrando el digest (evidencia 04) queda constancia de la versión exacta de Oracle que instalé.

**7. ¿Qué comando borraría de verdad los datos de Oracle? ¿Por qué `docker rm oralab-26ai` no lo hace?**
`docker volume rm oralab-26ai-data` (o un `docker system prune --volumes` sin leer). Los datafiles están en el volumen con nombre montado en `/opt/oracle/oradata`, no dentro del contenedor; `docker rm` borra el contenedor pero no el volumen. De hecho, en este laboratorio recreé `oralab-26ai` y FREEPDB1 conservó los 5 esquemas.

## Git, organización y evidencia

**8. ¿Por qué el laboratorio se hace en el repositorio, con Issue, branch y PR?**
Para que la instalación sea reproducible, verificable y revisable: los scripts y la evidencia quedan versionados, otra persona revisa el cambio antes de llegar a `main` y cualquiera puede reconstruir el entorno. En una carpeta aparte el conocimiento solo viviría en mi máquina (un *snowflake server*).

**9. `source 00-config.sh` vs `bash 00-config.sh`.**
`bash` ejecuta el script en un proceso hijo: las variables desaparecen al terminar. `source` lo ejecuta en la shell actual, así que `CONT_NAME`, `EVID`, `ts`, etc. quedan disponibles para los comandos siguientes. Por eso las constantes se cargan con `source`.

**10. Explica `20260915T091230Z_02-docker.script.log`.**
`20260915T091230Z` es la marca de tiempo ISO 8601 en UTC (fecha, `T`, hora, `Z` = UTC); `02` es el número de paso; `docker` la descripción en kebab-case; `.script.log` indica que es una captura de terminal (frente a `.spool.log` de SQL o `.png` de captura).

**11. ¿Para qué sirve `.gitattributes` y qué error evita?**
Obliga a guardar `.sh`, `.sql` y `.md` con finales de línea LF. Evita que un script editado en Windows (CRLF) falle en Linux con errores como `$'\r': command not found` y que los diffs se llenen de cambios invisibles.

**12. ¿Por qué *Create a merge commit* y no *Squash and merge*?**
Porque cada commit corresponde a una Parte del laboratorio y tiene valor propio como registro de cuándo y cómo se verificó cada herramienta. Squash los aplastaría en uno solo y se perdería ese historial paso a paso.

## Seguridad

**13. Las cuatro capas de la estrategia de contraseñas.**
1) Añadir `config/.env` a `.gitignore` antes de crearlo; 2) versionar solo la plantilla `config/.env.example` sin valores reales; 3) crear el `config/.env` real local y comprobar con `git check-ignore`; 4) cargar los secretos con `set -a; source config/.env; set +a` y usarlos como variables, sin teclearlos. Si me salto la primera, el `.env` real podría entrar en un `git add .` y la contraseña quedaría para siempre en el historial.

**14. ¿Por qué no escribir la contraseña en el `docker run` aunque el script no se suba?**
Porque todo lo que se teclea queda en texto plano en `~/.bash_history` (y en grabaciones con `script`). Usando `"$ORACLE_PWD"` solo queda el nombre de la variable.

**15. Si la contraseña aparece en un commit ya publicado, ¿basta con borrarla?**
No: sigue en el historial y cualquiera puede recuperarla. Hay que darla por comprometida y rotarla (cambiarla y recrear el entorno con la nueva), no hacer más push y avisar al docente para limpiar la branch.

## Oracle y herramientas

**16. ¿Por qué no usamos SPOOL ni `@archivo.sql` con sqlplus dentro del contenedor?**
sqlplus corre dentro del contenedor: SPOOL escribiría el archivo en el sistema de archivos del contenedor y `@archivo.sql` buscaría el script allí, donde no existe (SP2-0310). En su lugar redirigimos el archivo del repositorio con `< archivo.sql` y capturamos la salida con `| tee`.

**17. ¿Qué hace `WHENEVER SQLERROR EXIT SQL.SQLCODE` y qué pasaría sin ella?**
Hace que sqlplus termine en el primer error devolviendo su código, de modo que `08-aplicar-migraciones.sh` detecta el fallo y no ejecuta V001 sobre un V000 fallido. Sin ella sqlplus seguiría ejecutando sentencias sobre un estado a medias.

**18. ¿Qué es una migración y por qué V000 y V001 no se editan una vez aplicadas?**
Un script SQL numerado que lleva la base de un estado al siguiente, aplicado en orden. Una vez aplicada, editarla haría que el repositorio ya no describa lo que realmente se ejecutó y que otros entornos diverjan; si hay que corregir algo se crea una migración nueva (V002…).

**19. ¿Por qué en SQL Developer se usa el servicio FREEPDB1 y no FREE ni un SID?**
FREEPDB1 es la PDB donde están los esquemas de trabajo. FREE es el servicio de la CDB raíz (CDB$ROOT) y con SID también acabaríamos en el contenedor raíz, donde no están los usuarios `ADMIN_*` ni `ALUMNO`.

**20. ¿Qué aporta SQLcl frente a SQL*Plus y por qué dominar ambas?**
SQLcl es la herramienta moderna: autocompletado, historial, formato automático (`SET SQLFORMAT ansiconsole`), conexiones guardadas (`CONNECT -save`) e integración con Liquibase. SQL*Plus existe en cualquier servidor Oracle desde 1982 y a veces es lo único disponible en una terminal de producción, así que un DBA debe saber usar las dos.

## Entorno de trabajo

**21. ¿Por qué pasamos de Git Bash a Ubuntu en WSL 2?**
Porque Oracle, Docker y los servidores reales son Linux, y en Linux nativo/WSL 2 no hay emulación. Problemas de Git Bash que desaparecen: convierte rutas `/opt/...` a rutas de Windows y rompe argumentos de Docker; `docker run -it` necesita `winpty` o falla con "not a TTY"; faltan `free`, `ss` o `htop`; y las herramientas Java dan problemas con la petición de contraseñas. (En mi caso trabajo directamente en Linux nativo, que cumple lo mismo.)

**22. ¿Por qué clonar en `~/oracle-database-lab` y no en `/mnt/c/...`? ¿Por qué bash y no zsh?**
En `/mnt/c` cada operación cruza entre dos sistemas de archivos: Git y Docker van mucho más lentos, se pierden permisos de Linux (como el de ejecución) y reaparecen problemas de finales de línea. Bash porque es la shell por defecto de prácticamente todos los servidores: un script en bash funciona en cualquiera, mientras que zsh tiene diferencias sutiles y normalmente no está instalada.
