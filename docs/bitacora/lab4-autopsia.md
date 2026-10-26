# Autopsia de la instancia FREE

Evidencia: `docs/bitacora/lab4/evidencia/spool/20261026T183721Z_15-autopsia-instancia.spool.log`

## Hallazgos

| #   | Sección       | Evidencia (valor exacto)                                                                                                       | Riesgo | Acción | Prioridad |
| --- | ------------- | ------------------------------------------------------------------------------------------------------------------------------ | ------ | ------ | --------- |
| 1   | 4 · Archivos  | `redo log (miembro)` = 3 para 3 grupos (un miembro por grupo); `control file` = 2 en `/opt/oracle/oradata/FREE/`               | Alto. Si se corrompe el redo del grupo `CURRENT`, se pierden transacciones ya confirmadas. Los dos control files están en la misma carpeta del mismo volumen, así que un fallo de ese disco se lleva los dos a la vez. | Añadir un segundo miembro a cada grupo de redo en otra ruta (idealmente otro disco) y mover una copia del control file fuera de `FREE/`. | 1ª. Es lo único de la lista que puede hacer perder datos confirmados. |
| 2   | 4 · Archivos  | `db_recovery_file_dest` vacío y `db_recovery_file_dest_size` = 0; `archived log (en disco)` = 5 (353 MB) en `$ORACLE_HOME/dbs` | Alto. Los archivados crecen sin límite ni borrado automático, mezclados con el SPFILE y el password file. Si el disco se llena, ARCn no puede archivar y la base se queda parada. | Configurar la FRA (`db_recovery_file_dest` y `db_recovery_file_dest_size`) y llevar ahí los archivados. Está previsto en el Lab 5. | 2ª. No pierde datos, pero puede parar el servicio sin avisar. |
| 3   | 6 · Índices   | `ALTURA_MAX` vacía en ADMIN_CLINICA, ADMIN_FINTECH, ADMIN_LOGISTICA y ADMIN_RETAIL                                             | Medio. Sin estadísticas el optimizador estima a ciegas y puede elegir planes malos. Hoy apenas se nota porque esas tablas están vacías, pero empezará a notarse en cuanto tengan datos. | Lanzar `DBMS_STATS.GATHER_SCHEMA_STATS` en los cuatro esquemas y comprobar que la tarea automática de estadísticas está activa. | 4ª. Afecta al rendimiento, no a la seguridad de los datos. |
| 4   | 10 · Salud    | `ERRORES_ORA_24H` = 6: ORA-00800 (4), ORA-65025 (1), ORA-959 (1)                                                               | Bajo. Los tres tienen explicación: ORA-00800 es conocido (el contenedor no deja a VKTM y LGWR subir de prioridad); ORA-65025 lo provocó a propósito la Parte I al intentar borrar `PDB_LAB4` abierta; ORA-959 aparece a las 18:35, durante `13-capacidad.sql`, cuando prepara `TBS_LAB4`. | Documentarlos como conocidos y excluirlos de las alertas. Cualquier otro ORA- se investiga. | 5ª. No requiere cambios en la base. |
| 5   | 1 · Identidad | `FLASHBACK` = NO; `LOG_MODE` = ARCHIVELOG                                                                                      | Medio. Con ARCHIVELOG se puede recuperar tras un fallo físico, pero sin Flashback un error humano (un `DELETE` sin `WHERE`) solo se deshace restaurando una copia, que es mucho más lento. | Activar Flashback Database cuando la FRA esté configurada, porque depende de ella (hallazgo 2). | 3ª. Va justo después de la FRA. |

## Resumen para dirección

- La base funciona bien y la verificación final no encuentra ningún fallo; los problemas son de prevención, no de averías actuales.
- Lo urgente es duplicar los archivos de registro y control y darles un espacio propio con límite, para no perder datos ni quedarnos sin servicio si se llena el disco.
- Después conviene activar la vuelta atrás ante errores humanos y actualizar las estadísticas, que mejoran la recuperación y el rendimiento pero no corren prisa.
