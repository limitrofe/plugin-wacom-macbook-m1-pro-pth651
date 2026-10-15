# Wacom Intuos Pro (PTH-651) no MacBook M1 — macOS 26.2

Registro do que foi feito para a mesa voltar a funcionar neste Mac, onde o driver
oficial da Wacom não funciona mais.

## Resumo

| Item | Situação |
| --- | --- |
| Mesa | Wacom Intuos Pro Medium — **PTH-651/K** (SN 4JAH002497) |
| USB ID | `056a:0315` (o descritor USB diz "Intuos5 touch M" — a Wacom manteve a string) |
| Mac | MacBook Pro M1 (arm64), macOS 26.2 (build 25C56) |
| Driver usado | **OpenTabletDriver 0.6.7** (build `osx-x64`, roda via Rosetta) |
| Driver oficial | Removido (estava pela metade e quebrado) |

## Por que não usar o `cadenburleson/wacom-driver`

O repo é um driver Swift de espaço de usuário muito bom, mas suporta **apenas a família
Intuos de 2015** (`056a:033b`–`056a:033e` = CTL-490 / CTH-490 / CTL-690 / CTH-690).
A PTH-651 é da família Intuos Pro e usa outro formato de relatório — o próprio README
do projeto diz que outros tablets "will be ignored".

Ele continua sendo uma boa base caso um dia o OpenTabletDriver pare de funcionar:
o `AGENTS.md` do repo tem o passo a passo para escrever um decoder novo.

## Instalação feita

1. **Limpeza do driver Wacom** (o app principal já tinha sido removido, mas sobraram
   daemons, prefpanes e o framework, e o painel de Ajustes mostrava
   "Há um problema com driver da sua mesa digitalizadora"):

   - `~/Documents/wacom-intuos-pro-m1/cleanup-wacom-driver.sh`
   - `~/Documents/wacom-intuos-pro-m1/cleanup-wacom-driver-parte2.sh`
   - Backup completo em `/Users/Shared/wacom-driver-backup/*.tar.gz` (48 MB + 13 MB)

   Removido: 3 LaunchAgents, 1 LaunchDaemon, 3 PrivilegedHelperTools, 2 prefpanes,
   `WacomMultiTouch.framework`, `/Library/Application Support/Tablet`, scripts de usuário,
   `/Library/Preferences/Tablet`, `WacomADCV.json` e o pacote `com.wacom.TabletInstaller`.

   **Ainda restam** containers órfãos em `~/Library/Containers/com.wacom.*` — o macOS
   protege containers (`containermanagerd`) e nem root apaga. São inofensivos.

2. **OpenTabletDriver** instalado em `/Applications/OpenTabletDriver.app`
   (cópia original em `otd/otd.tar.gz`).

   O app **não é assinado** (`code object is not signed at all`). Consequência: a
   permissão de Acessibilidade é vinculada ao **caminho**, então ela quebra se o app
   for movido ou atualizado — nesse caso, remova e adicione de novo em
   Ajustes → Privacidade e Segurança → Acessibilidade.

3. **Autostart pelo LaunchAgent**, não por Item de Login:
   `~/Library/LaunchAgents/net.opentabletdriver.daemon.plist` (cópia do original em
   `net.opentabletdriver.daemon.plist`).

   Motivo: quando a janela do OTD é fechada, o Daemon embutido no app morre junto e a
   mesa para de funcionar. Com `KeepAlive`, o driver sempre volta.

   ```sh
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/net.opentabletdriver.daemon.plist
   launchctl kickstart -k gui/$(id -u)/net.opentabletdriver.daemon   # reiniciar
   launchctl bootout gui/$(id -u)/net.opentabletdriver.daemon        # parar
   ```

   Log: `~/Library/Logs/opentabletdriver.daemon.log`

## Configuração (settings.json)

`~/Library/Application Support/OpenTabletDriver/settings.json`, aplicado por
`patch-otd-settings.py`:

