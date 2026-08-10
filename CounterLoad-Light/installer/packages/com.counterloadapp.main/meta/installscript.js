function Component() {
    // Bileşen ilklendirmesi ve kısayol seçim kutusunun eklenmesi
    component.loaded.connect(this, Component.prototype.onComponentLoaded);

    // Mevcut dizinin üzerine yazılması (Güncelleme) uyarısını otomatik olarak "Evet" ile geç
    try {
        installer.setMessageBoxAutomaticAnswer("OverwriteTargetDirectory", QMessageBox.Yes);
    } catch (e) {
        // Eski versiyon uyumluluğu için
    }

    // Kurulum sırasında hedef dizin kontrolünü bypass etmek için RemoveTargetDir'i false yapalım.
    // Kaldırma esnasında ise dizini temizlemek için true yaparız.
    try {
        if (installer.isInstaller()) {
            installer.setValue("RemoveTargetDir", "false");
        } else if (installer.isUninstaller()) {
            installer.setValue("RemoveTargetDir", "true");
        }
    } catch (e) {
        // Tolerans
    }

    // Windows ve Linux'ta başlangıç yetkisine göre varsayılan dizini ayarla
    var isAdmin = false;
    try {
        isAdmin = installer.hasAdminRights();
    } catch (e) {
        // Eski versiyon uyumluluğu için
    }

    if (systemInfo.productType === "windows") {
        if (isAdmin) {
            // Yönetici yetkisi varsa all-users kurulumu ve varsayılan olarak Program Files dizini
            installer.setValue("TargetDir", installer.value("ApplicationsDir") + "/CounterLoad");
            installer.setValue("AllUsers", "true");
        } else {
            // Standart kullanıcı ise per-user kurulumu ve ev dizini
            installer.setValue("TargetDir", installer.value("HomeDir") + "/CounterLoad");
            installer.setValue("AllUsers", "false");
        }
    } else if (systemInfo.kernelType === "linux") {
        if (isAdmin) {
            // Root/Sudo yetkisi varsa Linux FHS standardı olarak /opt/CounterLoad
            installer.setValue("TargetDir", "/opt/CounterLoad");
            installer.setValue("AllUsers", "true");
        } else {
            // Standart kullanıcı için XDG standardı olarak ~/.local/share/CounterLoad
            installer.setValue("TargetDir", installer.value("HomeDir") + "/.local/share/CounterLoad");
            installer.setValue("AllUsers", "false");
        }
    }

    // Lisans sözleşmesi sayfasının alt başlığını (description/subtitle) iki satır halinde göstermek için dinamik güncelleme
    try {
        installer.currentPageChanged.connect(function(pageId) {
            try {
                var page = gui.currentPageWidget();
                if (page && page.objectName === "LicenseAgreementPage") {
                    var lang = installer.value("Language") || "";
                    if (lang.indexOf("tr") === 0) {
                        page.subTitle = "<html><center>Lütfen kurulum işlemine devam etmeden önce<br>aşağıdaki lisans sözleşmesini dikkatlice okuyun.</center></html>";
                    } else {
                        page.subTitle = "<html><center>Please read the following license agreement carefully<br>before continuing with the installation.</center></html>";
                    }
                }
            } catch (err) {
                // Tolerans
            }
        });

        // Cihaz ve Ağ Yapılandırması Sayfası için Kalıcı Ayarlar ve Sayfa Geçiş Takibi
        installer.currentPageChanged.connect(function(pageId) {
            try {
                var page = gui.currentPageWidget();
                if (!page) return;
                var pageName = "";
                try { pageName = page.objectName; } catch(e) {}
                // Yalnızca ConfigPage gösterildiğinde çalıştır
                if (pageName.indexOf("ConfigPage") === -1 && pageName.indexOf("DynamicConfigPage") === -1) return;

                var widget = getConfigPageWidget();
                if (widget) {
                    var saved = loadSavedSettings();
                    setLineEditText(widget, "cliAuthServicePortLineEdit", saved.cliAuthServicePort);
                    setLineEditText(widget, "remoteAppPortLineEdit", saved.remoteAppPort);
                    setLineEditText(widget, "remoteManPortLineEdit", saved.remoteManPort);
                    setLineEditText(widget, "remoteIpLineEdit", saved.remoteIp);
                    setLineEditText(widget, "serialNoLineEdit", saved.serialNo);
                    attachConfigPageListeners(widget);
                }
            } catch (err) {
                // Tolerans
            }
        });
    } catch (e) {
        // Tolerans
    }
}

