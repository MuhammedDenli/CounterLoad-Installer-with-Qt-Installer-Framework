# CounterLoad & CounterLoad-Light Installer Altyapısı Geliştirme ve Kullanım Kılavuzu

Bu döküman, **CounterLoad** projesinin Windows ve Linux işletim sistemleri için cross-platform kurulum paketi (installer) altyapısının baştan sona nasıl tasarlandığını, geliştirildiğini, derlendiğini ve işletildiğini adım adım açıklayan **teknik kılavuz rehberidir**.

---

## 1. Proje Mimarisi ve Karar Matrisi

### 1.1 Projenin Amacı ve Kapsamı
Projenin temel amacı, tek bir Linux build sunucusu üzerinden hem Windows hem de Linux işletim sistemleri için dağıtılabilir, imzalı, güvenli ve esnek kurulum paketleri üretmektir.

Desteklenen Kurulum Senaryoları:
* **Windows GUI & CLI:** Grafik arayüzlü kurulum sihirbazı ve tam otomatik (sessiz/unattended) komut satırı kurulumu.
* **Linux Masaüstü (GUI):** GNOME, KDE Plasma, X11 ve Wayland ortamlarında görsel kurulum sihirbazı.
* **Linux Sunucu / Headless (CLI):** Ekran (`DISPLAY`) bulunmayan ortamlarda interaktif CLI sihirbazı veya tamamen sessiz paket kurulumu.
* **Otomatik Kod İmzalama:** Windows ikilileri (`.exe`, `.dll`) ve nihai installer dosyalarının Linux build sunucusunda `osslsigncode` ile Authenticode imzalanması.


### 1.2 Teknolojik Yaklaşım Karar Matrisi
PoC (Proof of Concept) ve araştırma safhasında değerlendirilen teknolojiler ve seçim gerekçeleri aşağıda özetlenmiştir:

| Teknolojik Araç | Kullanım Alanı | Avantajları | Dezavantajları / Riskler | Karar / Sonuç |
| :--- | :--- | :--- | :--- | :--- |
| **Qt Installer Framework (QtIFW)** | Windows & Linux GUI / CLI | Ortak metadata yapısı (`config.xml`, `package.xml`), `installscript.js` esnekliği, MaintenanceTool desteği. | Linux host üzerinde yerel Windows installer derleyememesi (Wine gereksinimi). | **Birincil Seçim (Seçildi)** |
| **Wine + QtIFW Windows BinaryCreator** | Windows Cross-Build | Linux build sunucusunda Windows `.exe` installer üretimini sağlar. | headless Xvfb sanal ekran bağımlılığı. | **Uygulandı (Stabil)** |
| **Hybrid Shell Wrapper (.run)** | Linux CLI / GUI Hybrid | Ekransız sistemlerde yerel binary payload çıkartarak CLI sihirbazına düşer. | Ekstra script sarılmasını gerektirir. | **Uygulandı (Stabil)** |
| **CPack (CMake)** | Multi-platform paketleme | CMake projelerine doğrudan entegrasyon, `.deb`/`.rpm` üretimi. | QtIFW kadar esnek GUI/MaintenanceTool sunmaması. | Alternatif olarak değerlendirildi |
| **makeself** | Linux Self-extracting | Çok hafif, tamamen komut satırı odaklı. | Modern GUI sihirbazı ve gelişmiş uninstall/upgrade mekanizması yok. | Shell wrapper mantığı için esinlenildi |
| **Inno Setup / NSIS (Wine altında)** | Windows Kurulumu | Wine ile sorunsuz çalışır, hafif EXE üretir. | Ortak QtIFW paket yapısından sapma gerektirir. | Yedek hibrit plan |

---

## 2. Dizin ve Dosya Yapısı

Proje kök dizininde iki ana uygulama türevi yer almaktadır: `CounterLoad` (Özel Tema) ve `CounterLoad-Light` (Standart Tema). Her iki dizin de modüler ve path-independent (yoldan bağımsız) bir installer yapısına sahiptir.

