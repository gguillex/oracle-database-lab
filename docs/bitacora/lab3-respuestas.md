# Lab 3 — Respuestas de comprobación

Autor: Guillermo Garcia Andugar · Issue #3

## Docker

**1. ¿Qué diferencia hay entre una imagen y un contenedor?**
La imagen es solo la plantilla base (tipo `hello-world` o `alpine`) y el contenedor es cuando ya la tienes corriendo. En la parte G2, hacer `docker run` me levantaba un contenedor nuevo de cero cada vez. En la G4 le metí un `sh` al final, me metí dentro a trastear y la imagen original ni se inmutó.

**2. En G5 `nota.txt` desapareció y en G6 no. ¿Por qué?**
Porque en la G5 el archivo de texto se guardó en el propio contenedor. Al borrarlo con `docker rm`, el archivo se perdió con él. En la G6 lo metí en un volumen externo (`datos-prueba`), así que cuando levanté el contenedor nuevo lo pilló sin problema.

**3. `docker ps` vs `docker ps -a`; ¿qué significa `Exited (0)`?**
`docker ps` te enseña solo lo que está funcionando ahora mismo. Si le metes el `-a` ves absolutamente todo, hasta los contenedores parados. Lo de `Exited (0)` significa que el proceso terminó bien por su cuenta. Si devuelve otro número distinto de cero, es que algo ha fallado.

**4. En `-p 8181:8181`, ¿qué número es de mi equipo y cuál del contenedor? ¿Qué pasaría con `-p 80:8080` en nginx?**
El de la izquierda es el puerto de mi máquina y el de la derecha el del contenedor. Si pongo `-p 80:8080` con nginx, le estoy enchufando mi puerto 80 al 8080 del contenedor. Como nginx escucha internamente en el 80 por defecto, la página no va a cargar en la vida.

**5. ¿Por qué Oracle se queda en marcha y hello-world termina solo?**
Porque el contenedor vive lo que dure su proceso principal. El hello-world escupe el texto por pantalla y se muere al instante. Oracle es un motor de base de datos, así que se queda en segundo plano abierto escuchando conexiones.

**6. ¿Qué es el digest y por qué lo registramos si usamos `:latest`?**
El digest es el identificador exacto e inmutable de una imagen (`sha256...`). El `:latest` es una etiqueta móvil, no fija, que va apuntando a imágenes distintas con el tiempo. Me guardo el digest para saber exactamente qué versión instalé y que luego una actualización no me cambie la imagen por debajo y me rompa la práctica.

**7. ¿Qué comando borraría de verdad los datos de Oracle? ¿Por qué `docker rm oralab-26ai` no lo hace?**
Con un `docker volume rm oralab-26ai-data`. El `docker rm` normal solo borra el contenedor de usar y tirar, pero los datafiles reales están en el volumen. De hecho borré el contenedor `oralab-26ai`, lo volví a crear y mi PDB y los cinco esquemas seguían ahí intactos.

## Git, organización y evidencia

**8. ¿Por qué el laboratorio se hace en el repositorio, con Issue, branch y PR?**
Para no tenerlo todo tirado en mi PC y que sea reproducible. Si lo hago con un Issue, una rama y un PR, cualquiera puede clonarlo, ver la evidencia de los scripts y montar lo mismo. Si lo dejo en una carpeta suelta y mi equipo falla, lo pierdo todo.

**9. `source 00-config.sh` vs `bash 00-config.sh`.**
Si lo ejecutas con `bash`, te abre una consola hija nueva por debajo y al terminar pierdes las variables. Con `source` se lanza en tu misma terminal de trabajo, así que las variables como el nombre del contenedor o las fechas se te quedan en memoria para usarlas al instante en el siguiente comando.

**10. Explica `20260915T091230Z_02-docker.script.log`.**
Lo primero es la fecha exacta en UTC. El `02` es el número del paso por el que voy. Lo de `docker` es la descripción, y `.script.log` es para saber de un vistazo que he capturado la salida de la terminal y no que es un spool de SQL.

**11. ¿Para qué sirve `.gitattributes` y qué error evita?**
Para forzar que todos los scripts se guarden con los saltos de línea de Linux (LF). Si los editas en Windows se te guardan en CRLF, y luego al intentar ejecutarlos en Linux te empiezan a salir errores absurdos de `command not found` por culpa de retornos de carro invisibles.

