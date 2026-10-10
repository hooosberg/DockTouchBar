<p align="center">
  <img src="../assets/icon-256.png" alt="DockTouchBar" width="128" height="128">
</p>

<h1 align="center">DockTouchBar</h1>

<p align="center">
  <strong>Il tuo Dock sulla Touch Bar.</strong>
  <br>
  <strong>Semplice · Elegante · Efficiente</strong>
  <br>
  Tocca per passare · doppio tocco per minimizzare · pressione lunga per uscire
  <br>
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest">Scarica</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar">Pagina del prodotto</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar/diary">Diario di sviluppo</a>
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

> **Un'unica app:** DockTouchBar mostra sulle icone lo stato in tempo reale dei tuoi agenti di programmazione IA (disattivabile nelle Impostazioni). Il vecchio «DockTouchBar Vibe» è stato integrato qui. Dettagli e download: [English README](../README.md#what-it-is).

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-444.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20silicon-tested-2e7d32.svg" alt="Apple silicon: tested">
  <img src="https://img.shields.io/badge/Intel-untested-f9a825.svg" alt="Intel: untested">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

![DockTouchBar sulla Touch Bar](../assets/touchbar-idle.gif)
*Stato inattivo: app allineate in basso con punto distintivo attivo in alto a destra (rosso per l'app in primo piano); tazza di caffè in pixel-art con vapore che sale animato.*

![Pressione lunga per uscire: animazione delle quattro stagioni](../assets/touchbar-seasons.gif)
*Pressione lunga per uscire: scene di conto alla rovescia in pixel-art a scorrimento laterale attraverso quattro stagioni (cane che corre in primavera / nave a vela d'estate / volpe nella foresta d'autunno / giro in slitta d'inverno). Rilascia presto per annullare, con esplosione finale stagionale.*

### ⚡ Energia e prestazioni native (misurazioni dalla versione precedente)

Progettato per la residenza in background 24/7 utilizzando aggiornamenti dell'app e della finestra basati su eventi. Le misurazioni sottostanti provengono da versioni precedenti; l'attività di screenshot utilizza temporaneamente un breve controllo del processo:

| Metrica | Misurato | Note |
|---|---|---|
| **Utilizzo CPU** | **0.0% ~ 0.8%** | Inattivo 0.0%; brevi picchi trascurabili solo su eventi di cambio app/finestra |
| **Impronta fisica** | **29 MB** | Misurato con lo strumento `footprint` di macOS, frazione delle alternative Electron |
| **Impatto energetico** | **0.0** | Valutazione energetica macOS Activity Monitor più bassa possibile, impatto zero sulla batteria |
| **Thread residenti** | **4 thread (tutti in sleep su eventi)** | Nessun busy-wait, nessun polling di timer ad alta frequenza |
| **Accesso di rete** | **Controlli di aggiornamento e download di GitHub** | Le interazioni con il Dock vengono eseguite localmente; nessun analytics o account |
| **Latenza di rendering** | **~2.3 ms / frame** | Pipeline di rendering nativa CoreAnimation / AppKit per reattività istantanea al tocco |

**Se DockTouchBar ti è utile, una ⭐ Stella su GitHub è il modo migliore per dire grazie.**

## Perché

Pock, PockV2 e altri possono mettere il Dock sulla Touch Bar, ma fanno molte più cose e nell'uso quotidiano la barra tende a scomparire o smettere di rispondere. DockTouchBar mantiene un'unica mansione e la svolge bene.

**Semplice**

- Un'unica mansione: il tuo Dock sulla Touch Bar. Nessun widget, nessun plugin.
- Una manciata di interruttori nella barra dei menu, nient'altro da configurare.
- Swift e AppKit nativi, senza dipendenze di terze parti. Le scene in pixel-art sono incluse nel codice sorgente.

**Elegante**

- Utilizza le icone di macOS e lo scroller Touch Bar del sistema. Le app in esecuzione non fissate appaiono a sinistra, le più recenti per prime; le app fissate mantengono il loro ordine nel Dock. La chiusura di un'app mantiene l'area attualmente visibile.
- Gesti che non si intromettono: un tocco agisce immediatamente (non aspetta mai per vedere se arriva un doppio tocco), e la pressione lunga mostra una barra di avanzamento silenziosa sotto l'icona, più un conto alla rovescia "Chiusura ..." al bordo destro della Touch Bar in modo che il tuo dito non la nasconda, disegnato come una piccola scena in pixel-art che puoi alternare tra quattro stagioni. Rilascia presto per annullare.
- I tocchi rapidi si sentono giusti: l'ultimo tocco vince sempre, e non ti combatte mai. Se il sistema perde un cambio desktop o qualcosa cattura il focus, lo rimette silenziosamente a posto, e si ferma nel momento in cui tocchi la tastiera, il mouse o il trackpad.
- Parla la tua lingua (12 lingue, dall'inglese a 简体中文 e 日本語) e chiede solo un permesso opzionale.

**Efficiente**

- Aggiornamenti dell'app e della finestra basati su eventi. Misurazioni precedenti su un MacBook Pro M1 con il Dock visibile e inattivo: **0.0% CPU**, **0 idle wakeup**, circa **32 MB** di memoria.\*
- Si adatta al tuo Mac invece di utilizzare ritardi fissi: i cambi desktop attendono il segnale "finito" del sistema stesso e controllano il risultato, quindi rimane corretto che le animazioni siano lente, disattivate o la macchina sia occupata.
- Quando le app si avviano o escono, solo ciò che è cambiato viene aggiornato e la tua posizione di scorrimento viene conservata. Le icone vengono rasterizzate una volta e memorizzate in cache.
- Autoguarente: si riconnette dopo il sonno, lo sblocco dello schermo e i riavvii della Control Strip, quindi non devi mai riavviarla.
- Fallisce in modo sicuro: le API private vengono risolte in fase di esecuzione. Se macOS ne rimuove una, quella funzione si disattiva da sola invece di causare un crash.
- Privacy: nessun analytics o account. Le interazioni con il Dock vengono eseguite localmente; i controlli di aggiornamento automatici e i download richiesti si connettono a GitHub. Le preferenze rimangono sul tuo Mac.

<sub>\* Rilascio di produzione. CPU da cinque campioni `top` a 2 s di distanza (tutti 0.0%); wakeup dal contatori per processo del kernel letto a 20 s di distanza, tre volte sulla versione 1.10 (0 idle wakeup e 0 interrupt wakeup ogni volta; un'esecuzione precedente sulla versione 1.8 ha visto 0–7 interrupt wakeup, da eventi di sistema); memoria è l'impronta fisica da `footprint` (32 MB). Il vapore sopra la tazza di caffè è disegnato dal processo di rendering del sistema, non dall'app.</sub>

## Caratteristiche

| Gesto | Cosa succede |
|---|---|
| **Tocca** un'icona | Passa all'app, o avviala. Se le sue finestre sono su un altro desktop (Space), salta a quel desktop |
| **Doppio tocco** | Minimizza la finestra corrente, come il suo pulsante giallo. Richiede il permesso Accessibilità. Tocca di nuovo per ripristinare |
| **Pressione lunga** | Chiudi l'app e dicci sempre cosa è successo. Una barra di avanzamento si riempie sotto l'icona mentre tieni premuto, e un conto alla rovescia "Chiusura ..." appare al bordo destro su una stagione in pixel-art (la tua scelta nel menu); rilascia presto e conta come un tocco. L'app viene sempre chiusa interamente (stesso come ⌘Q), indipendentemente dal numero di finestre o se sono minimizzate o nascoste. Finder non può essere chiusa, quindi tutte le sue finestre vengono chiuse invece (anche quelle minimizzate; se sono su un altro desktop vi salta prima). Se l'app non riesce a chiudersi perché ti sta aspettando (un foglio "modifiche non salvate") o non si chiude, la Touch Bar passa ad essa, attraverso i desktop, e lo dice |
| **Cestino** | Tocca per aprire la finestra del Cestino in Finder; doppio tocco per minimizzarla; pressione lunga per chiuderla. Si oscura mentre la finestra è chiusa (e scompare in modalità "mostra solo app in esecuzione") |
| **Scorri** | Scorri quando le icone non entrano tutte; chiudere un'app mantiene l'area corrente in vista |
| **Tazza di caffè** (estremità destra, con vapore animato) | Fai una pausa: nascondi il Dock per un momento e restituisci la Touch Bar al sistema (luminosità, volume). Ritorna da solo dopo 10–60 s |
| **Pulsante centra / massimizza** (estrema destra) | Centra la finestra dell'app in primo piano; tocca di nuovo per massimizzarla (riempie l'area utilizzabile, non a schermo intero nativo), e di nuovo per centrarla. Se hai spostato la finestra da solo o cambiato app, centra prima, e l'icona segue lo stato corrente della finestra. Richiede il permesso Accessibilità |

Il menu della barra dei menu mantiene gli interruttori di uso quotidiano: Mostra il Dock sulla Touch Bar, Mostra solo le app in esecuzione (disattivato per impostazione predefinita: le app fissate vengono mostrate anche; le app che sarebbero attenuate, incluso Finder senza finestre e un Cestino chiuso, vengono nascoste e Finder siede all'estrema sinistra), Centra le icone (quando entrano; una volta superate iniziano da sinistra e scorrono), Mostra il pulsante centra/massimizza e Avvia al login. **Impostazioni…** apre la finestra delle impostazioni, che ha tre pagine:

- **Impostazioni** — spaziatura icone; nascondi tempo per un momento dopo aver toccato la tazza di caffè (10 / 20 / 30 / 60 s); la dimensione della finestra centrata (60–100% dell'altezza dello schermo; larghezza uguale all'altezza, o 50–100% della larghezza dello schermo); doppio tocco per minimizzare; pressione lunga per chiudere (Disattivo / 1 / 2 / 3 / 5 s) e il suo stile (Primavera / Estate / Autunno / Inverno, con un'anteprima breve sulla Touch Bar); cedere ai controlli Touch Bar del sistema (interruttori screenshot / registrazione e Fn indipendenti, attivi per impostazione predefinita); lingua (Segui il Sistema, o una delle 12 lingue — mostrate in cima alla pagina Impostazioni; traduce anche i messaggi di pressione lunga della Touch Bar); stato del permesso Accessibilità con un collegamento alle Impostazioni di Sistema (nient'altro necessita di un permesso); e la diagnosi "perché non riesco a vedere il Dock?"
- **Come usare** — gesti e pulsanti
- **Informazioni** — versione, controllo aggiornamenti, pagina del prodotto e collegamenti del diario di sviluppo, pulsante Stella

L'app ha un'icona anche nel Dock, quindi puoi avviarla da lì dopo l'installazione.

Aprire di nuovo l'app da Applicazioni mentre è in esecuzione fa apparire il menu.

## Requisiti e ambiente testato

| | |
|---|---|
| Hardware | Un Mac con Touch Bar (MacBook Pro 2016–2022) |
| **Testato su** | **MacBook Pro 13" (M1, `MacBookPro17,1`), macOS 27.0, display singolo, 3 Space, Touch Bar impostata su "Expanded Control Strip", Stage Manager attivo** |
| Apple silicon (M1) | ✅ Questo è il computer su cui viene sviluppato e utilizzato |
| Intel | ⚠️ **Sconosciuto.** Il download è un binario universale e lo slice Intel si avvia su Rosetta su un Mac M1, ma non ha mai girato su un vero Mac Intel con Touch Bar. I rapporti sono benvenuti |
| Versione di macOS | Costruito con macOS 13 come minimo, ma testato solo su macOS 27.0. Le versioni precedenti non sono testate |

Cose da sapere:

- Utilizza **API private di Apple** per mantenere una Touch Bar sullo schermo da un'app in background. È anche per questo che non può essere nel Mac App Store, e per questo un futuro aggiornamento di macOS potrebbe romperlo. Le interfacce private vengono risolte in fase di esecuzione, quindi se una scompare quella funzione si disattiva invece di causare un crash; `swift tools/probe-private-api.swift` mostra quali il tuo macOS ha ancora.
- Il Dock prende l'**intera** Touch Bar, quindi la Control Strip del sistema (luminosità, volume) è nascosta mentre è attiva. Tocca la piccola tazza di caffè a destra della barra per nascondere il Dock per un momento e restituire la Touch Bar al sistema (ritorna da solo dopo 10–60 secondi, 20 per impostazione predefinita — o, se lo schermo è stato completamente spento, non appena la luminosità viene aumentata). Puoi anche deselezionare "Mostra il Dock sulla Touch Bar" nel menu.
- Ordine da sinistra a destra: app in esecuzione non fissate (le più recenti per prime) → divisore → Finder → app fissate in ordine Dock → divisore → Cestino. Le app non fissate appena avviate entrano in vista a sinistra; il passaggio tra app aperte non le riordina. Tocca il Cestino per aprirlo in Finder.
- Con Stage Manager attivo, macOS anima il cambio della finestra, quindi la finestra può impiegare circa mezzo secondo per apparire sullo schermo. L'app toccata diventa l'app in primo piano in circa 40 ms; il resto è l'animazione del sistema.

## Installa

1. Scarica `DockTouchBar-<versione>.dmg` da [Versioni](https://github.com/hooosberg/DockTouchBar/releases/latest).
2. Aprilo e trascina **DockTouchBar** su **Applicazioni**, quindi avvialo. Un'icona Dock appare nella barra dei menu e sulla Touch Bar.

> Il DMG è firmato con un certificato Developer ID ed è **notarizzato da Apple**, quindi si apre come qualsiasi altra app. macOS ti chiederà solo di confermare il primo avvio. Preferisci compilarlo da te? Vedi [Compila dal codice sorgente](#compila-dal-codice-sorgente).

### Permesso Accessibilità (opzionale)

L'Accessibilità consente il cambio di finestre tra desktop, la minimizzazione con doppio tocco, il centraggio / massimizzazione, la chiusura delle finestre di Finder, il rilevamento di dialoghi di conferma e la cessione di Fn. Senza di esso, l'avvio e l'attivazione di base rimangono disponibili; questi funzioni sono limitate.

1. Icona della barra dei menu → **Impostazioni…** → **Permessi** → **Attiva…** (una volta concesso legge **Accessibilità: attiva**)
2. In Impostazioni di Sistema → Privacy e sicurezza → Accessibilità, attiva DockTouchBar.

Se continua a chiedere dopo aver lo acceso, la vecchia voce è stantia (questo accade quando la firma dell'app è cambiata): seleziona DockTouchBar nell'elenco, fai clic su **−**, quindi aggiungilo di nuovo. Oppure esegui `tccutil reset Accessibility com.maohuhu.docktouchbar` e ripeti il passo 1.

### Se un tocco non cambia desktop

Subito dopo che accade, esegui questo da un clone del repository. È di sola lettura e stampa come l'app ha giudicato le finestre di quell'app (quali finestre esistono, quale desktop ognuna è, quali sono finestre reali, quale alzerebbe):

```bash
tools/diagnose-switch.sh com.google.Chrome
```

## Non riesco a vedere il Dock?

Causa più comune: Impostazioni di Sistema → Tastiera → "Touch Bar Mostra" è impostata su "Tasti F1, F2, ecc.", che riempie l'intera Touch Bar con i tasti funzione. Dalla versione 1.16 l'app rileva questo e si offre di passare a "Expanded Control Strip" al primo avvio. Puoi anche fare clic su "Diagnosi: perché non riesco a vedere il Dock?" nel menu della barra dei menu per verificare ogni causa possibile e copiare un rapporto per il feedback. Tenere premuto Fn mostra comunque F1–F12 dopo.

## Compila dal codice sorgente

Richiede gli strumenti della riga di comando di Xcode.

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # build → copia in /Applications → avvia
scripts/make-dmg.sh     # build/DockTouchBar-<versione>.dmg
```

Senza un certificato di firma la build ritorna alla firma ad-hoc. Questo funziona, ma macOS tratta ogni rebuild ad-hoc come una nuova app, quindi devi ri-concedere l'Accessibilità ogni volta. Imposta `SIGN_IDENTITY="Apple Development: …"` (o un certificato Developer ID) per mantenere un'identità stabile.

## Layout del progetto

```
Sources/DockTouchBar/   Codice sorgente dell'app
Resources/              Info.plist, icona dell'app
scripts/                build.sh, install.sh, make-dmg.sh, make-icon.sh
tools/                  Diagnostica: controllo API privata, ispettore Space/finestre, diagnostica di cambio, test di clic rapido, anteprima offscreen e render-seasons.sh (screenshot README)
assets/                 Immagini README
```

Dopo un grande aggiornamento di macOS, esegui `swift tools/probe-private-api.swift` per vedere quali API private sono ancora disponibili.

## Licenza

[PolyForm Noncommercial License 1.0.0](../LICENSE) — gratuito per uso personale e altri scopi non commerciali. **L'uso commerciale non è coperto** e richiede una licenza separata dall'autore; per favore contatta tramite [hooosberg.com](https://hooosberg.com/).

Questa è una licenza source-available, non una licenza open source approvata dall'OSI. Avviso richiesto: Copyright © 2026 hooosberg.

## Autore

Realizzato da **hooosberg** — [hooosberg.com](https://hooosberg.com/) · [GitHub](https://github.com/hooosberg). Se questo ti ha risparmiato alcuni tocchi, per favore ⭐ il repository.