```text
CounterLoad/
├── installer/
│   ├── certs/                      # Kod imzalama sertifikaları (.pfx, .pem, .key)
│   │   ├── test_cert.pfx
│   │   ├── test_cert.pem
│   │   └── test_key.pem
│   ├── config/                     # QtIFW yapılandırma XML ve stil dosyaları
│   │   ├── config.xml              # Ana yapılandırma
│   │   ├── config-windows.xml      # Windows için özelleştirilmiş XML
│   │   ├── config-linux.xml        # Linux için özelleştirilmiş XML
│   │   ├── style.qss               # QSS Teması
│   │   ├── banner.png              # Sihirbaz üst görseli
│   │   └── logo1.png / logo1.ico   # Uygulama ve installer ikonları
│   ├── packages/                   # QtIFW Paket Tanımları
│   │   └── com.counterloadapp.main/
│   │       ├── data/               # Dağıtılacak ikili ve kaynak dosyalar
│   │       |   ├── config/
│   │       │   ├── CounterLoad.exe / counterload
│   │       │   ├── dependency.dll
│   │       │   └── resources/
│   │       └── meta/               # Paket meta verileri ve özel UI sayfaları
│   │           ├── package.xml     # Paket açıklama ve bağımlılık bilgileri
│   │           ├── installscript.js # Kurulum mantığı ve olay dinleyicileri (JavaScript)
│   │           ├── configpage.ui   # Cihaz ve Ağ Yapılandırması özel ekranı
│   │           ├── shortcutcheckbox.ui # Masaüstü kısayol seçim ekranı
│   │           └── license.txt     # Lisans metni
│   ├── resources/                  # Simgeler ve lisans kaynakları
│   └── scripts/                    # Derleme ve Otomasyon Betikleri
│       ├── build-installer.sh      # Ana Orkestrasyon Betiği (Build & Sign Pipeline)
│       ├── build-windows-installer.sh # Windows özel derleme scripti
│       ├── build-linux-installer.sh   # Linux özel derleme scripti
│       ├── prepare-package.sh      # Staging alanından paket data'ya taşıma betiği
│       ├── sign-windows-artifacts.sh # Windows ikililerini ve EXE'sini imzalama betiği
│       └── verify-windows-signatures.sh # Authenticode imza doğrulama betiği
├── staging/                        # Derleme öncesi ham ikili girdiler (CI/CD Çıktıları)
│   ├── linux/
│   └── windows/
└── artifacts/                      # Derleme sonucu oluşan nihai kurulum paketleri
    ├── linux/
    │   ├── CounterLoadSetup-1.2.5.run
    │   ├── CounterLoadSetup-1.2.5.run.sha256
    │   └── CounterLoadSetup-1.2.5.run.asc
    └── windows/
        └── CounterLoadSetup-1.2.5.exe
```

---

## 3. Ön Gereksinimler ve Geliştirme Ortamı Kurulumu

Linux build sunucusunda (Ubuntu / Debian / RHEL) otomatik installer üretebilmek için aşağıdaki paketlerin ve araçların kurulu olması gerekmektedir:

### 3.1 Gerekli Linux Paketlerinin Yüklenmesi

```bash
# Sistem paketlerinin güncellenmesi
sudo apt-get update

# Temel yapılandırma ve bağımlılık araçları
sudo apt-get install -y \
    build-essential \
    qttools5-dev-tools \
    wine64 \
    xvfb \
    osslsigncode \
    openssl \
    gpg \
    python3 \
    coreutils
```

### 3.2 Qt Installer Framework (QtIFW) Kurulumu
1. **Linux Native QtIFW:** `binarycreator` komutunun sistem yoluna (`PATH`) eklenmesi gerekir.
2. **Windows QtIFW (Wine Kurulumu):** Linux üzerinde Windows installer üretmek için Windows uyumlu `binarycreator.exe` aracı `/home/user/Masaüstü/Qt_counterloadapp/qt_ifw_win/Tools/QtInstallerFramework/4.7/bin/binarycreator.exe` konumunda veya projeye özel dizinde bulundurulmalıdır.

### 3.3 WinePrefix Yapılandırılması
Windows derleyici aracının headless ortamda sorunsuz çalışabilmesi için özel bir WinePrefix kullanılır:

```bash
export WINEPREFIX="$HOME/.wine_counterload"
export WINEDEBUG=-all
wineboot -u
```

---

## 4. Sertifika ve Kod İmzalama Altyapısı

Windows işletim sisteminde UAC (User Account Control) ekranında *"Bilinmeyen Yayıncı (Unknown Publisher)"* uyarısını önlemek ve dosya bütünlüğünü garanti etmek için **Authenticode Kod İmzalama (Code Signing)** zorunludur.

### 4.1 Test Kod İmzalama Sertifikası Oluşturulması (Self-Signed PFX & PEM)
Geliştirme ve test ortamlarında kullanılmak üzere SHA-256 tabanlı RSA imzalama sertifikası oluşturma adımları:

