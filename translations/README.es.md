<p align="center">
  <img src="../assets/icon-256.png" alt="DockTouchBar" width="128" height="128">
</p>

<h1 align="center">DockTouchBar</h1>

<p align="center">
  <strong>Tu Dock en la Touch Bar.</strong>
  <br>
  <strong>Simple · Elegante · Eficiente</strong>
  <br>
  Toca para cambiar · doble toque para minimizar · mantén presionado para cerrar
  <br>
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest">Descargar</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar">Página del producto</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar/diary">Diario de construcción</a>
</p>

<p align="center">
  <a href="../README.md">English</a> ·
  <a href="README.zh-CN.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.pt.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.tr.md">Türkçe</a>
</p>

> **Una sola app:** DockTouchBar muestra en los iconos el estado en directo de tus agentes de programación con IA (se puede desactivar en Ajustes). El antiguo «DockTouchBar Vibe» se ha integrado aquí. Detalles y descarga: [English README](../README.md#what-it-is).

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-444.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20silicon-tested-2e7d32.svg" alt="Apple silicon: tested">
  <img src="https://img.shields.io/badge/Intel-untested-f9a825.svg" alt="Intel: untested">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

![DockTouchBar en la Touch Bar](../assets/touchbar-idle.gif)
*Estado inactivo: aplicaciones alineadas en la parte inferior con punto de insignia activo en la esquina superior derecha (rojo para la aplicación frontal); taza de café de arte de píxeles con vapor animado en vivo.*

![Mantén presionado para cerrar: animación de cuatro estaciones](../assets/touchbar-seasons.gif)
*Mantén presionado para cerrar: escenas de cuenta regresiva de arte de píxeles con desplazamiento lateral en cuatro estaciones (perro corriendo en primavera / barco navegando en verano / zorro en bosque de otoño / trineo en invierno). Suelta antes para cancelar, con explosión de temporada final.*

### ⚡ Energía y Rendimiento Nativo (Medidas de Versiones Anteriores)

Diseñado para residencia en segundo plano 24/7 utilizando actualizaciones de aplicación y ventana basadas en eventos. Las mediciones a continuación son de versiones anteriores; la actividad de captura de pantalla utiliza temporalmente una verificación de proceso corta:

| Métrica | Medido | Notas |
|---|---|---|
| **Uso de CPU** | **0.0% ~ 0.8%** | Inactivo 0.0%; picos brevísimos insignificantes solo en eventos de cambio de aplicación/ventana |
| **Huella Física** | **29 MB** | Medido con la herramienta `footprint` de macOS, fracción de alternativas Electron |
| **Impacto de Energía** | **0.0** | Calificación de impacto de energía más baja posible en Monitor de Actividad de macOS, cero impacto en la batería |
| **Hilos Residentes** | **4 hilos (todos durmiendo en eventos)** | Sin espera ocupada, sin encuestas de temporizador de alta frecuencia |
| **Acceso de Red** | **Verificaciones de actualización de GitHub y descargas** | Las interacciones del Dock se ejecutan localmente; sin análisis ni cuentas |
| **Latencia de Renderizado** | **~2.3 ms / fotograma** | Canalización de renderizado nativa CoreAnimation / AppKit para capacidad de respuesta al toque instantánea |

**Si DockTouchBar te es útil, una ⭐ Estrella en GitHub es la mejor manera de decir gracias.**

## Por qué

Pock, PockV2 y similares pueden poner el Dock en la Touch Bar, pero hacen mucho más, y en el uso diario la barra tiende a desaparecer o dejar de responder. DockTouchBar se mantiene enfocado en un trabajo y lo hace bien.

**Simple**

- Un trabajo: tu Dock en la Touch Bar. Sin widgets, sin plugins.
- Un puñado de interruptores en la barra de menú, nada más que configurar.
- Swift nativo y AppKit, sin dependencias de terceros. Las escenas de arte de píxeles están incluidas en el código fuente.

**Elegante**

- Utiliza iconos de macOS y el desplazador de Touch Bar del sistema. Las aplicaciones en ejecución sin anclar aparecen a la izquierda, más recientes primero; las aplicaciones ancladas mantienen su orden en el Dock. Cerrar una aplicación mantiene el área visible actual.
- Gestos que se salen del camino: un toque actúa inmediatamente (nunca espera para ver si viene un doble toque), y mantén presionado muestra una barra de progreso tranquila bajo el icono, más una cuenta regresiva de "Cerrando…" en el borde derecho de la Touch Bar para que tu dedo nunca la oculte, dibujada como una pequeña escena de arte de píxeles que puedes cambiar entre cuatro estaciones. Suelta antes para cancelar.
- Los toques rápidos se sienten bien: el último toque siempre gana, y nunca lucha contra ti. Si el sistema pierde un cambio de escritorio o algo roba el enfoque, coloca silenciosamente las cosas en orden, y se detiene en el momento en que tocas el teclado, ratón o trackpad.
- Habla tu idioma (12 idiomas, desde inglés hasta 简体中文 y 日本語) y pide solo un permiso opcional.

**Eficiente**

- Actualizaciones de aplicación y ventana basadas en eventos. Mediciones anteriores en una MacBook Pro M1 con el Dock mostrándose e inactivo: **0.0% CPU**, **0 activaciones inactivas**, aproximadamente **32 MB** de memoria.\*
- Se adapta a tu Mac en lugar de utilizar retrasos fijos: los cambios de escritorio esperan la señal "finalizado" del propio sistema y verifican el resultado, por lo que permanece correcto independientemente de si las animaciones son lentas, apagadas o la máquina está ocupada.
- Cuando las aplicaciones se inician o cierran, solo se actualiza lo que cambió y se mantiene tu posición de desplazamiento. Los iconos se rasterizan una vez y se almacenan en caché.
- Auto-reparador: se vuelve a conectar después del sueño, desbloqueo de pantalla y reinicios de Control Strip, por lo que nunca tienes que relanzarlo.
- Falla de forma segura: las APIs privadas se resuelven en tiempo de ejecución. Si macOS elimina una, esa función se apaga en lugar de fallar.
- Privacidad: sin análisis ni cuentas. Las interacciones del Dock se ejecutan localmente; las verificaciones de actualización automáticas y las descargas solicitadas se conectan a GitHub. Las preferencias permanecen en tu Mac.

<sub>\* Compilación de lanzamiento. CPU de cinco muestras `top` 2 s aparte (todas 0.0%); activaciones del contador por proceso del kernel leídas 20 s aparte, tres veces en 1.10 (0 activaciones inactivas y 0 activaciones de interrupción cada vez; una ejecución anterior en 1.8 vio 0–7 activaciones de interrupción, desde eventos del sistema); la memoria es la huella física de `footprint` (32 MB). El vapor sobre la taza de café es dibujado por el proceso de renderizado del sistema, no por la aplicación.</sub>

## Características

| Gesto | Qué sucede |
|---|---|
| **Toca** un icono | Cambia a la aplicación, o lánzala. Si sus ventanas están en otro escritorio (Space), salta a ese escritorio |
| **Doble toque** | Minimiza la ventana actual, como su botón amarillo. Necesita permiso de Accesibilidad. Toca de nuevo para restaurar |
| **Mantén presionado** | Cierra la aplicación, y siempre te dice lo que sucedió. Una barra de progreso se llena bajo el icono mientras mantienes presionado, y una cuenta regresiva de "Cerrando…" aparece en el borde derecho sobre una estación de arte de píxeles (tu elección en el menú); suelta antes y cuenta como un toque. La aplicación siempre se cierra completamente (igual que ⌘Q), sin importar su número de ventanas o si están minimizadas u ocultas. Finder no se puede cerrar, por lo que todas sus ventanas se cierran en su lugar (las minimizadas también; si están en otro escritorio, salta allí primero). Si la aplicación no se puede cerrar porque te está esperando (una hoja de "cambios sin guardar") o no se cierra, la Touch Bar cambia a ella, entre escritorios, y lo dice |
| **Papelera** | Toca para abrir la ventana de Papelera en Finder; doble toque la minimiza; mantén presionado para cerrarla. Se oscurece mientras la ventana está cerrada (y desaparece en el modo "mostrar solo aplicaciones en ejecución") |
| **Deslizar** | Desplázate cuando los iconos no quepan todos; cerrar una aplicación mantiene el área actual en vista |
| **Taza de café** (extremo derecho, con vapor animado) | Tómate un descanso: oculta el Dock un momento y devuelve la Touch Bar al sistema (brillo, volumen). Regresa por sí solo después de 10–60 s |
| **Botón Centrar / maximizar** (extremo derecho) | Centra la ventana de la aplicación frontal; toca de nuevo para maximizarla (llena el área usable, no la pantalla completa nativa), y de nuevo para centrarla. Si moviste la ventana tú mismo o cambiaste de aplicación, se centra primero, y el icono sigue el estado actual de la ventana. Necesita permiso de Accesibilidad |

El menú de la barra de menú mantiene los interruptores cotidianos: Mostrar Dock en Touch Bar, Mostrar solo aplicaciones en ejecución (desactivado de forma predeterminada: también se muestran las aplicaciones ancladas; las aplicaciones que se oscurecerían, incluido Finder sin ventanas y una Papelera cerrada, se ocultan, y Finder se sienta en el extremo izquierdo), Centrar los iconos (cuando caben; una vez que se desbordan comienzan desde la izquierda y se desplazan), Mostrar el botón centrar / maximizar, y Iniciar al conectarse. **Ajustes…** abre la ventana de ajustes, que tiene tres páginas:

- **Ajustes** — espaciado de iconos; tiempo de ocultamiento después de tocar la taza de café (10 / 20 / 30 / 60 s); el tamaño de la ventana centrada (60–100% de la altura de la pantalla; ancho igual a la altura, u 50–100% del ancho de la pantalla); doble toque para minimizar; mantén presionado para cerrar (Desactivado / 1 / 2 / 3 / 5 s) y su estilo (Primavera / Verano / Otoño / Invierno, con una vista previa corta en la Touch Bar); cediendo a los controles de Touch Bar del sistema (interruptores de captura de pantalla / grabación y Fn independientes, activados de forma predeterminada); idioma (Seguir Sistema, u uno de 12 idiomas — mostrado en la parte superior de la página de Ajustes; también traduce los mensajes de mantén presionado de la Touch Bar); estado del permiso de Accesibilidad con un atajo a Ajustes del Sistema (nada más necesita un permiso); y el diagnóstico "¿por qué no puedo ver el Dock?"
- **Cómo usar** — gestos y botones
- **Acerca de** — versión, verificación de actualización, página del producto y enlaces del diario de construcción, botón Estrella

La aplicación también tiene un icono en el Dock, por lo que puedes lanzarla desde allí después de instalarla.

Abrir la aplicación de nuevo desde Aplicaciones mientras se está ejecutando abre el menú.

## Requisitos y entorno probado

| | |
|---|---|
| Hardware | Una Mac con Touch Bar (MacBook Pro 2016–2022) |
| **Probado en** | **MacBook Pro 13" (M1, `MacBookPro17,1`), macOS 27.0, pantalla única, 3 Espacios, Touch Bar configurada en "Expanded Control Strip", Administrador de escenas activado** |
| Apple silicon (M1) | ✅ Esta es la máquina en la que se desarrolla y se usa |
| Intel | ⚠️ **Desconocido.** La descarga es un binario universal y la porción Intel se inicia bajo Rosetta en una Mac M1, pero nunca se ha ejecutado en una Mac Touch Bar Intel real. Se agradecen los reportes |
| versión de macOS | Construido con un mínimo de macOS 13, pero solo probado en macOS 27.0. Las versiones anteriores no se han probado |

Cosas a saber:

- Utiliza **APIs privadas de Apple** para mantener una Touch Bar en pantalla desde una aplicación en segundo plano. Por eso tampoco puede estar en la Mac App Store, y por qué una futura actualización de macOS podría romperla. Las interfaces privadas se resuelven en tiempo de ejecución, por lo que si una desaparece esa función se apaga en lugar de fallar; `swift tools/probe-private-api.swift` muestra cuáles tu macOS aún tiene.
- El Dock toma toda la Touch Bar **completa**, por lo que el Control Strip del sistema (brillo, volumen) se oculta mientras está activado. Toca la pequeña taza de café en la derecha de la barra para ocultar el Dock un momento y devolver la Touch Bar al sistema (regresa por sí solo después de 10–60 segundos, 20 de forma predeterminada — u, si la pantalla se apagó completamente, tan pronto como se aumente el brillo). También puedes desmarcar "Mostrar Dock en Touch Bar" en el menú.
- Orden de izquierda a derecha: aplicaciones en ejecución sin anclar (más recientes primero) → divisor → Finder → aplicaciones ancladas en el orden del Dock → divisor → Papelera. Las aplicaciones nuevas sin anclar aparecen a la vista a la izquierda; cambiar entre aplicaciones abiertas no las reordena. Toca Papelera para abrirla en Finder.
- Con Administrador de escenas activado, macOS anima el cambio de ventana, por lo que la ventana puede tardar aproximadamente medio segundo en aparecer en pantalla. La aplicación tocada se convierte en la aplicación frontal en aproximadamente 40 ms; el resto es la animación del sistema.

## Instalar

1. Descarga `DockTouchBar-<version>.dmg` desde [Releases](https://github.com/hooosberg/DockTouchBar/releases/latest).
2. Ábrelo y arrastra **DockTouchBar** a **Aplicaciones**, luego lánzalo. Un icono de Dock aparece en la barra de menú y en la Touch Bar.

> El DMG está firmado con un certificado de Developer ID y **notarizado por Apple**, por lo que se abre como cualquier otra aplicación. macOS solo te pedirá que confirmes el primer lanzamiento. ¿Prefieres compilarlo tú mismo? Ver [Compilar desde la fuente](#compilar-desde-la-fuente).

### Permiso de Accesibilidad (opcional)

Accesibilidad habilita cambio de ventana entre escritorios, minimización con doble toque, centro / maximización, cierre de ventanas de Finder, detección de diálogos de confirmación y ceder a Fn. Sin él, el lanzamiento y activación básicos permanecen disponibles; estas características están limitadas.

1. Icono de la barra de menú → **Ajustes…** → **Permisos** → **Activar…** (una vez otorgado lee **Accesibilidad: activado**)
2. En Ajustes del Sistema → Privacidad y Seguridad → Accesibilidad, activa DockTouchBar.

Si sigue preguntando después de que lo activaras, la entrada anterior está obsoleta (esto sucede cuando la firma de la aplicación cambió): selecciona DockTouchBar en la lista, haz clic en **−**, luego agrégalo de nuevo. O ejecuta `tccutil reset Accessibility com.maohuhu.docktouchbar` y repite el paso 1.

### Si un toque no cambia de escritorio

Justo después de que suceda, ejecuta esto desde un clon del repositorio. Es de solo lectura e imprime cómo la aplicación juzgó las ventanas de esa aplicación (qué ventanas existen, qué escritorio tiene cada una, cuáles son ventanas reales, cuál elevaría):

```bash
tools/diagnose-switch.sh com.google.Chrome
```

## ¿No puedes ver el Dock?

Causa más común: Ajustes del Sistema → Teclado → "Touch Bar Shows" está configurada en "Teclas F1, F2, etc.", que llena toda la Touch Bar con teclas de función. Desde la versión 1.16 la aplicación lo detecta y ofrece cambiarlo a "Expanded Control Strip" al primer lanzamiento. También puedes hacer clic en "Diagnosticar: ¿por qué no puedo ver el Dock?" en el menú de la barra de menú para verificar cada causa posible y copiar un informe para comentarios. Mantener presionada Fn aún muestra F1–F12 después.

## Compilar desde la fuente

Requiere las herramientas de línea de comandos de Xcode.

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # compilar → copiar a /Applications → lanzar
scripts/make-dmg.sh     # build/DockTouchBar-<version>.dmg
```

Sin un certificado de firma, la compilación recurre a la firma ad hoc. Eso funciona, pero macOS trata cada recompilación ad hoc como una nueva aplicación, por lo que tienes que volver a otorgar Accesibilidad cada vez. Establece `SIGN_IDENTITY="Apple Development: …"` (o un certificado Developer ID) para mantener una identidad estable.

## Disposición del proyecto

```
Sources/DockTouchBar/   Código fuente de la aplicación
Resources/              Info.plist, icono de la aplicación
scripts/                build.sh, install.sh, make-dmg.sh, make-icon.sh
tools/                  Diagnósticos: verificación de API privada, inspector de Espacios/ventanas, diagnóstico de cambio, prueba de estrés de clics rápidos, vista fuera de pantalla, y render-seasons.sh (las capturas de pantalla del README)
assets/                 Imágenes del README
```

Después de una gran actualización de macOS, ejecuta `swift tools/probe-private-api.swift` para ver cuáles APIs privadas aún están disponibles.

## Licencia

[PolyForm Noncommercial License 1.0.0](../LICENSE) — libre para usar, copiar, modificar y compartir para **propósitos personales y otros no comerciales**. **El uso comercial no está cubierto** y necesita una licencia separada del autor; por favor comunícate a través de [hooosberg.com](https://hooosberg.com/).

Esta es una licencia de código disponible, no una licencia de código abierto aprobada por OSI. Aviso requerido: Copyright © 2026 hooosberg.

## Autor

Hecho por **hooosberg** — [hooosberg.com](https://hooosberg.com/) · [GitHub](https://github.com/hooosberg). Si esto te ahorró algunos toques, por favor ⭐ el repositorio.
