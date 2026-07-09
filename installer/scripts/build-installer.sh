#!/bin/bash

# Herhangi bir adım hata verirse betiğin çalışmasını hemen durduralım
set -e

# Proje kök dizininde olduğumuzdan emin olalım
if [ ! -d "installer" ]; then
    echo "Hata: Lütfen bu betiği projenin kök dizinden çalıştırın!"
    exit 1
fi

VERSION=""
LINUX_INPUT="staging/linux"
WINDOWS_INPUT="staging/windows"
OUTPUT_DIR="artifacts"
BUILD_WINDOWS=false
BUILD_LINUX=false
SIGN_WINDOWS=false
CERT_PATH="installer/certs/test_cert.pfx"
CERT_PASS="123456"
ROOT_DIR=$(pwd)

usage() {
    echo "Kullanım: $0 [SEÇENEKLER]"
    echo "Seçenekler:"
    echo "  --version <sürüm>         Derlenecek kurulum paketinin sürümü (Zorunlu)"
    echo "  --linux-input <dizin>     Linux staging girdi dizini (Varsayılan: staging/linux)"
    echo "  --windows-input <dizin>   Windows staging girdi dizini (Varsayılan: staging/windows)"
    echo "  --output <dizin>          Çıktı dosyalarının oluşturulacağı dizin (Varsayılan: artifacts)"
    echo "  --build-windows           Windows kurulum paketini derle"
    echo "  --build-linux             Linux kurulum paketini derle"
    echo "  --sign-windows            Windows ikili dosyalarını ve yükleyicisini imzala"
    echo "  --cert <sertifika>        Windows kod imzalama sertifikası (.pfx) (Varsayılan: installer/certs/test_cert.pfx)"
    echo "  --pass <şifre>            Sertifika şifresi (Varsayılan: 123456)"
    echo "  --platform <win|linux>    Geriye dönük uyumluluk için platform seçimi (windows veya linux)"
    echo "  -h, --help                Bu yardım mesajını göster"
    exit 1
}

# Parametrelerin ayrıştırılması
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --linux-input) LINUX_INPUT="$2"; shift ;;
        --windows-input) WINDOWS_INPUT="$2"; shift ;;
        --output) OUTPUT_DIR="$2"; shift ;;
        --build-windows) BUILD_WINDOWS=true ;;
        --build-linux) BUILD_LINUX=true ;;
        --sign-windows) SIGN_WINDOWS=true ;;
        --cert) CERT_PATH="$2"; shift ;;
        --pass) CERT_PASS="$2"; shift ;;
        --platform)
            PLATFORM_VAL="$2"
            if [ "$PLATFORM_VAL" == "windows" ] || [ "$PLATFORM_VAL" == "win" ]; then
                BUILD_WINDOWS=true
            elif [ "$PLATFORM_VAL" == "linux" ]; then
                BUILD_LINUX=true
            fi
            shift
            ;;
        -h|--help) usage ;;
        *) echo "Bilinmeyen parametre: $1"; usage ;;
    esac
    shift
done

if [ -z "$VERSION" ]; then
    echo "Hata: --version parametresi zorunludur!"
    usage
fi

if [ "$BUILD_WINDOWS" = false ] && [ "$BUILD_LINUX" = false ]; then
    echo "Hata: En az bir platform seçilmelidir (--build-windows veya --build-linux)!"
    usage
fi

echo "================================================================="
echo "🚀 BÜTÜNLEŞİK DERLEME OTOMASYONU BAŞLATILDI (Sürüm: v$VERSION)"
echo "================================================================="

# Çıktı dizinlerini hazırlayalım
mkdir -p "$OUTPUT_DIR"