```bash
# 1. Sertifika dizinine geçiş
cd installer/certs

# 2. Özel Anahtar (Private Key) ve Kök Sertifika Üretimi
openssl req -x509 -newkey rsa:4096 -keyout test_key.pem -out test_cert.pem -days 365 -nodes \
  -subj "/CN=CounterLoad Corporation/O=CounterLoad Software/C=TR"

# 3. OpenSSL ile PFX (PKCS#12) Sertifika Paketinin Oluşturulması
openssl pkcs12 -export -out test_cert.pfx -inkey test_key.pem -in test_cert.pem \
  -name "CounterLoad Code Signing" -passout pass:123456

# 4. İzinlerin Sınırlandırılması
chmod 600 test_key.pem test_cert.pfx
```

### 4.2 Windows Kod İmzalama Mantığı (`osslsigncode`)
Windows ikili dosyaları (`.exe`, `.dll`) ve derlenen nihai `CounterLoadSetup-X.Y.Z.exe` yükleyicisi, Linux üzerinde `osslsigncode` aracı ile imzalanır.

İmzalama Sıralaması (Kritik):
1. **Staging / Data İkilileri:** `CounterLoad.exe` ve `dependency.dll` dosyaları **paketleme yapılmadan önce** imzalanır.
2. **Nihai Yükleyici:** `binarycreator.exe` ile paket oluşturulduktan sonra nihai `CounterLoadSetup.exe` **tekrar** imzalanır.

#### İmzalama Komutu (`sign-windows-artifacts.sh`):
```bash
./installer/scripts/sign-windows-artifacts.sh \
  --cert "installer/certs/test_cert.pfx" \
  --pass "123456" \
  --target "installer/packages/com.counterloadapp.main/data"
```

İmzalama betiğinin arka planda çalıştırdığı soyut `osslsigncode` komutu:
```bash
osslsigncode sign \
  -pkcs12 "installer/certs/test_cert.pfx" \
  -pass "123456" \
  -n "CounterLoad Software" \
  -i https://counterloadapp.main \
  -t http://timestamp.digicert.com \
  -h sha256 \
  -in "CounterLoad.exe" \
  -out "CounterLoad.exe.signed"
```

### 4.3 Authenticode İmza Doğrulama (`verify-windows-signatures.sh`)
İmzalanmış ikili dosyaların sertifika ve timestamp geçerliliği aşağıdaki komutla doğrulanır:

```bash
./installer/scripts/verify-windows-signatures.sh \
  --target "artifacts/windows/CounterLoadSetup-1.2.5.exe" \
  --cert "installer/certs/test_cert.pfx"
```

### 4.4 Linux Bütünlük ve Güvenlik Altyapısı
Linux `.run` paketi için Windows Authenticode kullanılmaz. Bunun yerine:
1. **SHA-256 Checksum:** Dosya bütünlüğü için `.sha256` özeti üretilir.
2. **GPG Detached Signature:** GPG anahtarı mevcutsa zırhlı `.asc` imza dosyası üretilir.

```bash
# SHA-256 Üretimi
sha256sum CounterLoadSetup-1.2.5.run > CounterLoadSetup-1.2.5.run.sha256

# GPG İmzalaması
gpg --batch --yes --detach-sign --armor CounterLoadSetup-1.2.5.run
```

---

## 5. Otomatik Derleme Hattı (Build Automation)

Tüm derleme süreci `build-installer.sh` orkestrasyon betiği tarafından yönetilir. Betik, çalıştığı dizinden bağımsız olarak proje kök dizinini otomatik tespit eder (`SCRIPT_DIR/../..`).

### 5.1 Ana Derleme Betiği Parametreleri (`build-installer.sh`)

| Parametre | Açıklama | Varsayılan Değer |
| :--- | :--- | :--- |
| `--version <sürüm>` | Derlenecek paketin sürüm numarası (**Zorunlu**) | - |
| `--build-windows` | Windows kurulum paketini derler | `false` |
| `--build-linux` | Linux kurulum paketini derler | `false` |
| `--sign-windows` | Windows DLL/EXE dosyalarını `osslsigncode` ile imzalar | `false` |
| `--linux-input <dizin>` | Linux ham ikili girdi dizini | `staging/linux` |
| `--windows-input <dizin>` | Windows ham ikili girdi dizini | `staging/windows` |
| `--output <dizin>` | Çıktıların kaydedileceği dizin | `artifacts` |
| `--cert <sertifika>` | Windows PFX sertifika dosyası yolu | `installer/certs/test_cert.pfx` |
| `--pass <şifre>` | Sertifika parolanız | `123456` |

### 5.2 Dinamik Sürüm Güncelleme (Dynamic Versioning)
`build-installer.sh` betiği çalıştığında, aşağıdaki yapılandırma dosyalarındaki `<Version>` ve `<Title>` etiketlerini anlık olarak günceller:
* `installer/config/config-windows.xml`
* `installer/config/config-linux.xml`
* `installer/packages/com.counterloadapp.main/meta/package.xml`