- **Display**: `3440x1440@<1720,720>` — só o monitor ultrawide Samsung S34CG50
- **Tablet**: `223,52 x 93,57 mm @<111,76, 46,79>` — faixa central
- **LockAspectRatio**: `true`
- **8 ExpressKeys** ligadas (ver abaixo)

### Sobre a área do tablet

A mesa tem 223,52 × 139,7 mm (1,6:1). O monitor é 3440 × 1440 (2,39:1). Mapeando a mesa
inteira no monitor, o traço sai **esticado ~1,49x na horizontal**. Reduzindo a altura da
área ativa para `223,52 / (3440/1440) = 93,57 mm`, a escala fica 1:1 e o traço sai
proporcional.

**Custo**: 33% da altura da mesa (23 mm em cima e 23 mm embaixo) não responde.
Se preferir usar a mesa inteira, aumente `Tablet.Height` para `139.7` e `Tablet.Y` para
`69.85` no `settings.json` (ou mexa na aba *Output* do app).

**Atenção**: `LockAspectRatio` no OTD é só um auxiliar da **interface** — o daemon ignora.
Ele serve para manter a proporção enquanto você edita a área na janela; não cria nem
remove zona morta sozinho.

### ExpressKeys (aba *Auxiliary Settings*)

| Índice | Binding | Função |
| --- | --- | --- |
| 0 | `Application+Z` | Desfazer (⌘Z) |
| 1 | `Application+Shift+Z` | Refazer (⌘⇧Z) |
| 2 | `LeftBracket` | Diminuir pincel |
| 3 | `RightBracket` | Aumentar pincel |
| 4 | `Space` | Mão/pan (segurar) |
| 5 | `Alt` | Conta-gotas (segurar) |
| 6 | `Application` | Command (segurar) |
| 7 | `Shift` | Shift (segurar — trava proporção / linha reta) |

No macOS, os nomes de tecla do OTD são: `Application` = ⌘, `Alt` = ⌥, `Control` = ⌃.
Combos usam o tipo **Multi-Key Binding** com a propriedade `Keys` separada por `+`.

**A ordem física das 8 teclas ainda precisa ser confirmada** — o índice 0 pode não ser a
tecla de cima. O jeito de ajustar é na aba *Auxiliary Settings* do app (a GUI funciona
neste macOS).

### O que o OTD **não** suporta nesta mesa

- **Touch ring** (o anel): a especificação da PTH-651 no OTD declara só 8 aux buttons,
  sem wheel. O anel não faz nada.

## Verificação

- Teste de pressão/tilt: `teste-pressao.html` (também copiado em
  `/Users/Shared/teste-pressao.html` para abrir no Chrome sem esbarrar no TCC de
  `~/Documents`).
- Console do OTD (ótimo para diagnosticar):
  ```sh
  cd /Applications/OpenTabletDriver.app/Contents/MacOS
  ./OpenTabletDriver.Console detect
  ./OpenTabletDriver.Console getareas "Wacom PTH-651"
  ./OpenTabletDriver.Console getbindings "Wacom PTH-651"
  ```
  Comandos `set*` alteram só o daemon em memória — para gravar, edite o `settings.json`
  ou use `savedefaultsettings` / `loadsettings <arquivo>`.

## Armadilha do macOS 26 encontrada no caminho

A mesa pode aparecer no `ioreg` mas **sem interfaces HID** (`hidutil` não lista, o OTD
não detecta). É a **segurança de acessórios USB-C**: a porta fica com
`TRM_StateDescription = "Limited"`.

Solução: Ajustes → Privacidade e Segurança → **"Permitir que acessórios se conectem"** →
*Sempre* (ou reconectar e clicar **Permitir** no diálogo). Melhor plugar direto no Mac,
sem hub.

## Créditos e licenças

- **OpenTabletDriver** — https://opentabletdriver.net — licença LGPL-3.0
- **wacom-driver** (referência de estudo) — https://github.com/cadenburleson/wacom-driver — GPL-2.0
- Formatos de relatório derivam do driver do kernel Linux (`drivers/hid/wacom_wac.c`), GPL-2.0
- Wacom e Intuos são marcas da Wacom Co., Ltd. Este projeto não tem vínculo com a Wacom.
