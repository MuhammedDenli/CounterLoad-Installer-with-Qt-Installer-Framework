#!/bin/bash

# Herhangi bir adım hata verirse betiğin çalışmasını hemen durduralım
set -e

# Betik nereden çağrılırsa çağrılsın kendi projesinin kök dizinine geçsin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

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

# Config ve paket dosyalarındaki sürüm bilgilerini dinamik olarak güncelleyelim
echo "👉 Yapılandırma ve paket dosyalarındaki sürüm bilgileri v$VERSION olarak güncelleniyor..."
sed -i "s|<Version>[^<]*</Version>|<Version>$VERSION</Version>|g" "installer/config/config-windows.xml"
sed -i "s|<Version>[^<]*</Version>|<Version>$VERSION</Version>|g" "installer/config/config-linux.xml"
sed -i "s|<Version>[^<]*</Version>|<Version>$VERSION</Version>|g" "installer/packages/com.counterloadapp.main/meta/package.xml"

# GUI Başlıklarını sürüm bilgisiyle güncelleyelim
sed -i "s|<Title>[^<]*</Title>|<Title>CounterLoad v$VERSION</Title>|g" "installer/config/config-windows.xml"
sed -i "s|<Title>[^<]*</Title>|<Title>CounterLoad v$VERSION</Title>|g" "installer/config/config-linux.xml"


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

    # binarycreator.exe dosyasını projenin kök dizininden göreceli yollarla çalıştırıyoruz
    # Böylece paket içerisindeki dosya yolları mutlak (Z:/home/user/...) yerine doğru şekilde göreceli olarak derlenir.
    xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
    wine /home/user/Masaüstü/Qt_counterloadapp/qt_ifw_win/Tools/QtInstallerFramework/4.7/bin/binarycreator.exe \
      -c "installer/config/config-windows.xml" \
      -p "installer/packages" \
      "$OUTPUT_DIR/windows/CounterLoadSetup-$VERSION.exe"

    # ADIM 4: Paketleme Sonrası Nihai Yükleyicinin İmzalanması (Opsiyonel)
    if [ "$SIGN_WINDOWS" = true ]; then
        echo "👉 [4/4] Üretilen nihai CounterLoadSetup-$VERSION.exe yükleyicisi imzalanıyor..."
        ./installer/scripts/sign-windows-artifacts.sh --cert "$CERT_PATH" --pass "$CERT_PASS" --target "$OUTPUT_DIR/windows/CounterLoadSetup-$VERSION.exe"
    else
        echo "👉 [4/4] Windows final imzalama adımı atlandı."
    fi

    echo "🎉 [BAŞARILI] Windows Kurulum Paketi Başarıyla Tamamlandı!"
    echo "📍 Çıktı Konumu: $OUTPUT_DIR/windows/CounterLoadSetup-$VERSION.exe"
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
      "$OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.bin"

    echo "👉 Linux yükleyicisi için CLI ve GUI uyumluluk wrapper betiği oluşturuluyor..."
    # Grafik ve CLI destekleyen wrapper betiği oluşturuyoruz
    cat << 'EOF' > "$OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.run"
#!/bin/bash
# CounterLoad Kurulum Sihirbazı Wrapper
# Bu betik, grafiksel oturumun olmadığı ortamlarda otomatik veya interaktif CLI kurulumu sağlar.

set -e