### 5.3 Windows Kurulum Paketi Derleme Akışı

```bash
./installer/scripts/build-installer.sh \
  --version 1.2.5 \
  --build-windows \
  --sign-windows \
  --cert installer/certs/test_cert.pfx \
  --pass 123456
```

#### İç Çalışma Adımları:
1. `prepare-package.sh` betiği çağrılarak `staging/windows` içindeki dosyalar doğrulanır ve `installer/packages/com.counterloadapp.main/data` altına kopyalanır.
2. `--sign-windows` aktifse, `sign-windows-artifacts.sh` ile data klasöründeki `.exe` ve `.dll` dosyaları imzalanır.
3. Wine ve `Xvfb` (Sanal Ekran) eşliğinde Windows `binarycreator.exe` tetiklenir:
   ```bash
   xvfb-run --auto-servernum --server-args="-screen 0 1024x768x24" \
     wine binarycreator.exe -c installer/config/config-windows.xml \
     -p installer/packages artifacts/windows/CounterLoadSetup-1.2.5.exe
   ```
4. Oluşan final `CounterLoadSetup-1.2.5.exe` tekrar imzalanır ve doğrulanır.

### 5.4 Linux Kurulum Paketi Derleme Akışı

```bash
./installer/scripts/build-installer.sh \
  --version 1.2.5 \
  --build-linux
```

#### İç Çalışma Adımları:
1. `prepare-package.sh` ile `staging/linux` dosyaları paket alanına aktarılır.
2. Native Linux `binarycreator` çalıştırılarak geçici `.bin` dosyası üretilir:
   ```bash
   binarycreator -c installer/config/config-linux.xml \
     -p installer/packages artifacts/linux/CounterLoadSetup-1.2.5.bin
   ```
3. **Hybrid Wrapper Betiği Katmanı:** Üretilen `.bin` binary payload'u, grafik oturum (`DISPLAY`) bulunmadığında CLI moduna düşen özel bir shell wrapper scriptinin arkasına eklenir.
4. `.run` dosyasına çalıştırma izni (`chmod +x`) verilir.
5. `.sha256` ve (varsa) `.asc` imza dosyaları oluşturulur.

### 5.5 Bütünleşik (Windows + Linux) Derleme Komutu

```bash
./installer/scripts/build-installer.sh \
  --version 1.2.5 \
  --build-linux \
  --build-windows \
  --sign-windows
```

---

## 6. İşletim Sistemlerine Göre Kurulum ve Kullanım Senaryoları

### 6.1 Grafik Arayüz (GUI) Ekran Görüntüleri ve Adımları

Bu bölümde Windows ve Linux platformlarında hem **Özel Tema (CounterLoad)** hem de **Light Tema (CounterLoad-Light / Standart Tema)** için kurulum ve kaldırma (MaintenanceTool) sihirbazı ekran görüntüleri sıralanmıştır.

---

#### 6.1.1 Windows - Özel Tema (CounterLoad Standart)

##### A. Kurulum Adımları (Installation Flow)
1. **Welcome (Hoş Geldiniz):**
   ![Windows Özel Tema - Welcome](images/win_custom_install_01_welcome.png)
   *Açıklama: Karşılama ve hoş geldiniz ekranı.*

2. **Device and Network Settings (Cihaz ve Ağ Yapılandırması):**
   ![Windows Özel Tema - Device and Network Settings](images/win_custom_install_02_device_network.png)
   *Açıklama: CLI Auth Service Port, Remote IP ve Serial No yapılandırma ekranı.*

3. **Installation Folder (Kurulum Dizini Seçimi):**
   ![Windows Özel Tema - Installation Folder](images/win_custom_install_03_folder.png)
   *Açıklama: Uygulamanın kurulacağı hedef dizin seçim ekranı.*

4. **Select Components (Bileşen Seçimi):**
   ![Windows Özel Tema - Select Components](images/win_custom_install_04_components.png)
   *Açıklama: Yüklenecek uygulama paket ve bileşen seçim ekranı.*

5. **License Agreement (Lisans Sözleşmesi):**
   ![Windows Özel Tema - License Agreement](images/win_custom_install_05_license.png)
   *Açıklama: Kullanım sözleşmesi kabul ve onay ekranı.*

6. **Ready to Install (Kuruluma Hazır):**
   ![Windows Özel Tema - Ready to Install](images/win_custom_install_06_ready.png)
   *Açıklama: Kurulum öncesi özet ve başlatma ekranı.*

7. **Installing (Kurulum Yapılıyor):**
   ![Windows Özel Tema - Installing](images/win_custom_install_07_installing.png)
   *Açıklama: Dosyaların kopyalanması ve ilerleme çubuğu ekranı.*

