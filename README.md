# CounterLoad Installer Infrastructure with Qt Installer Framework

Cross-platform Windows and Linux installer infrastructure for **CounterLoad** and **CounterLoad-Light**, built with Qt Installer Framework.

[Türkçe](#türkçe) · [English](#english)

> [!WARNING]
> This repository contains self-signed certificates and private keys created for testing. They must never be used for production code signing. Replace them with securely managed production certificates and keep production private keys outside the repository.

---

## Türkçe

### Projenin amacı

Bu proje, CounterLoad uygulamasının Windows ve Linux için dağıtılabilir kurulum paketlerini **tek bir Linux build ortamından** üretmek amacıyla geliştirilmiştir. Qt Installer Framework merkezli yapı; paket hazırlama, sürüm güncelleme, platforma özel yükleyici oluşturma, kod imzalama ve bütünlük doğrulama adımlarını ortak bir otomasyon hattında birleştirir.

Altyapı iki uygulama varyantını destekler:

- **CounterLoad:** Özelleştirilmiş kurulum arayüzüne sahip ana sürüm.
- **CounterLoad-Light:** Daha sade ve standart görünümlü hafif sürüm.

### Elde edilen sonuçlar

Proje sonunda aşağıdaki çıktılar ve çalışma senaryoları sağlanmıştır:

| Sonuç | Açıklama |
| --- | --- |
| Windows yükleyicisi | Linux üzerinde Wine, Xvfb ve QtIFW `binarycreator.exe` kullanılarak `.exe` kurulum paketi üretimi |
| Linux hibrit yükleyicisi | Masaüstünde grafik arayüzü, headless sistemlerde CLI ve sessiz kurulumu destekleyen çalıştırılabilir `.run` paketi |
| Otomatik sürümleme | Yapılandırma ve paket metadata dosyalarındaki sürüm bilgilerinin build sırasında güncellenmesi |
| Windows kod imzalama | Uygulama ikilileri ile nihai yükleyicinin `osslsigncode` kullanılarak Authenticode ile imzalanabilmesi |
| Linux bütünlük doğrulaması | Üretilen `.run` paketi için SHA-256 özeti ve GPG detached signature oluşturulması |
| Yetkiye göre kurulum dizini | Linux'ta standart kullanıcı için `~/.local/share/CounterLoad`, yönetici kurulumu için `/opt/CounterLoad` kullanılması |
| Kurulum yönetimi | QtIFW Maintenance Tool üzerinden kaldırma ve güncelleme senaryolarının desteklenmesi |
| Teknik dokümantasyon | GUI, CLI, headless kurulum, imzalama, doğrulama ve CI/CD kullanımını kapsayan ayrıntılı kılavuz |

Hazır örnek çıktılar her iki varyantın `artifacts/` dizinlerinde bulunur:

```text
CounterLoad/artifacts/
├── linux/
│   ├── CounterLoadSetup-1.2.5.run
│   ├── CounterLoadSetup-1.2.5.run.sha256
│   └── CounterLoadSetup-1.2.5.run.asc
└── windows/
    └── CounterLoadSetup-1.2.5.exe
```

### Sağladığı yararlar

- **Tek merkezden çoklu platform üretimi:** Windows ve Linux yükleyicileri aynı Linux build sunucusunda hazırlanabilir.
- **Tekrarlanabilir otomasyon:** Manuel paketleme adımları betiklerle standartlaştırılır ve insan hatası azaltılır.
- **Masaüstü ve sunucu uyumluluğu:** Aynı Linux paketi GUI, interaktif CLI ve tamamen sessiz kurulum senaryolarını destekler.
- **Daha güvenilir dağıtım:** Windows için Authenticode; Linux için SHA-256 ve GPG doğrulaması sunulur.
- **Tutarlı sürüm yönetimi:** Sürüm numarası paket metadata'sına ve çıktı adlarına otomatik olarak uygulanır.
- **CI/CD entegrasyonuna uygunluk:** Derleme betikleri GitLab CI, GitHub Actions veya benzeri sistemlerden çağrılabilir.
- **Özelleştirilebilir kullanıcı deneyimi:** QtIFW yapılandırmaları, özel UI sayfaları, lisans ekranları, kısayollar ve tema kaynakları değiştirilebilir.
- **Bakım kolaylığı:** Hazırlama, derleme, imzalama ve doğrulama görevleri ayrı ve yeniden kullanılabilir betiklere bölünmüştür.

### Desteklenen kurulum senaryoları

- Windows grafik arayüzlü kurulum
- Windows sessiz/unattended kurulum
- Linux X11 ve Wayland grafik arayüzlü kurulum
- Linux headless interaktif CLI kurulumu
- Linux tamamen sessiz kurulum
- Kullanıcı bazlı veya yönetici yetkili sistem geneli kurulum
- Maintenance Tool ile kaldırma ve güncelleme

### Proje yapısı

```text
.
├── CounterLoad/                 # Özelleştirilmiş ana varyant
│   ├── installer/               # QtIFW config, package, kaynak ve betikleri
│   ├── staging/                 # Paketlenecek ham Linux/Windows ikilileri
│   └── artifacts/               # Üretilmiş kurulum paketleri
├── CounterLoad-Light/           # Standart görünümlü hafif varyant
├── Ekran görüntüleri/           # Kurulum ve test ekran görüntüleri
├── KILAVUZ.md                   # Ayrıntılı Türkçe teknik kılavuz
└── README.md
```

### Hızlı başlangıç

Linux paketini üretmek için:

```bash
cd CounterLoad
./installer/scripts/build-installer.sh \
  --version 1.2.5 \
  --build-linux
```

Windows ve Linux paketlerini birlikte üretmek için:

```bash
cd CounterLoad
./installer/scripts/build-installer.sh \
  --version 1.2.5 \
  --build-windows \
  --build-linux
```

Windows kod imzalamayı etkinleştirmek için komuta aşağıdaki seçenekler eklenebilir:

```bash
--sign-windows --cert /guvenli/yol/code-signing.pfx --pass 'SERTIFIKA_PAROLASI'
```

> Windows cross-build işlemi için Wine, Xvfb ve Qt Installer Framework'ün Windows `binarycreator.exe` aracı gerekir. `build-installer.sh` içindeki araç yolunu kendi ortamınıza göre yapılandırın. Üretim sertifikasını veya parolasını repoya kaydetmeyin; CI/CD secret mekanizması kullanın.

Linux paketini doğrulamak için:

```bash
cd CounterLoad/artifacts/linux
sha256sum -c CounterLoadSetup-1.2.5.run.sha256
gpg --verify CounterLoadSetup-1.2.5.run.asc CounterLoadSetup-1.2.5.run
```

Tüm gereksinimler, derleme seçenekleri, kurulum komutları ve test senaryoları için [KILAVUZ.md](KILAVUZ.md) dosyasını inceleyin.

---

## English

### Project purpose

This project was created to produce distributable CounterLoad installers for Windows and Linux from **a single Linux build environment**. The Qt Installer Framework-based architecture combines package preparation, version updates, platform-specific installer generation, code signing, and integrity verification in one automated pipeline.

The infrastructure supports two application variants:

- **CounterLoad:** The main edition with a customized installer interface.
- **CounterLoad-Light:** A lightweight edition with a simpler, standard appearance.

### Results

The project delivers the following outputs and deployment scenarios:

| Result | Description |
| --- | --- |
| Windows installer | Generates an `.exe` installer on Linux through Wine, Xvfb, and the QtIFW Windows `binarycreator.exe` |
| Hybrid Linux installer | Produces an executable `.run` package with desktop GUI, headless CLI, and unattended installation support |
| Automated versioning | Updates version information in configuration and package metadata during the build |
| Windows code signing | Supports Authenticode signing of application binaries and the final installer with `osslsigncode` |
| Linux integrity verification | Generates a SHA-256 checksum and a detached GPG signature for the `.run` package |
| Privilege-aware destination | Uses `~/.local/share/CounterLoad` for regular Linux users and `/opt/CounterLoad` for administrative installations |
| Installation lifecycle | Supports uninstall and update scenarios through the QtIFW Maintenance Tool |
| Technical documentation | Includes detailed guidance for GUI, CLI, headless installation, signing, verification, and CI/CD usage |

Ready-made example artifacts are available under the `artifacts/` directory of each variant:

```text
CounterLoad/artifacts/
├── linux/
│   ├── CounterLoadSetup-1.2.5.run
│   ├── CounterLoadSetup-1.2.5.run.sha256
│   └── CounterLoadSetup-1.2.5.run.asc
└── windows/
    └── CounterLoadSetup-1.2.5.exe
```

### Benefits

- **Multi-platform builds from one environment:** Windows and Linux installers can be produced on the same Linux build server.
- **Repeatable automation:** Scripts standardize manual packaging steps and reduce human error.
- **Desktop and server compatibility:** The same Linux package supports GUI, interactive CLI, and fully unattended installations.
- **More trustworthy distribution:** Authenticode is available for Windows, while SHA-256 and GPG verification are available for Linux.
- **Consistent version management:** The supplied version is automatically applied to package metadata and output names.
- **CI/CD readiness:** Build scripts can be invoked from GitLab CI, GitHub Actions, or similar systems.
- **Customizable user experience:** QtIFW configurations, custom UI pages, license screens, shortcuts, and theme resources can be adapted.
- **Maintainable structure:** Preparation, building, signing, and verification are separated into reusable scripts.

### Supported installation scenarios

- Windows graphical installation
- Windows silent/unattended installation
- Linux graphical installation on X11 and Wayland
- Linux interactive CLI installation on headless systems
- Fully unattended Linux installation
- Per-user or privileged system-wide installation
- Uninstall and update through the Maintenance Tool

### Repository structure

```text
.
├── CounterLoad/                 # Customized main variant
│   ├── installer/               # QtIFW config, package, resources, and scripts
│   ├── staging/                 # Raw Linux/Windows binaries to be packaged
│   └── artifacts/               # Generated installer packages
├── CounterLoad-Light/           # Lightweight standard-looking variant
├── Ekran görüntüleri/           # Installation and test screenshots
├── KILAVUZ.md                   # Detailed Turkish technical guide
└── README.md
```

### Quick start

To build the Linux package:

```bash
cd CounterLoad
./installer/scripts/build-installer.sh \
  --version 1.2.5 \
  --build-linux
```

To build the Windows and Linux packages together:

```bash
cd CounterLoad
./installer/scripts/build-installer.sh \
  --version 1.2.5 \
  --build-windows \
  --build-linux
```

Add the following options to enable Windows code signing:

```bash
--sign-windows --cert /secure/path/code-signing.pfx --pass 'CERTIFICATE_PASSWORD'
```

> Windows cross-building requires Wine, Xvfb, and the Windows `binarycreator.exe` from Qt Installer Framework. Configure the tool path in `build-installer.sh` for your environment. Never commit a production certificate or password; use your CI/CD secret store instead.

To verify the Linux artifact:

```bash
cd CounterLoad/artifacts/linux
sha256sum -c CounterLoadSetup-1.2.5.run.sha256
gpg --verify CounterLoadSetup-1.2.5.run.asc CounterLoadSetup-1.2.5.run
```

See [KILAVUZ.md](KILAVUZ.md) for complete prerequisites, build options, installation commands, and test scenarios.

