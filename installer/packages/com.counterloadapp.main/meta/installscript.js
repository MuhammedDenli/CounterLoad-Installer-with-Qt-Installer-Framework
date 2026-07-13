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

    // Windows'ta başlangıç yetkisine göre varsayılan dizini ayarla
    if (systemInfo.productType === "windows") {
        var isAdmin = false;
        try {
            isAdmin = installer.hasAdminRights();
        } catch (e) {
            // Eski versiyon uyumluluğu için
        }
        
        if (isAdmin) {
            // Yönetici yetkisi varsa all-users kurulumu ve varsayılan olarak Program Files dizini
            installer.setValue("TargetDir", installer.value("ApplicationsDir") + "/CounterLoad");
            installer.setValue("AllUsers", "true");
        } else {
            // Standart kullanıcı ise per-user kurulumu ve ev dizini
            installer.setValue("TargetDir", installer.value("HomeDir") + "/CounterLoad");
            installer.setValue("AllUsers", "false");
        }
    }
}

Component.prototype.onComponentLoaded = function() {
    if (installer.isInstaller()) {
        installer.addWizardPageItem(component, "ShortcutForm", QInstaller.ReadyForInstallation);
    }
};

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
        // Argümanlar: <target> <link location> <workingDirectory=...>
        if (createDesktopShortcut) {
            component.addOperation("CreateShortcut", 
                "@TargetDir@/CounterLoad.exe", 
                "@DesktopDir@/CounterLoad.lnk",
                "workingDirectory=@TargetDir@"
            );
        }

        // 3. Başlat Menüsü Kısayolu
        component.addOperation("CreateShortcut", 
            "@TargetDir@/CounterLoad.exe", 
            "@StartMenuDir@/CounterLoad.lnk",
            "workingDirectory=@TargetDir@"
        );

        // 4. Uygulamayı Kaldır (MaintenanceTool) Kısayolu
        component.addOperation("CreateShortcut", 
            "@TargetDir@/MaintenanceTool.exe", 
            "@StartMenuDir@/CounterLoad Uygulamasini Kaldir.lnk",
            "workingDirectory=@TargetDir@"
        );
    }
    
    //-------------------------------------------------------------------------
    // LINUX KISAYOL OPERASYONLARI
    //-------------------------------------------------------------------------
    if (systemInfo.kernelType === "linux") {
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

            var desktopFileContent = "Version=1.0\n" +
                                     "Type=Application\n" +
                                     "Terminal=false\n" +
                                     "Exec=@TargetDir@/counterload\n" +
                                     "Name=CounterLoad\n" +
                                     "Path=@TargetDir@";

            component.addOperation("CreateDesktopEntry", 
                desktopPath + "/CounterLoad.desktop",
                desktopFileContent
            );
        }
    }
};