8. **Finished (Tamamlandı):**
   ![Windows Özel Tema - Finished](images/win_custom_install_08_finished.png)
   *Açıklama: Kurulumun başarıyla tamamlandığı bitiş ekranı.*

##### B. Kaldırma Adımları (Uninstallation Flow - MaintenanceTool)
1. **Welcome (Kaldırma Hoş Geldiniz):**
   ![Windows Özel Tema - Uninstall Welcome](images/win_custom_uninstall_01_welcome.png)
   *Açıklama: MaintenanceTool kaldırma karşılama ekranı.*

2. **Ready to Uninstall (Kaldırmaya Hazır):**
   ![Windows Özel Tema - Ready to Uninstall](images/win_custom_uninstall_02_ready.png)
   *Açıklama: Kaldırma işlemi onay ekranı.*

3. **Finished (Kaldırma Tamamlandı):**
   ![Windows Özel Tema - Uninstall Finished](images/win_custom_uninstall_03_finished.png)
   *Açıklama: Uygulamanın sistemden başarıyla kaldırıldığı ekran.*

---

#### 6.1.2 Windows - Light Tema (CounterLoad-Light / Standart Tema)

##### A. Kurulum Adımları (Installation Flow)
1. **Welcome (Hoş Geldiniz):**
   ![Windows Light Tema - Welcome](images/win_light_install_01_welcome.png)

2. **Device and Network Settings (Cihaz ve Ağ Yapılandırması):**
   ![Windows Light Tema - Device and Network Settings](images/win_light_install_02_device_network.png)

3. **Installation Folder (Kurulum Dizini Seçimi):**
   ![Windows Light Tema - Installation Folder](images/win_light_install_03_folder.png)

4. **Select Components (Bileşen Seçimi):**
   ![Windows Light Tema - Select Components](images/win_light_install_04_components.png)

5. **License Agreement (Lisans Sözleşmesi):**
   ![Windows Light Tema - License Agreement](images/win_light_install_05_license.png)

6. **Ready to Install (Kuruluma Hazır):**
   ![Windows Light Tema - Ready to Install](images/win_light_install_06_ready.png)

7. **Installing (Kurulum Yapılıyor):**
   ![Windows Light Tema - Installing](images/win_light_install_07_installing.png)

8. **Finished (Tamamlandı):**
   ![Windows Light Tema - Finished](images/win_light_install_08_finished.png)

##### B. Kaldırma Adımları (Uninstallation Flow - MaintenanceTool)
1. **Welcome (Kaldırma Hoş Geldiniz):**
   ![Windows Light Tema - Uninstall Welcome](images/win_light_uninstall_01_welcome.png)

2. **Ready to Uninstall (Kaldırmaya Hazır):**
   ![Windows Light Tema - Ready to Uninstall](images/win_light_uninstall_02_ready.png)

3. **Finished (Kaldırma Tamamlandı):**
   ![Windows Light Tema - Uninstall Finished](images/win_light_uninstall_03_finished.png)

---

#### 6.1.3 Linux - Özel Tema (CounterLoad Standart)

##### A. Kurulum Adımları (Installation Flow)
1. **Welcome (Hoş Geldiniz):**
   ![Linux Özel Tema - Welcome](images/linux_custom_install_01_welcome.png)

2. **Device and Network Settings (Cihaz ve Ağ Yapılandırması):**
   ![Linux Özel Tema - Device and Network Settings](images/linux_custom_install_02_device_network.png)

3. **Installation Folder (Kurulum Dizini Seçimi):**
   ![Linux Özel Tema - Installation Folder](images/linux_custom_install_03_folder.png)

4. **Select Components (Bileşen Seçimi):**
   ![Linux Özel Tema - Select Components](images/linux_custom_install_04_components.png)

5. **License Agreement (Lisans Sözleşmesi):**
   ![Linux Özel Tema - License Agreement](images/linux_custom_install_05_license.png)

6. **Ready to Install (Kuruluma Hazır):**
   ![Linux Özel Tema - Ready to Install](images/linux_custom_install_06_ready.png)

7. **Installing (Kurulum Yapılıyor):**
   ![Linux Özel Tema - Installing](images/linux_custom_install_07_installing.png)

8. **Finished (Tamamlandı):**
   ![Linux Özel Tema - Finished](images/linux_custom_install_08_finished.png)

##### B. Kaldırma Adımları (Uninstallation Flow - MaintenanceTool)
1. **Welcome (Kaldırma Hoş Geldiniz):**
   ![Linux Özel Tema - Uninstall Welcome](images/linux_custom_uninstall_01_welcome.png)

