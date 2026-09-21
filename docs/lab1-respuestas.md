# Respuestas - Laboratorio 1: Git Fundamentals
**Estudiante:** Guillermo Garcia Andugar
**Profesor:** Richard Aviles Lopez

1. **Working Directory vs Staging Area vs Local Repository:**
   El Working Directory es la carpeta física donde editas los archivos. La Staging Area es el área temporal donde preparas los cambios con `git add`. El Local Repository almacena los cambios definitivos mediante un commit en la base de datos interna `.git`.

2. **Modificación sin git add:**
   No aparece en el commit, ya que Git solo confirma los cambios que han sido enviados previamente a la Staging Area.

3. **Carpetas vacías en git status:**
   Git registra contenidos de archivos y no carpetas vacías. Se soluciona colocando un archivo placeholder dentro, comúnmente llamado `.gitkeep`.

4. **Qué es HEAD:**
   Es el puntero de referencia que indica sobre qué rama y commit exacto estamos posicionados actualmente.

5. **git switch -c vs mkdir:**
   `mkdir` crea una carpeta física en el disco. `git switch -c` crea una nueva rama en el historial de Git sin duplicar archivos físicamente.

6. **Marcadores de conflicto:**
   El bloque entre `<<<<<<< HEAD` y `=======` muestra las líneas de la rama actual (`main`). El bloque entre `=======` y `>>>>>>> fix/readme-subtitle` muestra las líneas de la rama que intentamos fusionar.

7. **Riesgo de git commit --amend tras git push:**
   Reescribe el hash del commit. Si ya está publicado en el remoto, genera divergencias incompatibles con otros colaboradores.

8. **Borrar la carpeta .git:**
   Se destruye todo el historial de commits, ramas y configuración de Git, aunque los archivos actuales visibles en disco se conservan.

9. **Git vs GitHub:**
   Git es el software de control de versiones local que corre en tu máquina. GitHub es una plataforma web para alojar repositorios en remoto y colaborar.

10. **Archivos .env con contraseñas en repositorios:**
    Aunque el repositorio sea privado, las credenciales quedan expuestas en el historial a cualquier usuario con acceso y vulnerables ante filtraciones.

11. **Error non-fast-forward:**
    Ocurre porque el repositorio remoto contiene commits que no están presentes en local. Se soluciona ejecutando `git pull` antes de subir cambios.

12. **Tipos de Conventional Commits:**
    - Índice de rendimiento: `perf:`
    - Corregir restricción: `fix:`
    - Actualizar README: `docs:`
