#!/bin/bash
# CounterLoad Installer Test Suite

set -e

# Test modunu aktifleştirerek etkileşimli pencereleri engelleyelim
export IN_TEST=1

# Betik nereden çağrılırsa çağrılsın kendi projesinin kök dizinine geçsin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Renkler
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "=================================================="
echo "CounterLoad Kurulum Test Senaryoları Başlatılıyor"
echo "=================================================="

# Parametre kontrolü ve en son üretilen versiyonlu yükleyiciyi seçme mantığı
VERSION=""
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
    esac
    shift
done

if [ -n "$VERSION" ]; then
    INSTALLER="./artifacts/linux/CounterLoadSetup-$VERSION.run"
else
    # Eğer parametre geçilmediyse en güncel .run dosyasını otomatik bul
    INSTALLER=$(ls -t ./artifacts/linux/CounterLoadSetup-*.run 2>/dev/null | head -n 1)
fi

if [ -z "$INSTALLER" ] || [ ! -f "$INSTALLER" ]; then
    echo -e "${RED}Hata: Kurulum dosyası bulunamadı! Lütfen önce derleyin: ./installer/scripts/build-installer.sh --version <sürüm> --build-linux${NC}"
    exit 1
fi

echo -e "Test edilecek yükleyici dosyası: ${GREEN}$INSTALLER${NC}"

# Test Dizinleri
USER_TEST_DIR="$(pwd)/test_install_user"
ROOT_TEST_DIR="/opt/CounterLoadTest"

# Temizlik fonksiyonu
cleanup() {
    echo "Temizlik yapılıyor..."
    rm -rf "$USER_TEST_DIR" "${USER_TEST_DIR}_gui"
}
trap cleanup EXIT

# 1. DISPLAY olmadan, Sessiz ve Root Olmadan Kullanıcı Dizinine Kurulum
echo -e "\n--------------------------------------------------"
echo "1. Test: DISPLAY olmadan, Sessiz, Root Olmadan Kullanıcı Dizinine Kurulum"
echo "--------------------------------------------------"
cleanup

# DISPLAY değişkenini boşaltarak headless mod simüle ediyoruz
# Çıktıları log dosyasına kaydediyoruz
set +e
env -u DISPLAY -u WAYLAND_DISPLAY "$INSTALLER" --root "$USER_TEST_DIR" install --accept-licenses --confirm-command > test_install_user.log 2>&1
EXIT_CODE=$?
set -e

# Exit Code Kontrolü
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}[BAŞARILI] Kurulum 0 exit code ile tamamlandı.${NC}"
else
    echo -e "${RED}[HATA] Kurulum başarısız oldu! Exit Code: $EXIT_CODE${NC}"
    cat test_install_user.log
    exit 1
fi

# Kurulum Dosyaları Kontrolü
if [ -f "$USER_TEST_DIR/counterload" ] && [ -x "$USER_TEST_DIR/maintenancetool" ]; then
    echo -e "${GREEN}[BAŞARILI] Ana dosyalar hedef dizinde mevcut.${NC}"
else
    echo -e "${RED}[HATA] Kurulum dosyaları eksik!${NC}"
    exit 1
fi

# Log Dosyası Kontrolü
if [ -f "$USER_TEST_DIR/InstallationLog.txt" ]; then
    echo -e "${GREEN}[BAŞARILI] InstallationLog.txt başarıyla oluşturuldu.${NC}"
else
    echo -e "${RED}[HATA] InstallationLog.txt bulunamadı!${NC}"
    exit 1
fi


# 2. Sessiz Kaldırma (Uninstall) Testi
echo -e "\n--------------------------------------------------"
echo "2. Test: Sessiz Kaldırma (Uninstaller Purge)"
echo "--------------------------------------------------"
set +e
env -u DISPLAY -u WAYLAND_DISPLAY "$USER_TEST_DIR/maintenancetool" purge --confirm-command > test_uninstall_user.log 2>&1
EXIT_CODE=$?
set -e

# Exit Code Kontrolü
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}[BAŞARILI] Kaldırma işlemi 0 exit code ile tamamlandı.${NC}"
else
    echo -e "${RED}[HATA] Kaldırma işlemi başarısız! Exit Code: $EXIT_CODE${NC}"
    cat test_uninstall_user.log
    exit 1
fi

# Kaldırma Sonrası Kontrol
if [ ! -d "$USER_TEST_DIR" ] || [ -z "$(ls -A "$USER_TEST_DIR" 2>/dev/null)" ]; then
    echo -e "${GREEN}[BAŞARILI] Dizin temizlendi.${NC}"
else
    echo -e "${RED}[HATA] Dizin tam olarak temizlenemedi!${NC}"
    exit 1
fi


# 3. Root Yetkisi ile /opt Altına Kurulum Testi (Manuel Onay / Sudo Gerektirir)
echo -e "\n--------------------------------------------------"
echo "3. Test: Root Yetkisi ile /opt Altına Kurulum (Sudo gerektirir)"
echo "--------------------------------------------------"
echo "Bu test sudo yetkisi isteyecektir. Devam etmek için şifrenizi girin veya testi atlamak için Ctrl+C yapın."