2. **Ready to Uninstall (Kaldırmaya Hazır):**
   ![Linux Özel Tema - Ready to Uninstall](images/linux_custom_uninstall_02_ready.png)

3. **Finished (Kaldırma Tamamlandı):**
   ![Linux Özel Tema - Uninstall Finished](images/linux_custom_uninstall_03_finished.png)

---

#### 6.1.4 Linux - Light Tema (CounterLoad-Light / Standart Tema)

##### A. Kurulum Adımları (Installation Flow)
1. **Welcome (Hoş Geldiniz):**
   ![Linux Light Tema - Welcome](images/linux_light_install_01_welcome.png)

2. **Device and Network Settings (Cihaz ve Ağ Yapılandırması):**
   ![Linux Light Tema - Device and Network Settings](images/linux_light_install_02_device_network.png)

3. **Installation Folder (Kurulum Dizini Seçimi):**
   ![Linux Light Tema - Installation Folder](images/linux_light_install_03_folder.png)

4. **Select Components (Bileşen Seçimi):**
   ![Linux Light Tema - Select Components](images/linux_light_install_04_components.png)

5. **License Agreement (Lisans Sözleşmesi):**
   ![Linux Light Tema - License Agreement](images/linux_light_install_05_license.png)

6. **Ready to Install (Kuruluma Hazır):**
   ![Linux Light Tema - Ready to Install](images/linux_light_install_06_ready.png)

7. **Installing (Kurulum Yapılıyor):**
   ![Linux Light Tema - Installing](images/linux_light_install_07_installing.png)

8. **Finished (Tamamlandı):**
   ![Linux Light Tema - Finished](images/linux_light_install_08_finished.png)

##### B. Kaldırma Adımları (Uninstallation Flow - MaintenanceTool)
1. **Welcome (Kaldırma Hoş Geldiniz):**
   ![Linux Light Tema - Uninstall Welcome](images/linux_light_uninstall_01_welcome.png)

2. **Ready to Uninstall (Kaldırmaya Hazır):**
   ![Linux Light Tema - Ready to Uninstall](images/linux_light_uninstall_02_ready.png)

3. **Finished (Kaldırma Tamamlandı):**
   ![Linux Light Tema - Uninstall Finished](images/linux_light_uninstall_03_finished.png)

---

### 6.2 Komut Satırı (CLI) ve Sessiz Kurulum Senaryoları

#### 6.2.1 Windows Sessiz Kurulum ve Kaldırma
Komut Satırı / PowerShell üzerinden kullanıcı etkileşimi olmadan varsayılan dizine kurulum:

```cmd
CounterLoadSetup-1.2.5.exe install --accept-licenses --confirm-command
```

Özel hedef dizine sessiz kurulum:
```cmd
CounterLoadSetup-1.2.5.exe --root "C:\ÖzelDizin\CounterLoad" install --accept-licenses --confirm-command
```

Windows Sessiz Kaldırma (Silent Uninstall):
```cmd
"C:\Program Files\CounterLoad\maintenancetool.exe" purge --confirm-command
```

---

#### 6.2.2 Linux Sunucu / Headless Kurulum Senaryoları (CLI)

Grafik ekranının (`DISPLAY`) bulunmadığı sunucu veya SSH oturumlarında kurulum:

##### 1. Ekransız İnteraktif CLI Sihirbazı
Herhangi bir parametre verilmeden ekransız ortamda çalıştırıldığında wrapper betik durumu tespit eder ve interaktif terminal sihirbazını başlatır:

```bash
./CounterLoadSetup-1.2.5.run
```
*Terminal Ekranı Örneği:*
```text
=============================================================
     CounterLoad Kurulum Sihirbazı v1.2.5 (CLI Modu)     
=============================================================
Grafiksel oturum (DISPLAY) bulunamadı.
Kurulum komut satırı üzerinden interaktif olarak gerçekleştirilecektir.

Kurulum yapılacak hedef dizin [/home/user/.local/share/CounterLoad]: 
-------------------------------------------------------------
   Cihaz ve Ağ Yapılandırması (Device & Network Settings)   
-------------------------------------------------------------
CLI Auth Service Port [7894]: 
Remote App Port [4444]: 
Remote Management Port [4445]: 
Remote IP [172.17.0.3]: 
Serial No [003]: 
Kurulum başlatılıyor...
```

##### 2. Tam Otomatik Sessiz Kurulum (Silent CLI Install)
CI/CD veya deployment betikleri için hiçbir soru sormadan varsayılan veya özel dizine kurulum:

