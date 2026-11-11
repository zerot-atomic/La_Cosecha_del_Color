# ERRORES BASELINE - La Cosecha del Color

Fecha: 2026-11-10
Godot: 4.7.2 (gl_compatibility)

---

## 1. ERRORES DE PARSEO / CARGA DE SCRIPTS (Bloqueantes)

### Grupo A: RoomLabyrinth.gd - Constructor Transform3D inválido
**Archivo:** `scripts3d/RoomLabyrinth.gd:358`
**Escenas afectadas:** `Room_laberinto.tscn`, `Zone3D_laberinto.tscn`
**Error:**
```
SCRIPT ERROR: Parse Error: No constructor of "Transform3D" matches the signature "Transform3D(float, float, float, int, float, float, float, float, float, int, int, int)".
```
**Causa:** Línea 358 usa `Transform3D(0.8, -0.5, 0.33, 0, 0.55, 0.83, -0.6, -0.66, 0.44, 0, 8, 0)` con 12 parámetros numéricos. El constructor correcto en Godot 4 es `Transform3D(Basis, Vector3)` o 9 floats para Basis + 3 para origin.

### Grupo B: test_vision_ending.gd - Variable sin nombre
**Archivo:** `scripts3d/test_vision_ending.gd:187`
**Escena afectada:** `TestVisionEnding.tscn`
**Error:**
```
SCRIPT ERROR: Parse Error: Expected variable name after "var".
```
**Causa:** Sintaxis inválida en la declaración de variable.

---

## 2. ADVERTENCIAS COMUNES (No bloqueantes, aparecen en todas las ejecuciones)

### WARNING: ObjectDB instances leaked
```
WARNING: 4 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
```
**Frecuencia:** 4 instancias en la mayoría de zonas, 8 en `Zone3D_establo.tscn`

### ERROR: Resources still in use at exit
```
ERROR: 2 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```
**Frecuencia:** 2 recursos en la mayoría, 4 en `Zone3D_establo.tscn`

---

## 3. MENSAJES INFORMATIVOS DEL JUEGO

### InputProfiles - Bindings version mismatch
```
[InputProfiles] Bindings version 0 < 2, discarding inverted user bindings
```
**Archivo:** `autoload/InputProfiles.gd`
**Significado:** Guarda bindings de usuario con versión 0, se descartan por ser inferiores a la versión actual (2). Indica migración de bindings pendiente.

---

## 4. ESCENAS QUE CARGAN CORRECTAMENTE (Sin errores de script/recursos)

| Escena | Estado |
|--------|--------|
| ChildShoe.tscn | ✅ Carga OK |
| Credits3D.tscn | ✅ Carga OK (warnings genéricos) |
| EndingBad3D.tscn | ✅ Carga OK (warnings genéricos) |
| EndingGood3D.tscn | ✅ Carga OK (warnings genéricos) |
| MainMenu3D.tscn | ✅ Carga OK (warnings genéricos) |
| Player3D.tscn | ✅ Carga OK |
| Room_atico.tscn | ✅ Carga OK |
| Room_bosque.tscn | ✅ Carga OK |
| Room_camino_entrada.tscn | ✅ Carga OK |
| Room_campo_cultivo.tscn | ✅ Carga OK |
| Room_casa_principal.tscn | ✅ Carga OK |
| Room_crater_meteorito.tscn | ✅ Carga OK |
| Room_establo.tscn | ✅ Carga OK |
| Room_pozo.tscn | ✅ Carga OK |
| ScreamerOverlay.tscn | ✅ Carga OK |
| Vision3D.tscn | ✅ Carga OK |
| Wrapper3D.tscn | ✅ Carga OK |
| WrapperTest3D.tscn | ✅ Carga OK |
| Zone3D_atico.tscn | ✅ Carga OK (warnings genéricos) |
| Zone3D_bosque.tscn | ✅ Carga OK |
| Zone3D_camino_entrada.tscn | ✅ Carga OK (warnings genéricos) |
| Zone3D_campo_cultivo.tscn | ✅ Carga OK |
| Zone3D_casa_principal.tscn | ✅ Carga OK (warnings genéricos) |
| Zone3D_crater_meteorito.tscn | ✅ Carga OK (warnings genéricos) |
| Zone3D_establo.tscn | ✅ Carga OK (warnings genéricos x2) |
| Zone3D_pozo.tscn | ✅ Carga OK (warnings genéricos) |

---

## 5. ESCENAS CON ERRORES DE CARGA (Bloquean transición)

| Escena | Error | Causa raíz |
|--------|-------|------------|
| Room_laberinto.tscn | Parse Error Transform3D | RoomLabyrinth.gd:358 |
| Zone3D_laberinto.tscn | Parse Error Transform3D | RoomLabyrinth.gd:358 (instancia Room_laberinto) |
| TestVisionEnding.tscn | Parse Error variable name | test_vision_ending.gd:187 |

---

## 6. PROBLEMAS IDENTIFICADOS EN TRANSICIONES (FASE B1)

### 6.1 Laberinto vacío (Zona no cargable)
- `Zone3D_laberinto.tscn` no puede cargarse por error en `RoomLabyrinth.gd`
- Esto bloquea la transición desde `campo_cultivo` → `laberinto` y `bosque` → `laberinto`

### 6.2 Spawn markers faltantes / inconsistentes
- `Room_laberinto.tscn` **no tiene** nodos `SpawnDesdeBosque` ni `SpawnDesdeCampo` (los crea `RoomLabyrinth.gd:_build_spawns()` en runtime)
- `Zone3D_laberinto.tscn` usa `spawn_point_path = NodePath("Room_laberinto/SpawnDesdeBosque")` pero el nodo no existe en la escena base
- `Zone3D.gd:_spawn_player()` tiene fallback para `campo_cultivo` → `laberinto` pero no para `bosque` → `laberinto`

### 6.3 GameManager.EXITS vs nombres reales de nodos
- ExitArea3D en `Room_camino_entrada.tscn` usa `target_zone = "casa_principal"` y `"crater_meteorito"` ✅
- Pero `GameManager.EXITS["camino_entrada"]` apunta a coordenadas 2D (x,y) legacy, no se usa en 3D
- En 3D los ExitArea3D se colocan a mano en cada room_scene

### 6.4 ScreenDoorTransition traga errores
- Línea 160-163: Si `GameManager.change_zone()` falla, muestra error genérico pero no el error real de carga de escena
- No hay logs de qué escena falló ni por qué

---

## 7. PRÓXIMOS PASOS (FASE B)

1. **B1 - Transiciones:** Corregir RoomLabyrinth.gd:358 (Transform3D), añadir logs [TRANS] en ExitArea3D y ScreenDoorTransition, verificar spawn markers
2. **B2 - Laberinto:** Una vez cargue, verificar tabiques, perseguidor, spawns, triggers de salida
3. **B3 - Controles:** Diagnosticar inversión W/S y A/D en Player3D.gd e InputProfiles.gd
4. **B4 - Levitación:** Medir raycast desde modelo, añadir blob shadow si < 0.02m
5. **B5 - Pruebas:** Crear tools/TestNucleo.tscn con PASS/FAIL automáticos