Component.prototype.onComponentLoaded = function() {
    if (installer.isInstaller()) {
        // Özel wizard sayfalarını kaydet
        installer.addWizardPageItem(component, "ShortcutForm", QInstaller.ReadyForInstallation);
        installer.addWizardPage(component, "ConfigPage", QInstaller.TargetDirectory);
    }
};

Component.prototype.DynamicConfigPageCallback = function() {
    var widget = getConfigPageWidget();
    if (widget) {
        var saved = loadSavedSettings();
        setLineEditText(widget, "cliAuthServicePortLineEdit", saved.cliAuthServicePort);
        setLineEditText(widget, "remoteAppPortLineEdit", saved.remoteAppPort);
        setLineEditText(widget, "remoteManPortLineEdit", saved.remoteManPort);
        setLineEditText(widget, "remoteIpLineEdit", saved.remoteIp);
        setLineEditText(widget, "serialNoLineEdit", saved.serialNo);
        attachConfigPageListeners(widget);
    }
};

Component.prototype.ConfigPageCallback = Component.prototype.DynamicConfigPageCallback;

function getConfigPageWidget() {
    try {
        var widget = component.userInterface("ConfigPage");
        if (widget) return widget;
    } catch (e) {}
    try {
        var page = gui.pageWidgetByObjectName("DynamicConfigPage") || gui.pageWidgetByObjectName("ConfigPage");
        if (page) return page;
    } catch (e) {}
    return null;
}

function getLineEdit(widget, name) {
    if (!widget) widget = getConfigPageWidget();
    if (!widget) return null;
    try {
        if (widget[name]) return widget[name];
    } catch (e) {}
    try {
        if (typeof widget.findChild === "function") {
            var child = widget.findChild(name);
            if (child) return child;
        }
    } catch (e) {}
    return null;
}

function setLineEditText(widget, name, val) {
    if (val === undefined || val === null) return;
    if (!widget) widget = getConfigPageWidget();
    if (!widget) return;
    try {
        var le = getLineEdit(widget, name);
        if (le) {
            var strVal = val.toString();
            if (typeof le.setText === "function") {
                le.setText(strVal);
            }
            le.text = strVal;
        }
    } catch (e) {}
}

function getLineEditText(widget, name) {
    if (!widget) widget = getConfigPageWidget();
    if (!widget) return "";
    try {
        var le = getLineEdit(widget, name);
        if (le) {
            if (typeof le.text === "string" && le.text.length > 0) return le.text;
            if (typeof le.text === "function") return le.text();
            if (le.plainText) return le.plainText;
        }
    } catch (e) {}
    return "";
}

function attachConfigPageListeners(widget) {
    if (!widget) widget = getConfigPageWidget();
    if (!widget || widget._listenersAttached) return;
    widget._listenersAttached = true;

    var fields = [
        { name: "cliAuthServicePortLineEdit", key: "cliAuthServicePort" },
        { name: "remoteAppPortLineEdit", key: "remoteAppPort" },
        { name: "remoteManPortLineEdit", key: "remoteManPort" },
        { name: "remoteIpLineEdit", key: "remoteIp" },
        { name: "serialNoLineEdit", key: "serialNo" }
    ];

    for (var i = 0; i < fields.length; i++) {
        (function(item) {
            var le = getLineEdit(widget, item.name);
            if (le) {
                var handler = function() {
                    var val = getLineEditText(widget, item.name);
                    if (val) {
                        installer.setValue(item.key, val);
                        var current = loadSavedSettings();
                        current[item.key] = val;
                        saveSettings(current);
                    }
                };

                try { le.textChanged.connect(handler); } catch (e) {}
                try { le.editingFinished.connect(handler); } catch (e) {}
            }
        })(fields[i]);
    }
}