```bash
# Varsayılan dizine sessiz kurulum (Kullanıcı yetkisiyle ~/.local/share/CounterLoad)
./CounterLoadSetup-1.2.5.run install --accept-licenses --confirm-command

# Sistem geneli / Root yetkisiyle varsayılan dizine kurulum (/opt/CounterLoad)
sudo ./CounterLoadSetup-1.2.5.run install --accept-licenses --confirm-command

# Özel dizine sessiz kurulum
./CounterLoadSetup-1.2.5.run --root "/opt/counterload" install --accept-licenses --confirm-command

# Ekran değişkenleri tamamen temizlenerek sessiz kurulum garantisi
env -u DISPLAY -u WAYLAND_DISPLAY ./CounterLoadSetup-1.2.5.run install --accept-licenses --confirm-command
```

##### 3. Otomatik Güncelleme ve Temizlik (Auto-Purge Mekanizması)
Eğer hedef dizinde önceden yapılmış bir CounterLoad kurulumu varsa, installer çakışmayı önlemek için eski sürümü otomatik olarak temizler (`maintenancetool purge --confirm-command`) ve yeni sürümü üzerine kurar.

##### 4. Linux Sessiz Kaldırma (Silent Uninstall)
```bash
# Kullanıcı seviyesinde kurulum için kaldırma
~/.local/share/CounterLoad/maintenancetool purge --confirm-command

# Root / Sistem geneli kurulum için kaldırma
/opt/CounterLoad/maintenancetool purge --confirm-command

# Ekransız ortamda güvenli kaldırma
env -u DISPLAY -u WAYLAND_DISPLAY ~/.local/share/CounterLoad/maintenancetool purge --confirm-command
```

---

## 7. Cihaz ve Ağ Yapılandırma Yönetimi (Configuration Management)

Kurulum sırasında uygulamaya özel yapılandırma parametreleri toplanır ve saklanır:
* `cliAuthServicePort` (Varsayılan: `7894`)
* `remoteAppPort` (Varsayılan: `4444`)
* `remoteManPort` (Varsayılan: `4445`)
* `remoteIp` (Varsayılan: `172.17.0.3`)
* `serialNo` (Varsayılan: `003`)

### 7.1 Kalıcı Ayar Mekanizması (Persistence Hierarchy)
`installscript.js` içindeki `loadSavedSettings()` ve `saveSettings()` fonksiyonları sayesinde kullanıcının daha önce girdiği ayarlar hafızada tutulur:

1. **Ev Dizini JSON Ayar Dosyası:**
   * **Windows:** `%APPDATA%\CounterLoad\installer_settings.json`
   * **Linux:** `~/.config/CounterLoad/installer_settings.json`
2. **Hedef Dizin INI Dosyası:** `@TargetDir@/config/config.ini`

Kurulum yapıldığında bu değerler otomatik olarak `@TargetDir@/config/config.ini` içerisindeki `[NetworkSettings]` ve `[Device]` bölümlerine işlenir.

### 7.2 Sessiz Kurulumda Parametre Geçme Yöntemleri

#### Yöntem A: Komut Satırı Argümanları Eşliğinde Geçme
```bash
./CounterLoadSetup-1.2.5.run install \
  cliAuthServicePort=8080 \
  remoteIp=192.168.1.100 \
  serialNo=SN-999 \
  --accept-licenses --confirm-command
```

#### Yöntem B: Çevre Değişkenleri (Environment Variables) Eşliğinde Geçme
```bash
export CLI_AUTH_SERVICE_PORT="8080"
export REMOTE_IP="192.168.1.100"
export SERIAL_NO="SN-999"

./CounterLoadSetup-1.2.5.run install --accept-licenses --confirm-command
```

---

## 8. Güvenlik, UAC ve SmartScreen Test Senaryoları

### 8.1 Windows UAC ve Yayıncı Kontrolü
* Sertifikasız EXE dosyaları Windows UAC ekranında kırmızı renkli *"Bilinmeyen Yayıncı (Unknown Publisher)"* uyarısı verir.
* `osslsigncode` ile imzalanmış EXE dosyaları mavi renkli *"Mavimsi/Gri Onaylı Yayıncı: CounterLoad Corporation"* başlığı ile açılır.

### 8.2 Microsoft SmartScreen Test Protokolü
Geçerli bir Authenticode imzası "Unknown Publisher" uyarısını engeller; ancak yeni üretilen sertifikalarda Microsoft SmartScreen itibar uyarısı gösterebilir.

#### Test Adımları:
1. Temiz Windows 10 ve Windows 11 sanal makineleri hazırlanır.
2. Microsoft Edge ve Google Chrome üzerinden `.exe` dosyası indirilir (Mark-of-the-Web etiketi eklenir).
3. Dosya özelliklerinde *"Dijital İmzalar (Digital Signatures)"* sekmesinde sertifika zinciri ve timestamp doğrulanır.
4. Sertifika itibarının artması için yayınlanan artifact'ların tutarlı sertifika ile imzalanmasına devam edilir.