**12. ¿Por qué *Create a merge commit* y no *Squash and merge*?**
Porque quiero que cada paso se quede guardado por separado en el historial. Si le doy a Squash, me aplasta todo en un solo commit gigante y pierdo el rastro paso a paso de cómo fui configurando cada herramienta.

## Seguridad

**13. Las cuatro capas de la estrategia de contraseñas.**
Primero meto el archivo `.env` en el `.gitignore` para curarme en salud. Luego subo al repo solo una plantilla de mentira sin los valores reales. Me creo el real en local y compruebo con git que está ignorado. Por último, lo cargo con `source` para usar las contraseñas como variables. Si me salto el primer paso, puedo acabar subiendo la contraseña con un push y quedaría en el historial.

**14. ¿Por qué no escribir la contraseña en el `docker run` aunque el script no se suba?**
Porque si la escribes tal cual, se queda en texto plano guardada para siempre en el historial de comandos del bash de tu máquina. Si uso `"$ORACLE_PWD"`, en el historial solo se guarda el nombre de la variable y no dejas rastro.

**15. Si la contraseña aparece en un commit ya publicado, ¿basta con borrarla?**
No. Si solo la borras, se queda en el historial antiguo de los commits de git. Hay que darla por comprometida, cambiarla por una contraseña nueva, dejar de hacer push inmediatamente y avisar al profesor para que limpien la rama.

## Oracle y herramientas

**16. ¿Por qué no usamos SPOOL ni `@archivo.sql` con sqlplus dentro del contenedor?**
Porque sqlplus está corriendo aislado dentro de Docker. Si haces SPOOL te escupe el archivo dentro del contenedor, y si haces `@archivo` lo intenta buscar también ahí dentro (y te tira error). Hay que pasarle el script desde mi máquina con `<` y guardar la salida en mi terminal con `tee`.

**17. ¿Qué hace `WHENEVER SQLERROR EXIT SQL.SQLCODE` y qué pasaría sin ella?**
Hace que si falla cualquier cosa en el SQL, se corte todo de golpe. Si no lo pones, muestra el error pero sigue ejecutando lo de abajo, y eso es un problema porque te va a aplicar migraciones nuevas sobre un estado que se ha quedado a medias o roto.

**18. ¿Qué es una migración y por qué V000 y V001 no se editan una vez aplicadas?**
Es un script numerado para ir avanzando la base de datos de un estado inicial al siguiente. Si ya la has aplicado, no la puedes editar en texto porque entonces tu repositorio ya no cuadra con lo que tienes ejecutado de verdad en la base de datos. Si hay un error, se crea una migración nueva para corregirlo.

**19. ¿Por qué en SQL Developer se usa el servicio FREEPDB1 y no FREE ni un SID?**
Porque FREEPDB1 es mi base de datos conectable (PDB), donde de verdad están mis tablas y mi trabajo. Si entro a FREE a secas o con el SID acabo metido en el contenedor raíz de Oracle, y ahí no existen ni mis esquemas ni mis usuarios de la práctica.

**20. ¿Qué aporta SQLcl frente a SQL*Plus y por qué dominar ambas?**
SQLcl es lo nuevo: tiene autocompletado, historiales, guarda las conexiones y te formatea la salida limpia. Pero SQL*Plus es el viejo confiable, está en todos los servidores Oracle desde hace años. Si algún día entro a un servidor de producción que no tiene más herramientas, tengo que saber usarlo sí o sí.

## Entorno de trabajo

**21. ¿Por qué pasamos de Git Bash a Ubuntu en WSL 2?**
Porque al final Docker, Oracle y los servidores reales van en Linux. Git Bash en Windows te estropea las rutas al intentar emularlas, da fallos raros con los argumentos de Docker y le faltan herramientas básicas. Trabajando en Linux nativo me ahorro esos problemas y todo funciona como tiene que ir a la primera.

**22. ¿Por qué clonar en `~/oracle-database-lab` y no en `/mnt/c/...`? ¿Por qué bash y no zsh?**
Si clono el repo en el disco de Windows (`/mnt/c`), cada vez que Docker lee algo tiene que cruzar el sistema de archivos, va lentísimo y pierdes los permisos de ejecución de los scripts. Y uso bash porque es lo estándar; te lo vas a encontrar en el 100% de los servidores, mientras que zsh casi nunca está instalada por defecto.
