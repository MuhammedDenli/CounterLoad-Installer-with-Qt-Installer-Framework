#!/bin/bash

# Hata oluştuğunda betiğin çalışmasını hemen durduralım
set -e

# Betik nereden çağrılırsa çağrılsın kendi projesinin kök dizinine geçsin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

# Parametre tanımları
VERSION=""
PLATFORM=""
STAGING_DIR=""
TARGET_DATA_DIR="installer/packages/com.counterloadapp.main/data"

usage() {
    echo "Kullanım: $0 --version <sürüm> --platform <windows|linux> --input <staging_dizini>"
    exit 1
}

# Parametrelerin ayrıştırılması
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift ;;
        --platform) PLATFORM="$2"; shift ;;
        --input) STAGING_DIR="$2"; shift ;;
        *) echo "Bilinmeyen parametre: $1"; usage ;;
    esac
    shift
done

# Zorunlu parametre kontrolleri
if [ -z "$VERSION" ] || [ -z "$PLATFORM" ] || [ -z "$STAGING_DIR" ]; then
    echo "Hata: Eksik parametreler!"
    usage
fi

echo "=== Staging Girdi Kontrolleri Başlatıldı ($PLATFORM - Sürüm: $VERSION) ==="

# Hedef temizliği: Önceki derlemelerden kalan artıkları temizleyelim
mkdir -p "$TARGET_DATA_DIR"
rm -rf "${TARGET_DATA_DIR:?}"/*

# -------------------------------------------------------------------------
# WINDOWS KONTROLLERİ
# -------------------------------------------------------------------------
if [ "$PLATFORM" == "windows" ]; then
    EXE_PATH="$STAGING_DIR/CounterLoad.exe"
    
    # 1. Ana uygulama executable dosyası mevcut mu?
    if [ ! -f "$EXE_PATH" ]; then
        echo "Hata: Ana Windows uygulaması (CounterLoad.exe) bulunamadı!"
        exit 1
    fi

    # 2. Gerekli DLL dosyaları mevcut mu?
    DLL_COUNT=$(ls "$STAGING_DIR"/*.dll 2>/dev/null | wc -l)
    if [ "$DLL_COUNT" -eq 0 ]; then
        echo "Hata: Gerekli DLL kütüphaneleri bulunamadı!"
        exit 1
    fi

    # 3. Binary mimarisi doğru mu? (64-bit kontrolü)
    if ! file "$EXE_PATH" | grep -qE "x86-64|PE32\+"; then
        echo "Hata: Binary mimarisi hatalı! 64-bit Windows mimarisi bekleniyor."
        exit 1
    fi

    # 4. Debug binary yanlışlıkla eklenmiş mi?
    if file "$EXE_PATH" | grep -q "with debug_info"; then
        echo "Hata: Pakete Debug binary eklenemez! Lütfen Release sürüm kullanın."
        exit 1
    fi

    echo "Windows staging kontrolleri başarıyla geçildi. Dosyalar paketleme alanına kopyalanıyor..."
    cp -r "$STAGING_DIR"/* "$TARGET_DATA_DIR/"

# -------------------------------------------------------------------------
# LINUX KONTROLLERİ
# -------------------------------------------------------------------------
elif [ "$PLATFORM" == "linux" ]; then
    BIN_PATH="$STAGING_DIR/counterload"

    # 1. Ana çalıştırılabilir dosya mevcut mu?
    if [ ! -f "$BIN_PATH" ]; then
        echo "Hata: Ana Linux uygulaması (counterload) bulunamadı!"
        exit 1
    fi

    # 2. Mimari ve Debug kontrolü
    if ! file "$BIN_PATH" | grep -q "x86-64"; then
        echo "Hata: Linux binary mimarisi hatalı! x86-64 bekleniyor."
        exit 1
    fi
    
    if file "$BIN_PATH" | grep -q "not stripped"; then
        echo "Hata: Linux uygulaması 'not stripped' (Debug sembolleri içeriyor). Paketleme durduruldu!"
        exit 1
    fi

    echo "Linux staging kontrolleri başarıyla geçildi. Dosyalar paketleme alanına kopyalanıyor..."
    cp -r "$STAGING_DIR"/* "$TARGET_DATA_DIR/"

else
    echo "Hata: Geçersiz platform tipi! (windows veya linux seçilmeli)"
    exit 1
fi

# Masaüstü kısayol simgesini paket veri dizinine kopyala
if [ -d "installer/resources/icons" ]; then
    echo "👉 Masaüstü kısayol simgeleri paket veri dizinine kopyalanıyor..."
    mkdir -p "$TARGET_DATA_DIR/resources/icons"
    cp -r installer/resources/icons/* "$TARGET_DATA_DIR/resources/icons/"
fi

echo "=== Staging Kontrolü ve Veri Hazırlama Başarıyla Tamamlandı ==="