---

## 9. CI/CD Pipeline Entegrasyon Kılavuzu

Linux build sunucusunda veya GitLab CI / GitHub Actions runner üzerinde çalışacak örnek pipeline adımları:

### Örnek GitLab CI Yapılandırması (`.gitlab-ci.yml`)

```yaml
stages:
  - build_installers

build_job:
  stage: build_installers
  image: ubuntu:22.04
  script:
    - apt-get update && apt-get install -y build-essential wine64 xvfb osslsigncode gpg python3
    - chmod +x installer/scripts/*.sh
    - ./installer/scripts/build-installer.sh --version "$CI_COMMIT_TAG" --build-linux --build-windows --sign-windows --cert "$WINDOWS_SIGN_CERT_PATH" --pass "$WINDOWS_SIGN_PASS"
  artifacts:
    name: "CounterLoad-Installers-$CI_COMMIT_TAG"
    paths:
      - artifacts/windows/*.exe
      - artifacts/linux/*.run
      - artifacts/linux/*.sha256
      - artifacts/linux/*.asc
    expire_in: 30 days
  only:
    - tags
```

---

## 10. Tüm Terminal Komutları Özeti (Cheat Sheet)

### Derleme Komutları
```bash
# Sadece Windows Installer Derleme ve İmzalama
./installer/scripts/build-windows-installer.sh --version 1.2.5

# Sadece Linux Installer Derleme
./installer/scripts/build-linux-installer.sh --version 1.2.5

# Her İki Platform İçin Tam Otomatik Derleme ve İmzalama
./installer/scripts/build-installer.sh --version 1.2.5 --build-linux --build-windows --sign-windows
```

### Windows Kurulum & Kaldırma Komutları
```cmd
:: Interaktif GUI Kurulumu
CounterLoadSetup-1.2.5.exe

:: Metin Modu Kurulumu
CounterLoadSetup-1.2.5.exe --mode text

:: Varsayılan Dizine Sessiz Kurulum
CounterLoadSetup-1.2.5.exe install --accept-licenses --confirm-command

:: Özel Dizine Sessiz Kurulum
CounterLoadSetup-1.2.5.exe --root "C:\Programlar\CounterLoad" install --accept-licenses --confirm-command

:: Interaktif Metin Modunda Kaldırma
"C:\Program Files\CounterLoad\maintenancetool.exe" --mode text

:: Sessiz Kaldırma
"C:\Program Files\CounterLoad\maintenancetool.exe" purge --confirm-command
```

### Linux Kurulum & Kaldırma Komutları
```bash
# GUI Kurulumu
chmod +x ./artifacts/linux/CounterLoadSetup-1.2.5.run
./artifacts/linux/CounterLoadSetup-1.2.5.run

# Varsayılan Dizine Sessiz Kurulum
./artifacts/linux/CounterLoadSetup-1.2.5.run install --accept-licenses --confirm-command

# Özel Dizine Sessiz Kurulum
./artifacts/linux/CounterLoadSetup-1.2.5.run --root "/opt/counterload" install --accept-licenses --confirm-command

# Sunucu / Ekransız Ortamda Garanti Sessiz Kurulum
env -u DISPLAY -u WAYLAND_DISPLAY ./artifacts/linux/CounterLoadSetup-1.2.5.run install --accept-licenses --confirm-command

# Sessiz Kaldırma (Kullanıcı Kurulumu)
~/.local/share/CounterLoad/maintenancetool purge --confirm-command

# Sessiz Kaldırma (Root / Sistem Geneli Kurulum)
sudo /opt/CounterLoad/maintenancetool purge --confirm-command

# Ekransız Ortamda Sessiz Kaldırma
env -u DISPLAY -u WAYLAND_DISPLAY ~/.local/share/CounterLoad/maintenancetool purge --confirm-command
```

### Kod İmzalama & Doğrulama Komutları
```bash
# Windows İkililerini İmzala
./installer/scripts/sign-windows-artifacts.sh --cert "installer/certs/test_cert.pfx" --pass "123456" --target "artifacts/windows/CounterLoadSetup-1.2.5.exe"

# Windows İmzalarını Doğrula
./installer/scripts/verify-windows-signatures.sh --target "artifacts/windows/CounterLoadSetup-1.2.5.exe" --cert "installer/certs/test_cert.pfx"

# Linux SHA-256 Doğrulama
cd artifacts/linux && sha256sum -c CounterLoadSetup-1.2.5.run.sha256
```