set +e
sudo env -u DISPLAY -u WAYLAND_DISPLAY "$INSTALLER" --root "$ROOT_TEST_DIR" install --accept-licenses --confirm-command
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}[BAŞARILI] Root /opt kurulumu 0 exit code ile tamamlandı.${NC}"
else
    echo -e "${RED}[HATA] Root kurulumu başarısız! Exit Code: $EXIT_CODE${NC}"
    exit 1
fi

# Root Kurulum Dosyaları Kontrolü
if [ -f "$ROOT_TEST_DIR/counterload" ]; then
    echo -e "${GREEN}[BAŞARILI] /opt altında dosyalar oluşturuldu.${NC}"
else
    echo -e "${RED}[HATA] /opt altında dosyalar bulunamadı!${NC}"
    exit 1
fi

# Root Sessiz Kaldırma
echo -e "\n--------------------------------------------------"
echo "4. Test: Root Kaldırma (Sudo Purge)"
echo "--------------------------------------------------"
set +e
sudo env -u DISPLAY -u WAYLAND_DISPLAY "$ROOT_TEST_DIR/maintenancetool" purge --confirm-command
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}[BAŞARILI] Root kaldırma işlemi 0 exit code ile tamamlandı.${NC}"
else
    echo -e "${RED}[HATA] Root kaldırma işlemi başarısız! Exit Code: $EXIT_CODE${NC}"
    exit 1
fi

if [ ! -d "$ROOT_TEST_DIR" ] || [ -z "$(ls -A "$ROOT_TEST_DIR" 2>/dev/null)" ]; then
    echo -e "${GREEN}[BAŞARILI] /opt altındaki dizin temizlendi.${NC}"
else
    echo -e "${RED}[HATA] /opt dizini tam olarak temizlenemedi!${NC}"
    exit 1
fi


# 5. Linux Masaüstü GUI Otomatik Kurulum Testi (xvfb-run + Controller Script)
echo -e "\n--------------------------------------------------"
echo "5. Test: Linux Masaüstü GUI Otomatik Kurulum (xvfb-run + Controller)"
echo "--------------------------------------------------"
USER_TEST_DIR_GUI="${USER_TEST_DIR}_gui"
rm -rf "$USER_TEST_DIR_GUI"

set +e
xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" "$INSTALLER" --root "$USER_TEST_DIR_GUI" --script "installer/scripts/controller.qs" "TargetDirUserOverride=$USER_TEST_DIR_GUI"
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}[BAŞARILI] GUI Kurulum 0 exit code ile tamamlandı.${NC}"
else
    echo -e "${RED}[HATA] GUI Kurulum başarısız! Exit Code: $EXIT_CODE${NC}"
    exit 1
fi

# Dosyaların doğrulanması
if [ -f "$USER_TEST_DIR_GUI/counterload" ] && [ -x "$USER_TEST_DIR_GUI/maintenancetool" ]; then
    echo -e "${GREEN}[BAŞARILI] GUI kurulum dosyaları oluşturuldu.${NC}"
else
    echo -e "${RED}[HATA] GUI kurulum dosyaları eksik!${NC}"
    exit 1
fi

# Kısayol Kontrolü (GNOME/KDE menü kısayolu)
SHORTCUT_PATH="$HOME/.local/share/applications/CounterLoad.desktop"
if [ -f "$SHORTCUT_PATH" ]; then
    echo -e "${GREEN}[BAŞARILI] Uygulama menüsü kısayolu oluşturuldu: $SHORTCUT_PATH${NC}"
else
    echo -e "${RED}[HATA] Uygulama menüsü kısayolu bulunamadı!${NC}"
    exit 1
fi


# 6. Linux Masaüstü GUI Otomatik Kaldırma Testi (xvfb-run + Controller Script)
echo -e "\n--------------------------------------------------"
echo "6. Test: Linux Masaüstü GUI Otomatik Kaldırma (xvfb-run + Controller)"
echo "--------------------------------------------------"
set +e
xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" "$USER_TEST_DIR_GUI/maintenancetool" --script "installer/scripts/uninstall-controller.qs"
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}[BAŞARILI] GUI kaldırma işlemi 0 exit code ile tamamlandı.${NC}"
else
    echo -e "${RED}[HATA] GUI kaldırma işlemi başarısız! Exit Code: $EXIT_CODE${NC}"
    exit 1
fi

if [ ! -d "$USER_TEST_DIR_GUI" ] || [ -z "$(ls -A "$USER_TEST_DIR_GUI" 2>/dev/null)" ]; then
    echo -e "${GREEN}[BAŞARILI] GUI kurulum dizini başarıyla temizlendi.${NC}"
else
    echo -e "${RED}[HATA] GUI kurulum dizini tam temizlenemedi!${NC}"
    exit 1
fi


echo -e "\n=================================================="
echo -e "${GREEN}TÜM TESTLER BAŞARIYLA TAMAMLANDI!${NC}"
echo "=================================================="
