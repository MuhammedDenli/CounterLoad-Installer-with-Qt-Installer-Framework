#!/bin/bash

# Herhangi bir adım hata verirse betiğin çalışmasını hemen durduralım
set -e

# Proje kök dizininde olduğumuzdan emin olalım
if [ ! -d "installer" ] || [ ! -d "artifacts" ]; then
    echo "Hata: Lütfen bu betiği projenin kök dizinden çalıştırın!"
    echo "Örnek: ./installer/scripts/build-installer.sh --platform windows --version 1.2.3"
    exit 1
fi

VERSION=""
PLATFORM=""
CERT_PATH="installer/certs/test_cert.pfx"
CERT_PASS="123456"
ROOT_DIR=$(pwd)

usage() {
    echo "Kullanım: $0 --platform <windows|linux> --version <sürüm>"
    exit 1
}

# Parametrelerin ayrıştırılması
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --platform) PLATFORM="$2"; shift ;;
        --version) VERSION="$2"; shift ;;
        *) echo "Bilinmeyen parametre: $1"; usage ;;
    esac
    shift
done

if [ -z "$PLATFORM" ] || [ -z "$VERSION" ]; then
    echo "Hata: Eksik parametreler!"
    usage
fi

echo "================================================================="
echo "🚀 BÜTÜNLEŞİK DERLEME OTOMASYONU BAŞLATILDI ($PLATFORM - v$VERSION)"
echo "================================================================="

# -------------------------------------------------------------------------
# ADIM 1: Girdi Kontrolleri ve Paketleme Alanının Hazırlanması (Adım 2.2)
# -------------------------------------------------------------------------
echo "👉 [1/4] Girdi dosyaları doğrulanıyor ve staging alanına taşınıyor..."
./installer/scripts/prepare-package.sh --version "$VERSION" --platform "$PLATFORM" --input "staging/$PLATFORM"

# -------------------------------------------------------------------------
# ADIM 2: Paketleme Öncesi Ham Bileşenlerin İmzalanması (Adım 2.3)
# -------------------------------------------------------------------------
if [ "$PLATFORM" == "windows" ]; then
    echo "👉 [2/4] Windows ham binary ve DLL dosyaları topluca imzalanıyor..."
    ./installer/scripts/sign-windows-artifacts.sh --cert "$CERT_PATH" --pass "$CERT_PASS" --target "installer/packages/com.counterloadapp.main/data"
else
    echo "👉 [2/4] Linux mimarisi için paket öncesi imzalama adımı atlanıyor."
fi

# -------------------------------------------------------------------------
# ADIM 3: Yükleyici (Installer) Paketleme İşlemi (Adım 2.4)
# -------------------------------------------------------------------------
echo "👉 [3/4] $PLATFORM kurulum paketi derleniyor (QtIFW motoru tetikleniyor)..."

if [ "$PLATFORM" == "windows" ]; then
    # Wine ortam değişkenlerini temiz 64-bit olarak garanti altına alalım
    export WINEPREFIX="$HOME/.wine_counterload"
    export WINEDEBUG=-all

    # c0000135 (STATUS_DLL_NOT_FOUND) hatasını engellemek için bin klasörünün içine girerek çalıştırıyoruz
    cd /home/user/Masaüstü/Qt_counterloadapp/qt_ifw_win/Tools/QtInstallerFramework/4.7/bin/
    
    xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
    wine ./binarycreator.exe \
      -c "$ROOT_DIR/installer/config/config-windows.xml" \
      -p "$ROOT_DIR/installer/packages" \
      "$ROOT_DIR/artifacts/windows/CounterLoadSetup.exe"
      
    # Ana dizine güvenli geri dönüş yapalım
    cd "$ROOT_DIR"
    
elif [ "$PLATFORM" == "linux" ]; then
    # Linux için yerel binarycreator aracını tetikleyelim
    binarycreator \
      -c installer/config/config-linux.xml \
      -p installer/packages \
      artifacts/linux/CounterLoadSetup.run
fi

# -------------------------------------------------------------------------
# ADIM 4: Paketleme Sonrası Nihai Yükleyicinin İmzalanması
# -------------------------------------------------------------------------
if [ "$PLATFORM" == "windows" ]; then
    echo "👉 [4/4] Üretilen nihai CounterLoadSetup.exe yükleyicisi imzalanıyor..."
    ./installer/scripts/sign-windows-artifacts.sh --cert "$CERT_PATH" --pass "$CERT_PASS" --target "artifacts/windows/CounterLoadSetup.exe"
else
    echo "👉 [4/4] Linux nihai paketi (.run) için çalıştırma izinleri tanımlanıyor..."
    chmod +x artifacts/linux/CounterLoadSetup.run

    echo "👉 Linux paketi için SHA-256 bütünlük kontrol dosyası (.sha256) oluşturuluyor..."
    (cd artifacts/linux && sha256sum CounterLoadSetup.run > CounterLoadSetup.run.sha256)
    echo "👉 SHA-256 checksum başarıyla oluşturuldu: artifacts/linux/CounterLoadSetup.run.sha256"

    # GPG İmza Kontrolü ve Detached Signature
    if command -v gpg >/dev/null 2>&1; then
        echo "👉 GPG tespit edildi. Anahtar kontrolü yapılıyor..."
        # Eğer bir GPG anahtarı mevcutsa imzalayalım
        GPG_KEYS=$(gpg --list-secret-keys --keyid-format LONG | grep sec || true)
        if [ -n "$GPG_KEYS" ]; then
            echo "👉 GPG gizli anahtarı bulundu, detached signature (.asc) oluşturuluyor..."
            (cd artifacts/linux && gpg --batch --yes --detach-sign --armor CounterLoadSetup.run)
            echo "👉 Detached signature başarıyla oluşturuldu: artifacts/linux/CounterLoadSetup.run.asc"
        else
            echo "⚠️ Uyarı: Sistemde aktif bir GPG gizli anahtarı bulunamadı. GPG imzalama adımı atlanıyor."
        fi
    else
        echo "⚠️ Uyarı: 'gpg' aracı sistemde bulunamadı. GPG imzalama adımı atlanıyor."
    fi
fi

echo "================================================================="
echo "🎉 [BAŞARILI] $PLATFORM İÇİN TÜM PIPELINE SÜRECİ TAMAMLANDI!"
echo "📍 Çıktı Konumu: artifacts/$PLATFORM/"
echo "================================================================="
