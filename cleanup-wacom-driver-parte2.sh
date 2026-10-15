#!/bin/bash
# Segunda passada da limpeza do driver Wacom: processo orfao, container e restos de /Library.
set -uo pipefail

USER_HOME="/Users/jota"
BACKUP="/Users/Shared/wacom-driver-backup"
STAMP="$(date +%Y%m%d-%H%M%S)"
TARBALL="$BACKUP/wacom-leftovers2-$STAMP.tar.gz"

PATHS=(
  "/Library/Preferences/Tablet"
  "/Library/DCV Extensions/WacomADCV.json"
  "$USER_HOME/Library/Containers/com.wacom.IOManager"
  "$USER_HOME/Library/Containers/com.wacom.DataStoreMgr"
  "$USER_HOME/Library/Saved Application State/com.wacom.IOManager.savedState"
)

mkdir -p "$BACKUP"
EX=()
for p in "${PATHS[@]}"; do
  [ -e "$p" ] && EX+=("$p")
done

echo "==> Backup de ${#EX[@]} itens"
if [ ${#EX[@]} -gt 0 ]; then
  tar -czf "$TARBALL" "${EX[@]}" 2>/dev/null
  echo "    $(du -h "$TARBALL" 2>/dev/null | cut -f1) em $TARBALL"
fi

echo "==> Encerrando o processo orfao"
pkill -f "Wacom_IOManager" && echo "    Wacom_IOManager encerrado" || echo "    (nao estava rodando)"
pkill -f "com.wacom" 2>/dev/null
sleep 2

echo "==> Removendo restos"
for p in "${PATHS[@]}"; do
  if [ -e "$p" ]; then
    rm -rf "$p" && echo "    removido: $p"
  fi
done

# Containers e preferencias com outros nomes
for p in "$USER_HOME"/Library/Containers/*wacom* "$USER_HOME"/Library/Preferences/com.wacom*.plist; do
  [ -e "$p" ] && rm -rf "$p" && echo "    removido: $p"
done

echo
echo "==> Verificacao final"
echo "-- processos wacom:"
pgrep -fl -i wacom || echo "   (nenhum)"
echo "-- arquivos wacom em /Library:"
find /Library -maxdepth 3 -iname "*wacom*" 2>/dev/null || true
echo "-- arquivos wacom no home:"
find "$USER_HOME/Library" -maxdepth 2 -iname "*wacom*" 2>/dev/null || true
echo
echo "OK."
