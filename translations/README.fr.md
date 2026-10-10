<p align="center">
  <img src="../assets/icon-256.png" alt="DockTouchBar" width="128" height="128">
</p>

<h1 align="center">DockTouchBar</h1>

<p align="center">
  <strong>Votre Dock sur la Touch Bar.</strong>
  <br>
  <strong>Simple · Élégant · Efficace</strong>
  <br>
  Appuyer pour basculer · double-appui pour réduire · appui long pour quitter
  <br>
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest">Télécharger</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar">Page produit</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar/diary">Journal de développement</a>
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

> **Une seule app :** DockTouchBar affiche en direct l'état de vos agents de codage IA sur les icônes (désactivable dans les réglages). L'ancien « DockTouchBar Vibe » y est désormais intégré. Détails et téléchargement : [English README](../README.md#what-it-is).

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-444.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20silicon-tested-2e7d32.svg" alt="Apple silicon: tested">
  <img src="https://img.shields.io/badge/Intel-untested-f9a825.svg" alt="Intel: untested">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

![DockTouchBar sur la Touch Bar](../assets/touchbar-idle.gif)
*État inactif : apps alignées en bas avec un point badge actif en haut à droite (rouge pour l'app au premier plan) ; tasse de café en pixel-art avec vapeur animée.*

![Appui long pour quitter : animation des quatre saisons](../assets/touchbar-seasons.gif)
*Appui long pour quitter : scènes de compte à rebours en pixel-art défilantes sur quatre saisons (chien qui court au printemps / bateau à voile en été / renard en forêt en automne / traîneau en hiver). Relâchez tôt pour annuler, avec un grand final saisonnier.*

### ⚡ Énergie et performances natives (mesures des versions antérieures)

Conçu pour une résidence de fond 24/7 en utilisant les mises à jour d'app et de fenêtres pilotées par des événements. Les mesures ci-dessous proviennent des versions antérieures ; l'activité de capture d'écran utilise temporairement une vérification rapide de processus :

| Métrique | Mesurée | Notes |
|---|---|---|
| **Utilisation CPU** | **0,0 % ~ 0,8 %** | Inactif 0,0 % ; brefs pics négligeables uniquement lors des événements de changement d'app/fenêtre |
| **Empreinte physique** | **29 Mo** | Mesurée avec l'outil `footprint` de macOS, fraction des alternatives Electron |
| **Impact énergétique** | **0,0** | Notation d'impact énergétique macOS la plus basse possible, zéro impact sur la batterie |
| **Threads résidents** | **4 threads (tous en attente d'événements)** | Zéro attente active, aucun sondage avec minuterie haute fréquence |
| **Accès réseau** | **Vérifications de mises à jour GitHub et téléchargements** | Les interactions Dock s'exécutent localement ; aucune analytique ni comptes |
| **Latence de rendu** | **~2,3 ms / image** | Pipeline de rendu natif CoreAnimation / AppKit pour une réactivité tactile instantanée |

**Si DockTouchBar vous est utile, une ⭐ Star sur GitHub est le meilleur moyen de dire merci.**

## Pourquoi

Pock, PockV2 et autres peuvent mettre le Dock sur la Touch Bar, mais ils font bien plus, et en utilisation quotidienne la barre tend à disparaître ou à ne pas réagir. DockTouchBar remplit une tâche et la fait bien.

**Simple**

- Une tâche : votre Dock sur la Touch Bar. Aucun widget, aucun plugin.
- Une poignée de commutateurs dans la barre de menu, rien d'autre à configurer.
- Swift natif et AppKit, sans dépendances tierces. Les scènes en pixel-art sont incluses dans le source.

**Élégant**

- Utilise les icônes macOS et le scroller Touch Bar du système. Les apps en exécution non épinglées apparaissent à gauche, les plus récentes en premier ; les apps épinglées conservent leur ordre du Dock. Fermer une app conserve la zone visible actuelle.
- Des gestes discrets : un appui fonctionne immédiatement (il n'attend jamais de voir si un double-appui arrive), et un appui long affiche une barre de progression discrète sous l'icône, plus un compte à rebours « Fermeture … » au bord droit de la Touch Bar pour que votre doigt ne le cache jamais, dessiné comme une petite scène en pixel-art que vous pouvez changer entre quatre saisons. Relâchez tôt pour annuler.
- Les appuis rapides se sentent justes : le dernier appui gagne toujours, et il ne vous combat jamais. Si le système perd un changement de bureau ou quelque chose vole le focus, il remet les choses en place discrètement, et s'arrête dès que vous touchez le clavier, la souris ou le trackpad.
- Parle votre langue (12 langues, de l'anglais au 简体中文 et 日本語) et demande juste une permission optionnelle.

**Efficace**

- Mises à jour d'app et de fenêtres pilotées par des événements. Mesures antérieures sur un MacBook Pro M1 avec le Dock visible et inactif : **0,0 % CPU**, **0 réveils inactifs**, environ **32 Mo** de mémoire.\*
- S'adapte à votre Mac au lieu d'utiliser des délais fixes : les changements de bureau attendent le signal « terminé » du système lui-même et vérifient le résultat, donc il reste correct que les animations soient lentes, désactivées ou que la machine soit occupée.
- Quand les apps démarrent ou se ferment, seul ce qui a changé est mis à jour et votre position de défilement est conservée. Les icônes sont rastérisées une fois et mises en cache.
- Auto-réparateur : se réattache après la mise en veille, le déverrouillage de l'écran et les redémarrages de la bande de contrôle, donc vous n'avez jamais à le relancer.
- Échoue de manière sûre : les APIs privées sont résolues à l'exécution. Si macOS en supprime une, cette fonctionnalité se désactive d'elle-même au lieu de planter.
- Confidentialité : aucune analytique ni comptes. Les interactions Dock s'exécutent localement ; les vérifications de mise à jour automatiques et les téléchargements demandés se connectent à GitHub. Les préférences restent sur votre Mac.

<sub>\* Version de lancement. CPU à partir de cinq exemples `top` espacés de 2 s (tous 0,0 %) ; réveils à partir des compteurs par processus du noyau lus toutes les 20 s, trois fois sur 1.10 (0 réveils inactifs et 0 réveils d'interruption à chaque fois ; une exécution antérieure sur 1.8 a vu 0–7 réveils d'interruption, à partir d'événements système) ; la mémoire est l'empreinte physique de `footprint` (32 Mo). La vapeur au-dessus de la tasse de café est dessinée par le processus de rendu du système, pas par l'app.</sub>

## Fonctionnalités

| Geste | Ce qui se passe |
|---|---|
| **Appuyer** sur une icône | Basculer vers l'app, ou la lancer. Si ses fenêtres sont sur un autre bureau (Espace), sauter à ce bureau |
| **Double-appui** | Réduire la fenêtre actuelle, comme son bouton jaune. Nécessite la permission Accessibilité. Appuyez à nouveau pour restaurer |
| **Appui long** | Fermer l'app, et toujours vous dire ce qui s'est passé. Une barre de progression se remplit sous l'icône pendant que vous tenez, et un compte à rebours « Fermeture … » apparaît au bord droit sur une saison en pixel-art (votre choix dans le menu) ; relâchez tôt et cela compte comme un appui. L'app est toujours complètement fermée (comme ⌘Q), quel que soit son nombre de fenêtres ou qu'elles soient réduites ou cachées. Finder ne peut pas être fermé, donc toutes ses fenêtres sont fermées à la place (les réduites aussi ; si elles sont sur un autre bureau il y saute d'abord). Si l'app ne peut pas fermer parce qu'elle vous attend (une feuille « modifications non enregistrées ») ou ne ferme pas, la Touch Bar bascule vers elle, entre les bureaux, et le dit |
| **Corbeille** | Appuyer ouvre la fenêtre Corbeille dans Finder ; double-appui la réduit ; appui long la ferme. Elle s'assombrit quand la fenêtre est fermée (et disparaît en mode « afficher uniquement les apps en exécution ») |
| **Glisser** | Faire défiler quand les icônes ne tiennent pas toutes ; fermer une app conserve la zone actuelle en vue |
| **Tasse de café** (bout droit, avec vapeur animée) | Faire une pause : masquer le Dock pour un moment et rendre la Touch Bar au système (luminosité, volume). Elle revient toute seule après 10–60 s |
| **Bouton centrer / agrandir** (extrême droite) | Centrer la fenêtre de l'app au premier plan ; appuyez à nouveau pour l'agrandir (remplit la zone utilisable, pas le vrai plein écran), et à nouveau pour la centrer. Si vous avez déplacé la fenêtre vous-même ou changé d'app, elle se centre d'abord, et l'icône suit l'état actuel de la fenêtre. Nécessite la permission Accessibilité |

Le menu de la barre de menu conserve les commutateurs quotidiens : Afficher Dock sur Touch Bar, Afficher uniquement les apps en exécution (désactivé par défaut : les apps épinglées sont affichées aussi ; les apps qui seraient assombries, y compris Finder sans fenêtres et une Corbeille fermée, sont cachées, et Finder s'assoit à l'extrême gauche), Centrer les icônes (quand elles tiennent ; une fois qu'elles débordent elles commencent par la gauche et défilent), Afficher le bouton centrer / agrandir, et Lancer au démarrage. **Réglages…** ouvre la fenêtre des réglages, qui a trois pages :

- **Réglages** — espacement des icônes ; temps de masquage après appui sur la tasse de café (10 / 20 / 30 / 60 s) ; la taille de la fenêtre centrée (60–100 % de la hauteur de l'écran ; largeur identique à la hauteur, ou 50–100 % de la largeur de l'écran) ; double-appui pour réduire ; appui long pour fermer (Désactivé / 1 / 2 / 3 / 5 s) et son style (Printemps / Été / Automne / Hiver, avec un court aperçu sur la Touch Bar) ; cession aux contrôles Touch Bar du système (commutateurs indépendants de capture d'écran / enregistrement et Fn, activés par défaut) ; langue (Suivre le système, ou une des 12 langues — affichée en haut de la page Réglages ; elle traduit aussi les messages de long-appui de la Touch Bar) ; état de la permission Accessibilité avec un raccourci vers Réglages Système (rien d'autre n'a besoin d'une permission) ; et le diagnostic « pourquoi ne puis-je pas voir le Dock ? »
- **Comment utiliser** — gestes et boutons
- **À propos** — version, vérification de mise à jour, liens vers la page produit et le journal de développement, bouton Star

L'app a aussi une icône dans le Dock, vous pouvez donc la lancer de là après l'installation.

Ouvrir l'app à nouveau à partir d'Applications pendant qu'elle s'exécute fait apparaître le menu.

## Exigences et environnement testé

| | |
|---|---|
| Matériel | Un Mac avec une Touch Bar (MacBook Pro 2016–2022) |
| **Testé sur** | **MacBook Pro 13" (M1, `MacBookPro17,1`), macOS 27.0, affichage unique, 3 Espaces, Touch Bar définie sur « Bande de contrôle étendue », Stage Manager activé** |
| Apple silicon (M1) | ✅ C'est la machine sur laquelle il est développé et utilisé |
| Intel | ⚠️ **Inconnu.** Le téléchargement est un binaire universel et la tranche Intel démarre sous Rosetta sur un Mac M1, mais il n'a jamais tourné sur un vrai Mac Intel avec Touch Bar. Les rapports sont bienvenus |
| Version de macOS | Construit avec macOS 13 minimum, mais testé uniquement sur macOS 27.0. Les versions antérieures ne sont pas testées |

Choses à savoir :

- Il utilise **des APIs privées Apple** pour garder une Touch Bar à l'écran à partir d'une app de fond. C'est aussi pourquoi il ne peut pas être sur le Mac App Store, et pourquoi une future mise à jour de macOS pourrait le casser. Les interfaces privées sont résolues à l'exécution, donc si l'une disparaît cette fonctionnalité se désactive au lieu de planter ; `swift tools/probe-private-api.swift` montre lesquelles votre macOS a toujours.
- Le Dock prend la **totalité** de la Touch Bar, donc la bande de contrôle du système (luminosité, volume) est masquée pendant qu'il est actif. Appuyez sur la petite tasse de café au droit de la barre pour masquer le Dock un moment et rendre la Touch Bar au système (elle revient d'elle-même après 10–60 secondes, 20 par défaut — ou, si l'écran a été complètement éteint, dès que la luminosité est augmentée). Vous pouvez aussi décocher « Afficher Dock sur Touch Bar » dans le menu.
- Ordre de gauche à droite : apps en exécution non épinglées (les plus récentes en premier) → séparateur → Finder → apps épinglées dans l'ordre du Dock → séparateur → Corbeille. Les nouvelles apps non épinglées lancées viennent en vue à gauche ; basculer entre les apps ouvertes ne les réordonne pas. Appuyez sur Corbeille pour l'ouvrir dans Finder.
- Avec Stage Manager activé, macOS anime le changement de fenêtre, donc la fenêtre peut prendre environ une demi-seconde pour apparaître à l'écran. L'app appuyée devient l'app au premier plan en environ 40 ms ; le reste est l'animation du système.

## Installer

1. Téléchargez `DockTouchBar-<version>.dmg` depuis [Releases](https://github.com/hooosberg/DockTouchBar/releases/latest).
2. Ouvrez-le et glissez-déposez **DockTouchBar** sur **Applications**, puis lancez-le. Une icône Dock apparaît dans la barre de menu et sur la Touch Bar.

> Le DMG est signé avec un certificat Developer ID et **notarié par Apple**, donc il s'ouvre comme n'importe quelle autre app. macOS vous demandera juste de confirmer le premier lancement. Préférez compiler vous-même ? Voir [Compiler à partir du source](#compiler-à-partir-du-source).

### Permission Accessibilité (optionnelle)

L'Accessibilité active le changement de fenêtre entre bureaux, la minimisation par double-appui, le centrage / agrandissement, la fermeture des fenêtres Finder, la détection de boîtes de dialogue de confirmation, et la cession Fn. Sans elle, les lancements et activations basiques restent disponibles ; ces fonctionnalités sont limitées.

1. Icône de la barre de menu → **Réglages…** → **Permissions** → **Activer…** (une fois accordée elle lit **Accessibilité : activée**)
2. Dans Réglages Système → Confidentialité et sécurité → Accessibilité, activez DockTouchBar.

Si elle continue de demander après l'avoir activée, l'ancienne entrée est obsolète (cela arrive quand la signature de l'app a changé) : sélectionnez DockTouchBar dans la liste, cliquez sur **−**, puis ajoutez-la à nouveau. Ou exécutez `tccutil reset Accessibility com.maohuhu.docktouchbar` et répétez l'étape 1.

### Si un appui ne bascule pas les bureaux

Tout de suite après que cela se passe, exécutez ceci depuis un clone du dépôt. C'est en lecture seule et affiche comment l'app a jugé les fenêtres de cette app (quelles fenêtres existent, quel bureau chacune est, lesquelles sont des fenêtres réelles, laquelle elle élèverait) :

```bash
tools/diagnose-switch.sh com.google.Chrome
```

## Impossible de voir le Dock ?

Cause la plus courante : Réglages Système → Clavier → « La Touch Bar affiche » est réglée sur « Touches F1, F2, etc. », ce qui remplit toute la Touch Bar avec des touches de fonction. Depuis 1.16, l'app le détecte et propose de le changer en « Bande de contrôle étendue » au premier lancement. Vous pouvez aussi cliquer sur « Diagnostiquer : pourquoi ne puis-je pas voir le Dock ? » dans le menu de la barre de menu pour vérifier chaque cause possible et copier un rapport pour un retour. Tenir Fn affiche toujours F1–F12 après.

## Compiler à partir du source

Nécessite les outils en ligne de commande Xcode.

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # compilation → copie vers /Applications → lancement
scripts/make-dmg.sh     # build/DockTouchBar-<version>.dmg
```

Sans certificat de signature, la compilation revient à une signature ad-hoc. Cela fonctionne, mais macOS traite chaque reconstruction ad-hoc comme une nouvelle app, donc vous devez réattribuer Accessibilité à chaque fois. Réglez `SIGN_IDENTITY="Apple Development: …"` (ou un certificat Developer ID) pour conserver une identité stable.

## Disposition du projet

```
Sources/DockTouchBar/   Source de l'app
Resources/              Info.plist, icône de l'app
scripts/                build.sh, install.sh, make-dmg.sh, make-icon.sh
tools/                  Diagnostics : vérification des APIs privées, inspecteur Espaces/fenêtres, diagnostic de changement, test de clic rapide, aperçu hors écran, et render-seasons.sh (les captures d'écran du README)
assets/                 Images du README
```

Après une grosse mise à jour macOS, exécutez `swift tools/probe-private-api.swift` pour voir quelles APIs privées sont toujours disponibles.

## Licence

[PolyForm Noncommercial License 1.0.0](../LICENSE) — gratuit à utiliser, copier, modifier et partager à des fins **personnelles et autres fins non commerciales**. **L'utilisation commerciale n'est pas couverte** et nécessite une licence distincte de l'auteur ; veuillez entrer en contact via [hooosberg.com](https://hooosberg.com/).

Ceci est une licence source-disponible, pas une licence open source approuvée par l'OSI. Avis obligatoire : Copyright © 2026 hooosberg.

## Auteur

Créé par **hooosberg** — [hooosberg.com](https://hooosberg.com/) · [GitHub](https://github.com/hooosberg). Si cela vous a évité des appuis, veuillez ⭐ le dépôt.