# Key=Value formatındaki argümanları ayıklayıp çevre değişkeni olarak dışa aktaralım
for arg in "$@"; do
    if [[ "$arg" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        export "$key"="$val"
        upper_key=$(echo "$key" | sed -e 's/\([A-Z]\)/_\1/g' | tr '[:lower:]' '[:upper:]')
        export "$upper_key"="$val"
    fi
done

# Temizleme fonksiyonu
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# Geçici dizin oluşturulması
TMP_DIR=$(mktemp -d -t counterload-installer-XXXXXX)
BIN_PATH="$TMP_DIR/CounterLoadSetup.bin"

# Script içindeki binary payload offsetinin bulunması ve dışarı aktarılması
PAYLOAD_LINE=$(awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0;}' "$0")
tail -n +$PAYLOAD_LINE "$0" > "$BIN_PATH"
chmod +x "$BIN_PATH"

# Grafik oturumu kontrolü
HAS_DISPLAY=true
if [ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    HAS_DISPLAY=false
fi

# Grafiksel oturum yoksa platform olarak minimal seçelim
if [ "$HAS_DISPLAY" = false ]; then
    export QT_QPA_PLATFORM=minimal
fi

# CLI moduna geçiş komutlarını tespit etme
IS_CLI_CMD=false
for arg in "$@"; do
    case "$arg" in
        install|in|update|up|check-updates|ch|remove|rm|list|li|search|se|create-offline|co|clear-cache|cc|purge|pr|-h|--help|--help-all|-v|--version)
            IS_CLI_CMD=true
            break
            ;;
    esac
done

# Eğer kullanıcı CLI komutu veya yardım parametresi geçmişse (grafik oturumu olmasa da çalışmalı)
if [ "$IS_CLI_CMD" = true ]; then
    IS_INSTALL=false
    for arg in "$@"; do
        if [ "$arg" = "install" ] || [ "$arg" = "in" ]; then
            IS_INSTALL=true
            break
        fi
    done

    if [ "$IS_INSTALL" = true ]; then
        TARGET_DIR="$HOME/Kurulumlar/CounterLoad"
        args_copy=("$@")
        for ((i=0; i<${#args_copy[@]}; i++)); do
            arg="${args_copy[i]}"
            if [[ "$arg" == "--root" || "$arg" == "-t" ]]; then
                TARGET_DIR="${args_copy[i+1]}"
            elif [[ "$arg" =~ ^--root=(.*)$ || "$arg" =~ ^-t=(.*)$ || "$arg" =~ ^TargetDir=(.*)$ ]]; then
                TARGET_DIR="${BASH_REMATCH[1]}"
            fi
        done
        TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

        if [ -x "$TARGET_DIR/maintenancetool" ]; then
            if [ -t 0 ]; then
                echo "Seçilen dizinde zaten bir kurulum mevcut: $TARGET_DIR"
                read -p "Mevcut kurulum kaldırılarak güncelleme yapılacaktır. Devam etmek istiyor musunuz? [E/h]: " CONFIRM_PURGE
                CONFIRM_PURGE=${CONFIRM_PURGE:-E}
                if [[ ! "$CONFIRM_PURGE" =~ ^[EeYy]$ ]]; then
                    echo "Kurulum iptal edildi."
                    exit 1
                fi
            else
                echo "Mevcut kurulum tespit edildi ($TARGET_DIR). Güncelleme için eski sürüm kaldırılıyor..."
            fi
            env -u DISPLAY -u WAYLAND_DISPLAY QT_QPA_PLATFORM=minimal "$TARGET_DIR/maintenancetool" purge --confirm-command || true
        fi
    fi

    "$BIN_PATH" "$@"
    exit $?
fi

# Grafiksel oturum yoksa ve komut geçilmemişse (Headless interaktif/non-interaktif)
if [ "$HAS_DISPLAY" = false ]; then
    if [ -t 0 ]; then
        # Terminal interaktif ise interaktif CLI kurulum sihirbazını başlatalım
        echo "============================================================="
        echo "     CounterLoad Kurulum Sihirbazı v@VERSION@ (CLI Modu)     "
        echo "============================================================="
        echo "Grafiksel oturum (DISPLAY) bulunamadı."
        echo "Kurulum komut satırı üzerinden interaktif olarak gerçekleştirilecektir."
        echo ""

        DEFAULT_DIR="$HOME/Kurulumlar/CounterLoad"
        read -p "Kurulum yapılacak hedef dizin [$DEFAULT_DIR]: " TARGET_DIR
        if [ -z "$TARGET_DIR" ]; then
            TARGET_DIR="$DEFAULT_DIR"
        fi

        # ~ karakterini ev dizini ile değiştirelim
        TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

        echo "Hedef dizin: $TARGET_DIR"

        # Kaydedilmiş ayarların okunması
        SETTINGS_FILE="$HOME/.config/CounterLoad/installer_settings.json"
        DEF_CLI="7894"; DEF_APP="4444"; DEF_MAN="4445"; DEF_IP="172.17.0.3"; DEF_SN="003"
        if [ -f "$SETTINGS_FILE" ] && command -v python3 >/dev/null 2>&1; then
            DEF_CLI=$(python3 -c "import json; print(json.load(open('$SETTINGS_FILE')).get('cliAuthServicePort', '7894'))" 2>/dev/null || echo "7894")
            DEF_APP=$(python3 -c "import json; print(json.load(open('$SETTINGS_FILE')).get('remoteAppPort', '4444'))" 2>/dev/null || echo "4444")
            DEF_MAN=$(python3 -c "import json; print(json.load(open('$SETTINGS_FILE')).get('remoteManPort', '4445'))" 2>/dev/null || echo "4445")
            DEF_IP=$(python3 -c "import json; print(json.load(open('$SETTINGS_FILE')).get('remoteIp', '172.17.0.3'))" 2>/dev/null || echo "172.17.0.3")
            DEF_SN=$(python3 -c "import json; print(json.load(open('$SETTINGS_FILE')).get('serialNo', '003'))" 2>/dev/null || echo "003")
        fi

        echo ""
        echo "-------------------------------------------------------------"
        echo "   Cihaz ve Ağ Yapılandırması (Device & Network Settings)   "
        echo "-------------------------------------------------------------"
        read -p "CLI Auth Service Port [$DEF_CLI]: " IN_CLI_PORT
        read -p "Remote App Port [$DEF_APP]: " IN_APP_PORT
        read -p "Remote Management Port [$DEF_MAN]: " IN_MAN_PORT
        read -p "Remote IP [$DEF_IP]: " IN_REMOTE_IP
        read -p "Serial No [$DEF_SN]: " IN_SERIAL_NO

        export cliAuthServicePort="${IN_CLI_PORT:-$DEF_CLI}"
        export remoteAppPort="${IN_APP_PORT:-$DEF_APP}"
        export remoteManPort="${IN_MAN_PORT:-$DEF_MAN}"
        export remoteIp="${IN_REMOTE_IP:-$DEF_IP}"
        export serialNo="${IN_SERIAL_NO:-$DEF_SN}"

        # Eğer hedef dizinde bir maintenancetool varsa, temizlik için soralım
        if [ -x "$TARGET_DIR/maintenancetool" ]; then
            read -p "Seçilen dizinde zaten bir kurulum mevcut. Kaldırılarak güncelleme yapılacaktır. Devam etmek istiyor musunuz? [E/h]: " CONFIRM_PURGE
            CONFIRM_PURGE=${CONFIRM_PURGE:-E}
            if [[ ! "$CONFIRM_PURGE" =~ ^[EeYy]$ ]]; then
                echo "Kurulum iptal edildi."
                exit 0
            fi
            echo "Mevcut sürüm kaldırılıyor..."
            env -u DISPLAY -u WAYLAND_DISPLAY QT_QPA_PLATFORM=minimal "$TARGET_DIR/maintenancetool" purge --confirm-command || true
        else
            read -p "Kurulumı başlatmak istiyor musunuz? [E/h]: " CONFIRM
            CONFIRM=${CONFIRM:-E}
            if [[ ! "$CONFIRM" =~ ^[EeYy]$ ]]; then
                echo "Kurulum iptal edildi."
                exit 0
            fi
        fi

        echo "Kurulum başlatılıyor..."
        "$BIN_PATH" --root "$TARGET_DIR" install --accept-licenses --confirm-command
        exit $?
    else
        # Terminal interaktif değilse sessiz (silent) kurulumu varsayılan dizine başlatalım
        echo "Grafiksel oturum bulunamadı ve terminal interaktif değil."
        DEFAULT_DIR="$HOME/Kurulumlar/CounterLoad"
        if [ -x "$DEFAULT_DIR/maintenancetool" ]; then
            echo "Mevcut kurulum tespit edildi ($DEFAULT_DIR). Güncelleme için eski sürüm kaldırılıyor..."
            env -u DISPLAY -u WAYLAND_DISPLAY QT_QPA_PLATFORM=minimal "$DEFAULT_DIR/maintenancetool" purge --confirm-command || true
        fi
        echo "Varsayılan dizine sessiz (silent) v@VERSION@ kurulumu başlatılıyor..."
        "$BIN_PATH" install --accept-licenses --confirm-command
        exit $?
    fi
else
    # Grafiksel oturum mevcutsa normal çalıştır (GUI)
    "$BIN_PATH" "$@"
    exit $?
fi

__PAYLOAD_BELOW__
EOF

    # Wrapper script içindeki versiyon etiketlerini yerleştirelim
    sed -i "s|@VERSION@|$VERSION|g" "$OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.run"

    # Binary payload'u wrapper scriptin sonuna ekleyelim
    cat "$OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.bin" >> "$OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.run"
    rm "$OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.bin"


    # ADIM 4: Çalıştırma İzinleri, Bütünlük (SHA-256) ve GPG İmzalama
    echo "👉 [4/4] Linux nihai paketi (.run) için çalıştırma izinleri tanımlanıyor..."
    chmod +x "$OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.run"

    echo "👉 Linux paketi için SHA-256 bütünlük kontrol dosyası (.sha256) oluşturuluyor..."
    (cd "$OUTPUT_DIR/linux" && sha256sum CounterLoadSetup-$VERSION.run > CounterLoadSetup-$VERSION.run.sha256)
    echo "👉 SHA-256 checksum başarıyla oluşturuldu: $OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.run.sha256"

    # GPG Detached Signature oluşturulması
    if command -v gpg >/dev/null 2>&1; then
        echo "👉 GPG tespit edildi. Anahtar kontrolü yapılıyor..."
        GPG_KEYS=$(gpg --list-secret-keys --keyid-format LONG | grep sec || true)
        if [ -n "$GPG_KEYS" ]; then
            echo "👉 GPG gizli anahtarı bulundu, detached signature (.asc) oluşturuluyor..."
            (cd "$OUTPUT_DIR/linux" && gpg --batch --yes --detach-sign --armor CounterLoadSetup-$VERSION.run)
            echo "👉 Detached signature başarıyla oluşturuldu: $OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.run.asc"
        else
            echo "⚠️ Uyarı: Sistemde aktif bir GPG gizli anahtarı bulunamadı. GPG imzalama adımı atlanıyor."
        fi
    else
        echo "⚠️ Uyarı: 'gpg' aracı sistemde bulunamadı. GPG imzalama adımı atlanıyor."
    fi

    echo "🎉 [BAŞARILI] Linux Kurulum Paketi Başarıyla Tamamlandı!"
    echo "📍 Çıktı Konumu: $OUTPUT_DIR/linux/CounterLoadSetup-$VERSION.run"
fi

echo ""
echo "================================================================="
echo "🎉 TÜM PIPELINE SÜREÇLERİ TAMAMLANDI!"
echo "================================================================="
