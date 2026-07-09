#!/bin/bash

# Hata oluştuğunda betiğin çalışmasını hemen durduralım
set -e

CERT_PATH=""
PASSWORD=""
TARGET_PATH=""

usage() {
    echo "Kullanım: $0 --cert <sertifika_yolu> --pass <sifre> --target <dosya_veya_dizin>"
    exit 1
}

# Parametrelerin ayrıştırılması
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --cert) CERT_PATH="$2"; shift ;;
        --pass) PASSWORD="$2"; shift ;;
        --target) TARGET_PATH="$2"; shift ;;
        *) echo "Bilinmeyen parametre: $1"; usage ;;
    esac
    shift
done

# Zorunlu parametre kontrolleri
if [ -z "$CERT_PATH" ] || [ -z "$PASSWORD" ] || [ -z "$TARGET_PATH" ]; then
    echo "Hata: Eksik parametreler!"
    usage
fi

# Tek bir dosyayı imzalayan fonksiyon ve doğrulaması
sign_file() {
    local FILE="$1"
    echo "=> İmzalama işlemi başlatıldı: $FILE"
    
    # Güvenli imzalama için geçici bir çıktı dosyası kullanalım
    osslsigncode sign \
      -pkcs12 "$CERT_PATH" \
      -pass "$PASSWORD" \
      -n "CounterLoad Software" \
      -i https://counterloadapp.main \
      -t http://timestamp.digicert.com \
      -h sha256 \
      -in "$FILE" \
      -out "$FILE.signed"

    # Orijinal dosyanın üzerine imzalanmış sürümü yazalım
    mv "$FILE.signed" "$FILE"
    echo "=> Başarıyla imzalandı: $FILE"

    # İmzayı doğrula
    local PEM_PATH="${CERT_PATH%.*}.pem"
    echo "=> İmza doğrulama işlemi başlatıldı: $FILE"
    if [ -f "$PEM_PATH" ]; then
        osslsigncode verify -CAfile "$PEM_PATH" -in "$FILE"
    else
        osslsigncode verify -in "$FILE"
    fi
    echo "=> İmza başarıyla doğrulandı ve geçerli: $FILE"
}

# Ana akış kontrolü
echo "=== Windows Kod İmzalama Otomasyonu Başlatıldı ==="

if [ -f "$TARGET_PATH" ]; then
    # Hedef tek bir dosya ise (Örn: Nihai Yükleyici)
    sign_file "$TARGET_PATH"
elif [ -d "$TARGET_PATH" ]; then
    # Hedef bir dizin ise (Örn: Staging Klasörü)
    echo "Dizin taranıyor ve çalıştırılabilir dosyalar ayıklanıyor: $TARGET_PATH"
    
    # Klasör içindeki tüm .exe ve .dll dosyalarını bulup imzalayalım
    find "$TARGET_PATH" -type f \( -name "*.exe" -o -name "*.dll" \) | while read -r binary_file; do
        sign_file "$binary_file"
    done
else
    echo "Hata: Geçersiz hedef yol! ($TARGET_PATH bulunamadı)"
    exit 1
fi

echo "=== Tüm Windows Bileşenleri Başarıyla İmzalandı ==="
