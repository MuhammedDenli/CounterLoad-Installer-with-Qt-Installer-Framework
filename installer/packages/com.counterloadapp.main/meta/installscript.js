function Component() {
    // Bileşen ilklendirmesi
}

// Dosyalar hedef dizine çıkartıldıktan hemen sonra tetiklenir
Component.prototype.createOperations = function() {
    // QtIFW'nun varsayılan dosya kopyalama operasyonlarını çalıştırıyoruz
    component.createOperations();

    //-------------------------------------------------------------------------
    // WINDOWS KISAYOL OPERASYONLARI (Strictly 3 Arguments)
    //-------------------------------------------------------------------------
    if (systemInfo.productType === "windows") {
        
        // 1. Masaüstü Kısayolu
        // Argümanlar: <target> <link location> <workingDirectory=...>
        component.addOperation("CreateShortcut", 
            "@TargetDir@/CounterLoad.exe", 
            "@DesktopDir@/CounterLoad.lnk",
            "workingDirectory=@TargetDir@"
        );

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
    if (systemInfo.productType === "linux") {
        component.addOperation("CreateShortcut", 
            "@TargetDir@/counterload", 
            "@HomeDir@/Desktop/CounterLoad.desktop",
            "workingDirectory=@TargetDir@"
        );
    }
};
