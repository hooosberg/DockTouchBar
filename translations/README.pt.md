<p align="center">
  <img src="../assets/icon-256.png" alt="DockTouchBar" width="128" height="128">
</p>

<h1 align="center">DockTouchBar</h1>

<p align="center">
  <strong>Seu Dock na Touch Bar.</strong>
  <br>
  <strong>Simples · Elegante · Eficiente</strong>
  <br>
  Toque para alternar · toque duplo para minimizar · pressão prolongada para sair
  <br>
  <a href="https://github.com/hooosberg/DockTouchBar/releases/latest">Download</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar">Página do produto</a> ·
  <a href="https://hooosberg.com/apps/docktouchbar/diary">Diário de construção</a>
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

> **Um único app:** o DockTouchBar mostra nos ícones o estado em tempo real dos seus agentes de programação com IA (pode ser desativado nos Ajustes). O antigo «DockTouchBar Vibe» foi integrado aqui. Detalhes e download: [English README](../README.md#what-it-is).

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-444.svg" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Apple%20silicon-tested-2e7d32.svg" alt="Apple silicon: tested">
  <img src="https://img.shields.io/badge/Intel-untested-f9a825.svg" alt="Intel: untested">
  <img src="https://img.shields.io/badge/Swift-AppKit-F05138.svg" alt="Swift + AppKit">
  <img src="https://img.shields.io/badge/license-PolyForm%20Noncommercial-1e88e5.svg" alt="PolyForm Noncommercial">
</p>

![DockTouchBar na Touch Bar](../assets/touchbar-idle.gif)
*Estado ocioso: apps alinhados na parte inferior com ponto de badge ativo no canto superior direito (vermelho para o app em primeiro plano); xícara de café em pixel-art com vapor ao vivo em ascensão.*

![Pressão prolongada para sair: animação das quatro estações](../assets/touchbar-seasons.gif)
*Pressão prolongada para sair: cenas de contagem regressiva em pixel-art de rolagem lateral em quatro estações (cachorro correndo na primavera / navio à vela no verão / raposa na floresta de outono / passeio de trenó no inverno). Solte cedo para cancelar, com explosão final sazonal.*

### ⚡ Desempenho Energético e Nativo (Medições de Versões Anteriores)

Projetado para residência em segundo plano 24/7 usando atualizações de apps e janelas orientadas por eventos. As medições abaixo são de versões anteriores; a atividade de captura de tela usa temporariamente uma breve verificação de processo:

| Métrica | Medido | Notas |
|---|---|---|
| **Uso de CPU** | **0,0% ~ 0,8%** | Inativo 0,0%; picos negligenciáveis breves apenas em eventos de alternância de app/janela |
| **Pegada Física** | **29 MB** | Medido com a ferramenta `footprint` do macOS, fração de alternativas Electron |
| **Impacto Energético** | **0,0** | Classificação de impacto energético mais baixa possível do Monitor de Atividades do macOS, zero impacto na bateria |
| **Threads Residentes** | **4 threads (todos dormindo em eventos)** | Zero espera ocupada, sem polling de temporizador de alta frequência |
| **Acesso de rede** | **Verificações de atualização do GitHub e downloads** | Interações com Dock executadas localmente; sem análises ou contas |
| **Latência de Renderização** | **~2,3 ms / frame** | Pipeline de renderização nativo CoreAnimation / AppKit para responsividade tátil instantânea |

**Se DockTouchBar é útil para você, uma ⭐ Star no GitHub é a melhor forma de dizer obrigado.**

## Por quê

Pock, PockV2 e amigos podem colocar o Dock na Touch Bar, mas fazem muito mais, e no uso diário a barra tende a desaparecer ou parar de responder. DockTouchBar mantém um único trabalho e o faz bem.

**Simples**

- Um trabalho: seu Dock na Touch Bar. Sem widgets, sem plugins.
- Um punhado de interruptores na barra de menus, nada mais para configurar.
- Swift e AppKit nativos, sem dependências de terceiros. As cenas em pixel-art estão incluídas no código-fonte.

**Elegante**

- Usa ícones do macOS e o scroller da Touch Bar do sistema. Apps em execução não fixados aparecem à esquerda, mais recentes primeiro; apps fixados mantêm sua ordem no Dock. Fechar um app mantém a área visível atual.
- Gestos que ficam fora do seu caminho: um toque atua imediatamente (nunca espera para ver se um toque duplo está vindo), e a pressão prolongada mostra uma barra de progresso silenciosa sob o ícone, mais uma contagem regressiva "Fechando …" na borda direita da Touch Bar para que seu dedo nunca a cubra, desenhada como uma pequena cena em pixel-art que você pode alternar entre quatro estações. Solte cedo para cancelar.
- Os toques rápidos se sentem certos: o último toque sempre vence, e nunca briga com você. Se o sistema soltar uma alternância de desktop ou algo roubar o foco, discretamente corrige as coisas, e para no momento em que você toca no teclado, mouse ou trackpad.
- Fala sua língua (12 idiomas, do English ao 简体中文 e 日本語) e pede apenas uma permissão opcional.

**Eficiente**

- Atualizações de apps e janelas orientadas por eventos. Medições anteriores em um MacBook Pro M1 com o Dock mostrando e ocioso: **0,0% CPU**, **0 despertares ociosos**, cerca de **32 MB** de memória.\*
- Adapta-se ao seu Mac em vez de usar atrasos fixos: as alternâncias de desktop aguardam o sinal "concluído" do próprio sistema e verificam o resultado, então permanece correto se as animações forem lentas, desativadas, ou a máquina estiver ocupada.
- Quando apps iniciam ou saem, apenas o que mudou é atualizado e sua posição de rolagem é mantida. Os ícones são rasterizados uma vez e em cache.
- Autocura: se reconecta após dormir, desbloqueio de tela e reinicializações do Control Strip, então você nunca tem que reiniciá-la.
- Falha segura: APIs privadas são resolvidas em tempo de execução. Se macOS remover uma, esse recurso se desativa em vez de fazer crash.
- Privacidade: sem análises ou contas. Interações com Dock executadas localmente; verificações de atualização automática e downloads solicitados se conectam ao GitHub. As preferências ficam no seu Mac.

<sub>\* Compilação de release. CPU de cinco amostras `top` com 2 s de intervalo (todas 0,0%); despertares do contador per-processo do kernel lido com 20 s de intervalo, três vezes em 1.10 (0 despertares ociosos e 0 despertares de interrupção todas as vezes; uma execução anterior em 1.8 viu 0–7 despertares de interrupção, de eventos do sistema); memória é a pegada física de `footprint` (32 MB). O vapor acima da xícara de café é desenhado pelo processo de renderização do sistema, não pelo app.</sub>

## Recursos

| Gesto | O que acontece |
|---|---|
| **Toque** em um ícone | Alterne para o app ou inicie-o. Se suas janelas estão em outra área de trabalho (Space), pule para essa área de trabalho |
| **Toque duplo** | Minimize a janela atual, como seu botão amarelo. Requer permissão de Acessibilidade. Toque novamente para restaurar |
| **Pressão prolongada** | Feche o app e sempre diga o que aconteceu. Uma barra de progresso se preenche sob o ícone enquanto você segura, e uma contagem regressiva "Fechando …" aparece na borda direita sobre uma estação em pixel-art (sua escolha no menu); solte cedo e conta como um toque. O app é sempre fechado completamente (igual a ⌘Q), independentemente de seu número de janelas ou se são minimizadas ou ocultas. Finder não pode ser fechado, então todas as suas janelas são fechadas em vez disso (minimizadas também; se estiverem em outra área de trabalho pula para lá primeiro). Se o app não pode fechar porque está esperando por você (uma planilha de "mudanças não salvas") ou não fecha, a Touch Bar alterna para ele, entre áreas de trabalho, e diz assim |
| **Lixeira** | Toque abre a janela da Lixeira no Finder; toque duplo a minimiza; pressão prolongada a fecha. Ela fica opaca enquanto a janela está fechada (e desaparece no modo "mostrar apenas apps em execução") |
| **Passar o dedo** | Role quando os ícones não cabem todos; fechar um app mantém a área atual em vista |
| **Xícara de café** (extremidade direita, com vapor animado) | Tire um tempo: oculte o Dock por um momento e devolva a Touch Bar ao sistema (brilho, volume). Ela retorna sozinha após 10–60 s |
| **Botão de centrar / maximizar** (extremidade direita) | Centralize a janela do app em primeiro plano; toque novamente para maximizá-la (preenche a área utilizável, não modo tela inteira nativa), e novamente para centralizá-la. Se você moveu a janela sozinho ou alternada apps, centra primeiro, e o ícone segue o estado atual da janela. Requer permissão de Acessibilidade |

O menu da barra de menus mantém os interruptores do dia a dia: Mostrar Dock na Touch Bar, Mostrar apenas apps em execução (desativado por padrão: apps fixados também são mostrados; apps que seriam apagados, incluindo Finder sem janelas e uma Lixeira fechada, estão ocultos, e Finder fica na extremidade esquerda), Centralizar os ícones (quando cabem; uma vez que transbordam começam pela esquerda e rolam), Mostrar o botão de centrar/maximizar e Iniciar no login. **Ajustes…** abre a janela de ajustes, que tem três páginas:

- **Ajustes** — espaçamento de ícones; tempo de ocultação por um momento após tocar na xícara de café (10 / 20 / 30 / 60 s); o tamanho da janela centralizada (60–100% da altura da tela; largura igual à altura, ou 50–100% da largura da tela); toque duplo para minimizar; pressão prolongada para fechar (Desativado / 1 / 2 / 3 / 5 s) e seu estilo (Primavera / Verão / Outono / Inverno, com uma breve prévia na Touch Bar); cedência aos controles da Touch Bar do sistema (interruptores independentes de screenshot / gravação e Fn, ativados por padrão); idioma (Seguir o Sistema, ou um dos 12 idiomas — mostrado no topo da página de Ajustes; também traduz as mensagens de pressão prolongada da Touch Bar); status de permissão de Acessibilidade com um atalho para Ajustes do Sistema (nada mais precisa de uma permissão); e o diagnóstico "por que não consigo ver o Dock?"
- **Como usar** — gestos e botões
- **Sobre** — versão, verificação de atualização, links da página do produto e diário de construção, botão Star

O app tem um ícone no Dock também, então você pode iniciá-lo de lá após instalar.

Abrindo o app novamente de Aplicativos enquanto está em execução abre o menu.

## Requisitos e ambiente testado

| | |
|---|---|
| Hardware | Um Mac com uma Touch Bar (MacBook Pro 2016–2022) |
| **Testado em** | **MacBook Pro 13" (M1, `MacBookPro17,1`), macOS 27.0, display único, 3 Spaces, Touch Bar definida como "Expanded Control Strip", Stage Manager ativado** |
| Apple silicon (M1) | ✅ Esta é a máquina em que é desenvolvido e usado |
| Intel | ⚠️ **Desconhecido.** O download é um binário universal e o slice Intel começa em Rosetta em um Mac M1, mas nunca foi executado em um Mac Touch Bar Intel real. Relatórios bem-vindos |
| Versão macOS | Construído com mínimo macOS 13, mas apenas testado em macOS 27.0. Versões mais antigas não são testadas |

Coisas a saber:

- Usa **APIs privadas da Apple** para manter uma Touch Bar na tela de um app em segundo plano. Isso também é o motivo pelo qual não pode estar na Mac App Store, e por que uma futura atualização do macOS pode interrompê-lo. As interfaces privadas são resolvidas em tempo de execução, então se uma desaparecer, esse recurso se desativa em vez de fazer crash; `swift tools/probe-private-api.swift` mostra quais ainda seu macOS tem.
- O Dock ocupa a **inteira** Touch Bar, então o Control Strip do sistema (brilho, volume) fica oculto enquanto está ligado. Toque na pequena xícara de café à direita da barra para ocultar o Dock por um momento e devolver a Touch Bar ao sistema (ela retorna sozinha após 10–60 segundos, 20 por padrão — ou, se a tela foi completamente desligada, assim que o brilho é aumentado). Você também pode desmarcar "Mostrar Dock na Touch Bar" no menu.
- Ordem da esquerda para a direita: apps em execução não fixados (mais recentes primeiro) → divisor → Finder → apps fixados em ordem do Dock → divisor → Lixeira. Apps não fixados recém-lançados vêm para a vista à esquerda; alternar entre apps abertos não as reordena. Toque na Lixeira para abri-la no Finder.
- Com Stage Manager ativado, o macOS anima a mudança de janela, então a janela pode levar cerca de meio segundo para aparecer na tela. O app tocado fica em primeiro plano em cerca de 40 ms; o resto é a animação do sistema.

## Instalar

1. Baixe `DockTouchBar-<version>.dmg` em [Releases](https://github.com/hooosberg/DockTouchBar/releases/latest).
2. Abra-o e arraste **DockTouchBar** para **Aplicativos**, depois inicie-o. Um ícone do Dock aparece na barra de menus e na Touch Bar.

> O DMG é assinado com um certificado Developer ID e **verificado pela Apple**, então se abre como qualquer outro app. macOS apenas pedirá que você confirme o primeiro lançamento. Prefere compilar você mesmo? Veja [Compilar a partir da fonte](#compilar-a-partir-da-fonte).

### Permissão de Acessibilidade (opcional)

Acessibilidade ativa a alternância de janelas entre desktops, minimização com toque duplo, centrar/maximizar, fechar janelas do Finder, detectar diálogos de confirmação e cedência de Fn. Sem ela, o lançamento e ativação básicos permanecem disponíveis; esses recursos são limitados.

1. Ícone da barra de menus → **Ajustes…** → **Permissões** → **Ativar…** (uma vez concedido lê **Acessibilidade: ativada**)
2. Em Ajustes do Sistema → Privacidade e Segurança → Acessibilidade, ative DockTouchBar.

Se ainda pedir depois que você ativar, a entrada antiga está obsoleta (isso acontece quando a assinatura do app mudou): selecione DockTouchBar na lista, clique **−**, depois adicione novamente. Ou execute `tccutil reset Accessibility com.maohuhu.docktouchbar` e repita a etapa 1.

### Se um toque não alterna áreas de trabalho

Logo após acontecer, execute isto de um clone do repo. É somente leitura e imprime como o app julgou as janelas daquele app (quais janelas existem, qual área de trabalho cada uma está, quais são janelas reais, qual ele elevaria):

```bash
tools/diagnose-switch.sh com.google.Chrome
```

## Não consegue ver o Dock?

Causa mais comum: Ajustes do Sistema → Teclado → "Touch Bar Mostra" é definida como "Teclas F1, F2, etc.", que preenche toda a Touch Bar com teclas de função. Desde 1.16 o app detecta isso e oferece alterar para "Expanded Control Strip" no primeiro lançamento. Você também pode clicar em "Diagnosticar: por que não consigo ver o Dock?" no menu da barra de menus para verificar cada possível causa e copiar um relatório para feedback. Segurando Fn ainda mostra F1–F12 depois.

## Compilar a partir da fonte

Requer as ferramentas de linha de comando do Xcode.

```bash
git clone https://github.com/hooosberg/DockTouchBar.git
cd DockTouchBar
scripts/install.sh      # compilar → copiar para /Applications → iniciar
scripts/make-dmg.sh     # build/DockTouchBar-<version>.dmg
```

Sem um certificado de assinatura a compilação volta para assinatura ad-hoc. Isso funciona, mas o macOS trata cada recompilação ad-hoc como um novo app, então você tem que reativar Acessibilidade cada vez. Defina `SIGN_IDENTITY="Apple Development: …"` (ou um certificado Developer ID) para manter uma identidade estável.

## Layout do projeto

```
Sources/DockTouchBar/   Código-fonte do app
Resources/              Info.plist, ícone do app
scripts/                build.sh, install.sh, make-dmg.sh, make-icon.sh
tools/                  Diagnósticos: verificação de API privada, inspetor de Spaces/janelas, diagnóstico de alternância, teste de clique rápido, prévia fora da tela, e render-seasons.sh (capturas de tela do README)
assets/                 Imagens do README
```

Após uma grande atualização do macOS, execute `swift tools/probe-private-api.swift` para ver quais APIs privadas ainda estão disponíveis.

## Licença

[PolyForm Noncommercial License 1.0.0](../LICENSE) — gratuito para usar, copiar, modificar e compartilhar para **fins pessoais e outros não comerciais**. **Uso comercial não está coberto** e precisa de uma licença separada do autor; por favor, entre em contato via [hooosberg.com](https://hooosberg.com/).

Esta é uma licença de código aberto, não uma licença de código aberto aprovada pela OSI. Aviso obrigatório: Copyright © 2026 hooosberg.

## Autor

Feito por **hooosberg** — [hooosberg.com](https://hooosberg.com/) · [GitHub](https://github.com/hooosberg). Se isso economizou alguns toques, por favor ⭐ o repositório.
