# Respuestas - Laboratorio 1: Git Fundamentals

1. **Working Directory vs Staging Area vs Local Repository:**
   El Working Directory es la carpeta visible en disco donde se editan archivos. La Staging Area es el área de preparación intermedia donde se eligen los cambios mediante `git add`. El Local Repository almacena la versión congelada con su hash dentro de `.git` tras hacer `git commit`.

2. **Modificación sin `git add`:**
   No aparece en el commit. Git solo registra los cambios que previamente fueron colocados en la Staging Area.

3. **Carpetas vacías en `git status`:**
   Git versiona contenidos/archivos y no directorios vacíos. Se soluciona creando un archivo placeholder dentro, por convención denominado `.gitkeep`.

4. **Qué es HEAD:**
   Es un puntero/referencia que indica la rama y el commit específico sobre el que estamos trabajando actualmente en nuestro Working Directory.

5. **`git switch -c` vs `mkdir`:**
   `mkdir` crea una carpeta física en disco. `git switch -c` crea una nueva rama (un puntero en `.git`) sin duplicar carpetas físicas en disco.

6. **Marcadores de conflicto:**
   El bloque entre `<<<<<<< HEAD` y `=======` contiene los cambios de la rama donde estamos parados (`main`). El bloque entre `=======` y `>>>>>>> fix/readme-subtitle` contiene las líneas entrantes de la rama que intentamos fusionar.

7. **Riesgo de `git commit --amend` tras `git push`:**
   `--amend` reescribe el hash del commit. Si ya está publicado, genera discrepancias de historial irreversibles y conflictos con los demás colaboradores.

8. **Borrar la carpeta `.git`:**
   Se pierde el historial completo, branches y configuración del repositorio Git. Los archivos locales actuales en el disco se mantienen intactos en su último estado.

9. **Git vs GitHub:**
   Git es la herramienta por línea de comandos para control de versiones en local. GitHub es el servicio de alojamiento colaborativo para compartir esos repositorios e integrar revisiones.

10. **Archivos `.env` con contraseñas en repositorios:**
    Aunque el repositorio sea privado, las credenciales quedan grabadas permanentemente en el historial, visibles para cualquiera con acceso de lectura o en caso de una filtración.

11. **Error `non-fast-forward`:**
    Ocurre porque el repositorio remoto tiene cambios que aún no existen en la copia local. Se soluciona ejecutando primero `git pull`.

12. **Tipos de Conventional Commits:**
    - Índice de rendimiento: `perf:`
    - Corregir restricción: `fix:`
    - Actualizar README: `docs:`
