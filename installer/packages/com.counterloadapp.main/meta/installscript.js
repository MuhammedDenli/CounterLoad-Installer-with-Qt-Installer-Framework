function Component() {
    // Bileşen ilklendirmesi ve kısayol seçim kutusunun eklenmesi
    component.loaded.connect(this, Component.prototype.addShortcutCheckbox);
}

Component.prototype.addShortcutCheckbox = function() {
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
    // QtIFW'nun varsayılan dosya kopyalama operasyonlarını çalıştırıyoruz
    component.createOperations();

    // Kullanıcının masaüstü kısayolu isteyip istemediğini kontrol edelim
    var createDesktopShortcut = true;
    var widget = component.userInterface("ShortcutForm");
    if (widget) {
        createDesktopShortcut = widget.desktopShortcutCheckbox.checked;
    }

    //-------------------------------------------------------------------------
    // WINDOWS KISAYOL OPERASYONLARI (Strictly 3 Arguments)
    //-------------------------------------------------------------------------
    if (systemInfo.productType === "windows") {
        
        // 1. Masaüstü Kısayolu (Opsiyonel)
        // Argümanlar: <target> <link location> <workingDirectory=...>
        if (createDesktopShortcut) {
            component.addOperation("CreateShortcut", 
                "@TargetDir@/CounterLoad.exe", 
                "@DesktopDir@/CounterLoad.lnk",
                "workingDirectory=@TargetDir@"
            );
        }

        // 2. Başlat Menüsü Kısayolu
        component.addOperation("CreateShortcut", 
            "@TargetDir@/CounterLoad.exe", 
            "@StartMenuDir@/CounterLoad.lnk",
            "workingDirectory=@TargetDir@"
        );

        // 3. Uygulamayı Kaldır (MaintenanceTool) Kısayolu
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
