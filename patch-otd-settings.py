#!/usr/bin/env python3
"""
Ajusta o settings.json do OpenTabletDriver para a Wacom PTH-651:
  - mapeia para o monitor ultrawide (3440x1440@<1720,720>)
  - corrige a área do tablet para a mesma proporção do display (traço sem esticamento)
  - liga os 8 ExpressKeys
Faz backup do arquivo antes de escrever.
"""
import json
import shutil
import datetime
import pathlib

SETTINGS = pathlib.Path.home() / "Library/Application Support/OpenTabletDriver/settings.json"

# Display: Samsung S34CG50 (3440x1440), centro em <1720, 720>
DISPLAY = {"Width": 3440.0, "Height": 1440.0, "X": 1720.0, "Y": 720.0, "Rotation": 0.0}

# Tablet: 223.52 mm de largura; altura recalculada para a proporção do display
# 223.52 / (3440/1440) = 93.57 mm  ->  faixa central (33% da altura fica de fora)
TABLET = {"Width": 223.52, "Height": 93.57, "X": 111.76, "Y": 46.79, "Rotation": 0.0}

MULTI = "OpenTabletDriver.Desktop.Binding.MultiKeyBinding"
KEY = "OpenTabletDriver.Desktop.Binding.KeyBinding"


def store(path, prop, value):
    return {
        "Path": path,
        "Settings": [{"Property": prop, "Value": value}],
        "Enable": True,
    }


# Ordem física confirmada pelo teste teste-teclas.html:
#   coluna ESQUERDA de cima para baixo = índices 0-3
#   coluna DIREITA  de cima para baixo = índices 4-7
# Remapeável na aba "Auxiliary Settings" do app.
AUX = [
    store(MULTI, "Keys", "Application+Z"),        # 0 - Esq.1 (topo) desfazer
    store(MULTI, "Keys", "Application+Shift+Z"),  # 1 - Esq.2        refazer
    store(KEY, "Key", "LeftBracket"),             # 2 - Esq.3        diminuir pincel
    store(KEY, "Key", "RightBracket"),            # 3 - Esq.4 (base) aumentar pincel
    store(KEY, "Key", "Space"),                   # 4 - Dir.1 (topo) mão/pan (segurar)
    store(KEY, "Key", "Alt"),                     # 5 - Dir.2        conta-gotas (segurar)
    store(KEY, "Key", "Application"),             # 6 - Dir.3        Command (segurar)
    store(KEY, "Key", "Shift"),                   # 7 - Dir.4 (base) Shift (segurar)
]


def main():
    raw = SETTINGS.read_text(encoding="utf-8")
    data = json.loads(raw)

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    backup = SETTINGS.with_name(f"settings.json.bak-{stamp}")
    shutil.copy2(SETTINGS, backup)
    print(f"backup: {backup}")

    for profile in data["Profiles"]:
        if profile["Tablet"] != "Wacom PTH-651":
            print(f"pulando perfil '{profile['Tablet']}'")
            continue

        ams = profile["AbsoluteModeSettings"]
        ams["Display"] = dict(DISPLAY)
        ams["Tablet"] = dict(TABLET)
        ams["LockAspectRatio"] = True
        ams["EnableClipping"] = True
        ams["EnableAreaLimiting"] = False

        profile["Bindings"]["AuxButtons"] = AUX
        profile["Bindings"]["DisablePressure"] = False
        profile["Bindings"]["DisableTilt"] = False

        print(f"perfil '{profile['Tablet']}' atualizado")
        print(f"  display: {ams['Display']}")
        print(f"  tablet:  {ams['Tablet']}")
        print(f"  aux buttons: {len(AUX)} bindings")

    SETTINGS.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(f"escrito: {SETTINGS}")


if __name__ == "__main__":
    main()
