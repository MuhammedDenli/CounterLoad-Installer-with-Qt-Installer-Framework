#!/bin/bash
set -e

TARGET_PATH=""
CERT_PATH=""

usage() {
    echo "Kullanım: $0 --target <dosya_veya_dizin> [--cert <sertifika_yolu>]"
    exit 1
}

# Parametrelerin ayrıştırılması
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --target) TARGET_PATH="$2"; shift ;;
        --cert) CERT_PATH="$2"; shift ;;
        *) echo "Bilinmeyen parametre: $1"; usage ;;
    esac
    shift
done

# Zorunlu parametre kontrolü
if [ -z "$TARGET_PATH" ]; then
    echo "Hata: Eksik parametreler!"
    usage
fi

verify_file() {
    local FILE="$1"
    echo "=> Doğrulanıyor: $FILE"
    
    local PEM_PATH=""
    if [ -n "$CERT_PATH" ]; then
        PEM_PATH="${CERT_PATH%.*}.pem"
    fi
    
    if [ -f "$PEM_PATH" ]; then
        osslsigncode verify -CAfile "$PEM_PATH" -in "$FILE"
    else
        osslsigncode verify -in "$FILE"
    fi
    echo "=> Doğrulama Başarılı: $FILE"
}

echo "=== Windows İmza Doğrulama İşlemi Başlatıldı ==="

if [ -f "$TARGET_PATH" ]; then
    verify_file "$TARGET_PATH"
elif [ -d "$TARGET_PATH" ]; then
    find "$TARGET_PATH" -type f \( -name "*.exe" -o -name "*.dll" \) | while read -r binary_file; do
        verify_file "$binary_file"
    done
else
    echo "Hata: Geçersiz hedef yol! ($TARGET_PATH bulunamadı)"
    exit 1
fi

echo "=== Tüm İmzalar Başarıyla Doğrulandı ==="