function getSettingsFilePath() {
    if (systemInfo.productType === "windows") {
        var appData = installer.environmentVariable("APPDATA") || installer.value("UserAppDataOnly") || (installer.environmentVariable("USERPROFILE") + "/AppData/Roaming") || (installer.value("HomeDir") + "/AppData/Roaming");
        appData = appData.replace(/\\/g, "/");
        return appData + "/CounterLoad/installer_settings.json";
    } else {
        var home = installer.value("HomeDir");
        return home + "/.config/CounterLoad/installer_settings.json";
    }
}

function readFileViaShell(filePath) {
    try {
        if (systemInfo.productType === "windows") {
            var winPath = filePath.replace(/\//g, "\\");
            var result = installer.execute("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command",
                "$p = '" + winPath.replace(/'/g, "''") + "'; " +
                "if (-not (Test-Path -LiteralPath $p)) { $p = Join-Path $env:APPDATA 'CounterLoad\\installer_settings.json' }; " +
                "if (Test-Path -LiteralPath $p) { [System.IO.File]::ReadAllText($p, [System.Text.Encoding]::UTF8) } else { Write-Output '' }"
            ]);
            if (result && result.length > 0 && result[0]) {
                return result[0].replace(/^\s+|\s+$/g, '');
            }
        } else {
            var result = installer.execute("sh", ["-c",
                "if [ -f \"" + filePath + "\" ]; then cat \"" + filePath + "\"; fi"
            ]);
            if (result && result.length > 0 && result[0]) {
                return result[0].replace(/^\s+|\s+$/g, '');
            }
        }
    } catch (e) {}
    return "";
}

function loadSavedSettings() {
    var data = {
        cliAuthServicePort: "7894",
        remoteAppPort: "4444",
        remoteManPort: "4445",
        remoteIp: "172.17.0.3",
        serialNo: "003"
    };

    // 1. Öncelik: Kullanıcının ev dizinindeki kalıcı ayar dosyası (JSON)
    try {
        var userSettingsPath = getSettingsFilePath();
        var content = readFileViaShell(userSettingsPath);
        if (content && content.length > 2 && content.charAt(0) === '{') {
            var parsed = JSON.parse(content);
            if (parsed.cliAuthServicePort) data.cliAuthServicePort = parsed.cliAuthServicePort;
            if (parsed.remoteAppPort) data.remoteAppPort = parsed.remoteAppPort;
            if (parsed.remoteManPort) data.remoteManPort = parsed.remoteManPort;
            if (parsed.remoteIp) data.remoteIp = parsed.remoteIp;
            if (parsed.serialNo) data.serialNo = parsed.serialNo;
            return data;
        }
    } catch (e) {}

    // 2. Yedek: Hedef dizindeki config.ini dosyası
    try {
        var targetDir = installer.value("TargetDir");
        if (targetDir) {
            var targetIni = targetDir + "/config/config.ini";
            var iniContent = readFileViaShell(targetIni);
            if (iniContent && iniContent.length > 0) {
                var m1 = iniContent.match(/cliAuthServicePort\s*=\s*(.+)/);
                if (m1 && m1[1]) data.cliAuthServicePort = m1[1].trim();
                var m2 = iniContent.match(/remoteAppPort\s*=\s*(.+)/);
                if (m2 && m2[1]) data.remoteAppPort = m2[1].trim();
                var m3 = iniContent.match(/remoteManPort\s*=\s*(.+)/);
                if (m3 && m3[1]) data.remoteManPort = m3[1].trim();
                var m4 = iniContent.match(/remoteIp\s*=\s*(.+)/);
                if (m4 && m4[1]) data.remoteIp = m4[1].trim();
                var m5 = iniContent.match(/serialNo\s*=\s*(.+)/);
                if (m5 && m5[1]) data.serialNo = m5[1].trim();
            }
        }
    } catch (e) {}

    return data;
}

function saveSettings(data) {
    if (!data) return;
    try {
        var userSettingsPath = getSettingsFilePath();
        var dirPath = userSettingsPath.substring(0, userSettingsPath.lastIndexOf("/"));
        var jsonStr = JSON.stringify(data);

        if (systemInfo.productType === "windows") {
            var winFile = userSettingsPath.replace(/\//g, "\\");
            var script = "$p = '" + winFile.replace(/'/g, "''") + "'; " +
                         "$dir = [System.IO.Path]::GetDirectoryName($p); " +
                         "if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }; " +
                         "[System.IO.File]::WriteAllText($p, '" + jsonStr.replace(/'/g, "''") + "', [System.Text.Encoding]::UTF8); " +
                         "$appDataP = Join-Path $env:APPDATA 'CounterLoad\\installer_settings.json'; " +
                         "$appDataDir = [System.IO.Path]::GetDirectoryName($appDataP); " +
                         "if (-not (Test-Path -LiteralPath $appDataDir)) { New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null }; " +
                         "[System.IO.File]::WriteAllText($appDataP, '" + jsonStr.replace(/'/g, "''") + "', [System.Text.Encoding]::UTF8);";
            installer.execute("powershell", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", script]);
        } else {
            installer.execute("mkdir", ["-p", dirPath]);
            installer.execute("sh", ["-c", "printf '%s' '" + jsonStr.replace(/'/g, "'\\''" ) + "' > \"" + userSettingsPath + "\""]);
            installer.execute("sync", []);
        }
    } catch (e) {}
}

function decodeUtf8(str) {
    try {
        return decodeURIComponent(escape(str));
    } catch (e) {
        return str;
    }
}

// Dosyalar hedef dizine çıkartıldıktan hemen sonra tetiklenir
Component.prototype.createOperations = function() {
    // 0. Çalışan Uygulama Kontrolü (Güncelleme sırasında kilitlenmeyi önler)
    var appName = (systemInfo.productType === "windows") ? "CounterLoad.exe" : "counterload";
    
    var isSilent = false;
    try {
        isSilent = gui.isSilent();
    } catch (e) {
        isSilent = true;
    }

    if (installer.isProcessRunning(appName)) {
        if (isSilent) {
            // Sessiz kurulumda uygulamayı otomatik sonlandır
            try {
                if (systemInfo.productType === "windows") {
                    installer.execute("taskkill", ["/F", "/IM", appName]);
                    // Kısa bir bekleme (ping hilesi ile 1 saniye)
                    installer.execute("ping", ["127.0.0.1", "-n", "2"]);
                } else {
                    installer.execute("killall", ["-9", appName]);
                    installer.execute("sleep", ["1"]);
                }
            } catch (e) {
                // Hata durumunda yoksay
            }

            if (installer.isProcessRunning(appName)) {
                throw new Error("Uygulama arka planda sonlandırılamadı. Kurulum iptal ediliyor.");
            }
        } else {
            // GUI kurulumunda kullanıcıyı uyar
            var checkCount = 0;
            while (installer.isProcessRunning(appName)) {
                checkCount++;
                if (checkCount > 10) {
                    throw new Error("Uygulama çalışmaya devam ettiği için kurulum zaman aşımına uğradı ve iptal edildi.");
                }
                
                var result = QMessageBox.warning(
                    "app.running.warning",
                    "Kurulum Hatası",
                    "CounterLoad uygulaması şu anda çalışıyor. Lütfen güncellemeye devam etmeden önce uygulamayı kapatın.",
                    QMessageBox.Ok | QMessageBox.Cancel,
                    QMessageBox.Ok
                );
                
                if (result === QMessageBox.Cancel) {
                    throw new Error("Kullanıcı uygulamayı kapatmadığı için kurulum iptal edildi.");
                }
            }
        }
    }

    // QtIFW'nun varsayılan dosya kopyalama operasyonlarını çalıştırıyoruz
    component.createOperations();

    // Cihaz ve Ağ Yapılandırma Bilgilerinin Alınması, Kaydedilmesi ve Dosyaya Yazılması
    var saved = loadSavedSettings();
    var cliAuthServicePort = installer.value("cliAuthServicePort") || saved.cliAuthServicePort;
    var remoteAppPort = installer.value("remoteAppPort") || saved.remoteAppPort;
    var remoteManPort = installer.value("remoteManPort") || saved.remoteManPort;
    var remoteIp = installer.value("remoteIp") || saved.remoteIp;
    var serialNo = installer.value("serialNo") || saved.serialNo;

    // 2. Eğer GUI aktifse, kullanıcının arayüze girdiklerini alalım
    try {
        var configWidget = gui.pageWidgetByObjectName("DynamicConfigPage") || gui.pageWidgetByObjectName("ConfigPage") || component.userInterface("ConfigPage");
        if (configWidget) {
            var v1 = getLineEditText(configWidget, "cliAuthServicePortLineEdit");
            var v2 = getLineEditText(configWidget, "remoteAppPortLineEdit");
            var v3 = getLineEditText(configWidget, "remoteManPortLineEdit");
            var v4 = getLineEditText(configWidget, "remoteIpLineEdit");
            var v5 = getLineEditText(configWidget, "serialNoLineEdit");

            if (v1) cliAuthServicePort = v1;
            if (v2) remoteAppPort = v2;
            if (v3) remoteManPort = v3;
            if (v4) remoteIp = v4;
            if (v5) serialNo = v5;
        }
    } catch (e) {
        // Arayüz yüklenmediyse (sessiz mod) yoksay
    }

    // 3. Komut satırından (cliAuthServicePort=xxx) veya PowerShell Ortam Değişkenlerinden ($env:cliAuthServicePort="xxx") gelen değerler
    try {
        var envCliAuthServicePort = installer.value("cliAuthServicePort") || installer.value("CLI_AUTH_SERVICE_PORT") || installer.environmentVariable("cliAuthServicePort") || installer.environmentVariable("CLI_AUTH_SERVICE_PORT");
        var envRemoteAppPort = installer.value("remoteAppPort") || installer.value("REMOTE_APP_PORT") || installer.environmentVariable("remoteAppPort") || installer.environmentVariable("REMOTE_APP_PORT");
        var envRemoteManPort = installer.value("remoteManPort") || installer.value("REMOTE_MAN_PORT") || installer.environmentVariable("remoteManPort") || installer.environmentVariable("REMOTE_MAN_PORT");
        var envRemoteIp = installer.value("remoteIp") || installer.value("REMOTE_IP") || installer.environmentVariable("remoteIp") || installer.environmentVariable("REMOTE_IP");
        var envSerialNo = installer.value("serialNo") || installer.value("SERIAL_NO") || installer.environmentVariable("serialNo") || installer.environmentVariable("SERIAL_NO");

        if (envCliAuthServicePort) cliAuthServicePort = envCliAuthServicePort;
        if (envRemoteAppPort) remoteAppPort = envRemoteAppPort;
        if (envRemoteManPort) remoteManPort = envRemoteManPort;
        if (envRemoteIp) remoteIp = envRemoteIp;
        if (envSerialNo) serialNo = envSerialNo;
    } catch (e) {
        // Yoksay
    }

    // 4. Güncel değerleri saklayalım
    saveSettings({
        cliAuthServicePort: cliAuthServicePort,
        remoteAppPort: remoteAppPort,
        remoteManPort: remoteManPort,
        remoteIp: remoteIp,
        serialNo: serialNo
    });

    // Hedef config dizinini oluşturup Settings operasyonu ile değerleri INI dosyasına yazalım
    component.addOperation("Mkdir", "@TargetDir@/config");
    var iniPathArg = "path=" + installer.value("TargetDir") + "/config/config.ini";

    component.addOperation("Settings", iniPathArg, "method=set", "key=NetworkSettings/cliAuthServicePort", "value=" + cliAuthServicePort);
    component.addOperation("Settings", iniPathArg, "method=set", "key=NetworkSettings/remoteAppPort", "value=" + remoteAppPort);
    component.addOperation("Settings", iniPathArg, "method=set", "key=NetworkSettings/remoteManPort", "value=" + remoteManPort);
    component.addOperation("Settings", iniPathArg, "method=set", "key=NetworkSettings/remoteIp", "value=" + remoteIp);
    component.addOperation("Settings", iniPathArg, "method=set", "key=Device/serialNo", "value=" + serialNo);
    component.addOperation("Settings", iniPathArg, "method=set", "key=Mode/mode", "value=Elit");
    component.addOperation("Settings", iniPathArg, "method=set", "key=general/logLevel", "value=2");
    component.addOperation("Settings", iniPathArg, "method=set", "key=general/logMaxFileCount", "value=500");
    component.addOperation("Settings", iniPathArg, "method=set", "key=general/logMaxFileSize", "value=50");

    // Kullanıcının masaüstü kısayolu isteyip istemediğini kontrol edelim
    var createDesktopShortcut = true;
    try {
        var widget = component.userInterface("ShortcutForm");
        if (widget) {
            createDesktopShortcut = widget.desktopShortcutCheckbox.checked;
        }
    } catch (e) {
        // Sessiz (silent/unattended) kurulumda GUI sınıfları yüklenmediği için
        // component.userInterface QWidget* tipiyle ilgili hata fırlatabilir.
        // Bu durumda varsayılan olarak kısayol oluşturulacaktır.
        createDesktopShortcut = true;
    }

    //-------------------------------------------------------------------------
    // WINDOWS KISAYOL VE REGISTRY OPERASYONLARI
    //-------------------------------------------------------------------------
    if (systemInfo.productType === "windows") {
        
        // Eğer kullanıcı korumalı bir dizin seçtiyse ve admin değilse, UAC yükseltmesi isteyelim
        var targetDir = installer.value("TargetDir");
        var appsDir = installer.value("ApplicationsDir");
        if (!installer.hasAdminRights() && 
            (targetDir.indexOf(appsDir) !== -1 || 
             targetDir.indexOf("Program Files") !== -1 || 
             targetDir.indexOf("C:\\Windows") !== -1)) {
            
            try {
                if (installer.gainAdminRights()) {
                    installer.setValue("AllUsers", "true");
                }
            } catch (e) {
                // Hata durumunda devam et, dosya kopyalama aşaması doğal olarak hata fırlatacaktır
            }
        }

        // Yetki durumuna göre Registry kökünü seçelim (Admin ise HKLM, değilse HKCU)
        var registryRoot = "HKEY_CURRENT_USER";
        if (installer.hasAdminRights()) {
            registryRoot = "HKEY_LOCAL_MACHINE";
        }

        // 1. Registry Değerlerini Yazma (Kurulum yolu, sürüm ve yayıncı)
        var opType = (registryRoot === "HKEY_LOCAL_MACHINE") ? "addElevatedOperation" : "addOperation";
        component[opType]("Execute", "reg", "ADD", registryRoot + "\\Software\\CounterLoad", "/v", "InstallDir", "/t", "REG_SZ", "/d", targetDir, "/f", 
            "UNDOEXECUTE", "reg", "DELETE", registryRoot + "\\Software\\CounterLoad", "/f");
        component[opType]("Execute", "reg", "ADD", registryRoot + "\\Software\\CounterLoad", "/v", "Version", "/t", "REG_SZ", "/d", installer.value("Version"), "/f");
        component[opType]("Execute", "reg", "ADD", registryRoot + "\\Software\\CounterLoad", "/v", "Publisher", "/t", "REG_SZ", "/d", "CounterLoad Corporation", "/f");

        // 2. Masaüstü Kısayolu (Opsiyonel)
        if (createDesktopShortcut) {
            component.addOperation("CreateShortcut", 
                "@TargetDir@/CounterLoad.exe", 
                "@DesktopDir@/CounterLoad.lnk",
                "workingDirectory=@TargetDir@",
                "iconPath=@TargetDir@\\resources\\icons\\counterload.ico"
            );
        }

        // 3. Başlat Menüsü Kısayolu
        component.addOperation("CreateShortcut", 
            "@TargetDir@/CounterLoad.exe", 
            "@StartMenuDir@/CounterLoad.lnk",
            "workingDirectory=@TargetDir@",
            "iconPath=@TargetDir@\\resources\\icons\\counterload.ico"
        );

        // 4. Uygulamayı Kaldır (MaintenanceTool) Kısayolu
        component.addOperation("CreateShortcut", 
            "@TargetDir@/MaintenanceTool.exe", 
            "@StartMenuDir@/CounterLoad Uygulamasini Kaldir.lnk",
            "workingDirectory=@TargetDir@",
            "iconPath=@TargetDir@\\resources\\icons\\counterload.ico"
        );
    }
    
    //-------------------------------------------------------------------------
    // LINUX KISAYOL OPERASYONLARI
    //-------------------------------------------------------------------------
    if (systemInfo.kernelType === "linux") {
        // Ana uygulama binary dosyasına çalıştırma izni verelim
        component.addOperation("Execute", "chmod", "+x", "@TargetDir@/counterload");

        var isAdmin = false;
        try {
            isAdmin = installer.hasAdminRights();
        } catch (e) {
            isAdmin = false;
        }

        var desktopFileContent = "Version=1.0\n" +
                                 "Type=Application\n" +
                                 "Terminal=false\n" +
                                 "Exec=gnome-terminal -- @TargetDir@/counterload\n" +
                                 "Name=CounterLoad\n" +
                                 "Icon=@TargetDir@/resources/icons/counterload.png\n" +
                                 "Path=@TargetDir@";

        if (isAdmin) {
            // Root (Sistem geneli) kurulum: Uygulama menüsüne (launcher) ekleyelim
            component.addOperation("CreateDesktopEntry", 
                "/usr/share/applications/CounterLoad.desktop",
                desktopFileContent
            );
        } else {
            // Kullanıcı seviyesinde kurulum: Masaüstüne ekleyelim (Eğer seçildiyse)
            if (createDesktopShortcut) {
                var desktopPath = installer.value("HomeDir") + "/Desktop";
                try {
                    var result = installer.execute("xdg-user-dir", ["DESKTOP"]);
                    if (result && result[1] === 0) {
                        var path = result[0].replace(/^\s+|\s+$/g, '');
                        path = decodeUtf8(path);
                        if (path) {
                            desktopPath = path;
                        }
                    }
                } catch (e) {
                    // Hata durumunda varsayılan yoldan devam edelim
                }

                // Hedef dizinin var olduğundan emin olalım (Desktop klasörü yoksa oluşturulsun)
                component.addOperation("Execute", "mkdir", "-p", desktopPath);

                component.addOperation("CreateDesktopEntry", 
                    desktopPath + "/CounterLoad.desktop",
                    desktopFileContent
                );

                // Masaüstü kısayoluna çalıştırma izni verelim
                component.addOperation("Execute", "chmod", "+x", desktopPath + "/CounterLoad.desktop");

                // GNOME için kısayolu güvenilir olarak işaretleyelim (simge hemen yüklenir)
                component.addOperation("Execute", "sh", "-c", "gio set \"" + desktopPath + "/CounterLoad.desktop\" metadata::trusted true || true");
            }

            // Ayrıca kullanıcının yerel uygulama menüsüne de ekleyelim (böylece sistem aramasında çıkar)
            var userMenuPath = installer.value("HomeDir") + "/.local/share/applications";
            component.addOperation("Execute", "mkdir", "-p", userMenuPath);
            component.addOperation("CreateDesktopEntry", 
                userMenuPath + "/CounterLoad.desktop",
                desktopFileContent
            );
        }
    }
};

