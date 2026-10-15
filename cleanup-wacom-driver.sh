#!/bin/bash
# Remove os restos do driver oficial Wacom (Center 6.4.x) que ficaram neste Mac.
# O app principal ja nao existe mais, mas daemons, prefpanes e framework continuam
# instalados e disputando o tablet com qualquer driver alternativo.
#
# Faz um backup (.tar.gz) de tudo antes de apagar.
# Uso: sudo bash cleanup-wacom-driver.sh   (ou via dialogo de senha do macOS)

set -uo pipefail

# Executado como root via dialogo do macOS, $HOME vira /var/root. Fixa o home real.
USER_HOME="${WACOM_CLEANUP_HOME:-/Users/jota}"

BACKUP="${WACOM_CLEANUP_BACKUP:-/Users/Shared/wacom-driver-backup}"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARBALL="$BACKUP/wacom-leftovers-$STAMP.tar.gz"
UID_NUM="$(stat -f %u /dev/console 2>/dev/null || id -u)"

SYSTEM_PATHS=(
  "/Library/LaunchAgents/com.wacom.DataStoreMgr.plist"
  "/Library/LaunchAgents/com.wacom.IOManager.plist"
  "/Library/LaunchAgents/com.wacom.wacomtablet.plist"
  "/Library/LaunchDaemons/com.wacom.UpdateHelper.plist"
  "/Library/PrivilegedHelperTools/Wacom_IOManager.app"
  "/Library/PrivilegedHelperTools/com.wacom.DataStoreMgr.app"
  "/Library/PrivilegedHelperTools/com.wacom.UpdateHelper.app"
  "/Library/PreferencePanes/WacomTablet.prefpane"
  "/Library/PreferencePanes/WacomCenter.prefpane"
  "/Library/Frameworks/WacomMultiTouch.framework"
  "/Library/Application Support/Tablet"
)

USER_PATHS=(
  "$USER_HOME/Library/Application Scripts/com.wacom.DataStoreMgr"
  "$USER_HOME/Library/Application Scripts/com.wacom.IOManager"
  "$USER_HOME/Library/Application Scripts/com.wacom.TabletDriver"
  "$USER_HOME/Library/Application Scripts/com.wacom.WacomCenter"
  "$USER_HOME/Library/Application Scripts/com.wacom.WacomTabletDriver"
  "$USER_HOME/Library/Application Scripts/com.wacom.WacomTouchDriver"
  "$USER_HOME/Library/Application Scripts/com.wacom.UpgradeHelper"
  "$USER_HOME/Library/Application Scripts/com.wacom.wacomtablet"
  "$USER_HOME/Library/Application Scripts/com.wacom.RemoveWacomTablet"
  "$USER_HOME/Library/Application Scripts/EG27766DY7.com.wacom.WacomTabletDriver"
  "$USER_HOME/Library/Preferences/com.wacom.WacomCenter.plist"
  "$USER_HOME/Library/Preferences/com.wacom.wacomtablet.plist"
  "$USER_HOME/Library/Preferences/com.wacom.DataStoreMgr.plist"
)

echo "==> Parando os servicos da Wacom"
for label in com.wacom.DataStoreMgr com.wacom.IOManager com.wacom.wacomtablet; do
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null && echo "    agente parado: $label"
done
for label in com.wacom.UpdateHelper; do
  launchctl bootout "system/$label" 2>/dev/null && echo "    daemon parado: $label"
done
pkill -f "Wacom_IOManager" 2>/dev/null
pkill -f "com.wacom.DataStoreMgr" 2>/dev/null
pkill -f "wacomtablet" 2>/dev/null
sleep 1

echo "==> Fazendo backup em $TARBALL"
mkdir -p "$BACKUP"
EXISTING=()
for p in "${SYSTEM_PATHS[@]}" "${USER_PATHS[@]}"; do
  [ -e "$p" ] && EXISTING+=("$p")
done
if [ ${#EXISTING[@]} -eq 0 ]; then
  echo "    AVISO: nada encontrado para salvar."
else
  tar -czf "$TARBALL" "${EXISTING[@]}" 2>/dev/null
fi
if [ -s "$TARBALL" ]; then
  echo "    backup: $(du -h "$TARBALL" | cut -f1) (${#EXISTING[@]} itens)"
else
  echo "    AVISO: backup nao foi criado; abortando por seguranca."
  exit 1
fi

echo "==> Removendo arquivos de sistema"
for p in "${SYSTEM_PATHS[@]}"; do
  if [ -e "$p" ] || [ -L "$p" ]; then
    rm -rf "$p" && echo "    removido: $p"
  fi
done

echo "==> Removendo arquivos do usuario"
for p in "${USER_PATHS[@]}"; do
  if [ -e "$p" ] || [ -L "$p" ]; then
    rm -rf "$p" && echo "    removido: $p"
  fi
done

echo "==> Esquecendo os pacotes recebidos da Wacom"
pkgutil --pkgs 2>/dev/null | grep -i wacom | while read -r pkg; do
  pkgutil --forget "$pkg" >/dev/null 2>&1 && echo "    esquecido: $pkg"
done

echo
echo "==> Verificacao final"
echo "-- processos wacom ainda rodando:"
pgrep -fl -i wacom || echo "   (nenhum)"
echo "-- arquivos wacom ainda em /Library:"
find /Library -maxdepth 3 -iname "*wacom*" 2>/dev/null || true
echo
echo "Pronto. Reinicie o Mac (ou faca logout/login) para o macOS limpar o painel de Ajustes."
echo "Backup guardado em: $TARBALL"