# =========================================================================
# WINDOWS DERLEME HATTI
# =========================================================================
if [ "$BUILD_WINDOWS" = true ]; then
    echo ""
    echo "================================================================="
    echo "📦 WINDOWS KURULUM PAKETİ HAZIRLANIYOR"
    echo "================================================================="
    mkdir -p "$OUTPUT_DIR/windows"

    # ADIM 1: Girdi Kontrolleri ve Staging Alanı Hazırlığı
    echo "👉 [1/4] Girdi dosyaları doğrulanıyor ve staging alanına taşınıyor..."
    ./installer/scripts/prepare-package.sh --version "$VERSION" --platform "windows" --input "$WINDOWS_INPUT"

    # ADIM 2: Paket öncesi ikili dosyaların imzalanması (Opsiyonel)
    if [ "$SIGN_WINDOWS" = true ]; then
        echo "👉 [2/4] Windows ham binary ve DLL dosyaları topluca imzalanıyor..."
        ./installer/scripts/sign-windows-artifacts.sh --cert "$CERT_PATH" --pass "$CERT_PASS" --target "installer/packages/com.counterloadapp.main/data"
    else
        echo "👉 [2/4] Windows imzalama adımı atlandı (--sign-windows seçilmedi)."
    fi

    # ADIM 3: Yükleyiciyi Paketleme (Wine + QtIFW)
    echo "👉 [3/4] Windows kurulum paketi derleniyor (Wine + QtIFW)..."
    
    # Wine ortam değişkenlerini temiz 64-bit olarak garanti altına alalım
    export WINEPREFIX="$HOME/.wine_counterload"
    export WINEDEBUG=-all

    # c0000135 (STATUS_DLL_NOT_FOUND) hatasını engellemek için bin klasörünün içine girerek çalıştırıyoruz
    cd /home/user/Masaüstü/Qt_counterloadapp/qt_ifw_win/Tools/QtInstallerFramework/4.7/bin/
    
    xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
    wine ./binarycreator.exe \
      -c "$ROOT_DIR/installer/config/config-windows.xml" \
      -p "$ROOT_DIR/installer/packages" \
      "$ROOT_DIR/$OUTPUT_DIR/windows/CounterLoadSetup.exe"
      
    cd "$ROOT_DIR"

    # ADIM 4: Paketleme Sonrası Nihai Yükleyicinin İmzalanması (Opsiyonel)
    if [ "$SIGN_WINDOWS" = true ]; then
        echo "👉 [4/4] Üretilen nihai CounterLoadSetup.exe yükleyicisi imzalanıyor..."
        ./installer/scripts/sign-windows-artifacts.sh --cert "$CERT_PATH" --pass "$CERT_PASS" --target "$OUTPUT_DIR/windows/CounterLoadSetup.exe"
    else
        echo "👉 [4/4] Windows final imzalama adımı atlandı."
    fi

    echo "🎉 [BAŞARILI] Windows Kurulum Paketi Başarıyla Tamamlandı!"
    echo "📍 Çıktı Konumu: $OUTPUT_DIR/windows/CounterLoadSetup.exe"
fi

# =========================================================================
# LINUX DERLEME HATTI
# =========================================================================
if [ "$BUILD_LINUX" = true ]; then
    echo ""
    echo "================================================================="
    echo "📦 LINUX KURULUM PAKETİ HAZIRLANIYOR"
    echo "================================================================="
    mkdir -p "$OUTPUT_DIR/linux"

    # ADIM 1: Girdi Kontrolleri ve Staging Alanı Hazırlığı
    echo "👉 [1/4] Girdi dosyaları doğrulanıyor ve staging alanına taşınıyor..."
    ./installer/scripts/prepare-package.sh --version "$VERSION" --platform "linux" --input "$LINUX_INPUT"

    # ADIM 2: Linux için paket öncesi imzalama adımı yok
    echo "👉 [2/4] Linux mimarisi için paket öncesi imzalama adımı atlanıyor."

    # ADIM 3: Yükleyiciyi Paketleme (Local QtIFW)
    echo "👉 [3/4] Linux kurulum paketi derleniyor (QtIFW)..."
    binarycreator \
      -c installer/config/config-linux.xml \
      -p installer/packages \
      "$OUTPUT_DIR/linux/CounterLoadSetup.run"

    # ADIM 4: Çalıştırma İzinleri, Bütünlük (SHA-256) ve GPG İmzalama
    echo "👉 [4/4] Linux nihai paketi (.run) için çalıştırma izinleri tanımlanıyor..."
    chmod +x "$OUTPUT_DIR/linux/CounterLoadSetup.run"

    echo "👉 Linux paketi için SHA-256 bütünlük kontrol dosyası (.sha256) oluşturuluyor..."
    (cd "$OUTPUT_DIR/linux" && sha256sum CounterLoadSetup.run > CounterLoadSetup.run.sha256)
    echo "👉 SHA-256 checksum başarıyla oluşturuldu: $OUTPUT_DIR/linux/CounterLoadSetup.run.sha256"

    # GPG Detached Signature oluşturulması
    if command -v gpg >/dev/null 2>&1; then
        echo "👉 GPG tespit edildi. Anahtar kontrolü yapılıyor..."
        GPG_KEYS=$(gpg --list-secret-keys --keyid-format LONG | grep sec || true)
        if [ -n "$GPG_KEYS" ]; then
            echo "👉 GPG gizli anahtarı bulundu, detached signature (.asc) oluşturuluyor..."
            (cd "$OUTPUT_DIR/linux" && gpg --batch --yes --detach-sign --armor CounterLoadSetup.run)
            echo "👉 Detached signature başarıyla oluşturuldu: $OUTPUT_DIR/linux/CounterLoadSetup.run.asc"
        else
            echo "⚠️ Uyarı: Sistemde aktif bir GPG gizli anahtarı bulunamadı. GPG imzalama adımı atlanıyor."
        fi
    else
        echo "⚠️ Uyarı: 'gpg' aracı sistemde bulunamadı. GPG imzalama adımı atlanıyor."
    fi

    echo "🎉 [BAŞARILI] Linux Kurulum Paketi Başarıyla Tamamlandı!"
    echo "📍 Çıktı Konumu: $OUTPUT_DIR/linux/CounterLoadSetup.run"
fi

echo ""
echo "================================================================="
echo "🎉 TÜM PIPELINE SÜREÇLERİ TAMAMLANDI!"
echo "================================================================="
