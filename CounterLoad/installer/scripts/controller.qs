// CounterLoad GUI Installer Automation Script
// Used by test-installers.sh to automate GUI page clicks via xvfb-run

function Controller() {
    // Constructor
}

Controller.prototype.IntroductionPageCallback = function() {
    console.log("GUI: Introduction Page");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.TargetDirectoryPageCallback = function() {
    console.log("GUI: Target Directory Page");
    var widget = gui.currentPageWidget();
    if (widget) {
        var overrideDir = installer.value("TargetDirUserOverride");
        if (overrideDir !== "") {
            console.log("GUI: Overriding Target Directory to: " + overrideDir);
            widget.TargetDirectoryLineEdit.setText(overrideDir);
        }
    }
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.DynamicConfigPageCallback = function() {
    console.log("GUI: Dynamic Config Page");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.ComponentSelectionPageCallback = function() {
    console.log("GUI: Component Selection Page");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.LicenseAgreementPageCallback = function() {
    console.log("GUI: License Agreement Page");
    // Select the first radio button (Accept license agreement)
    var widget = gui.currentPageWidget();
    if (widget) {
        widget.AcceptLicenseRadioButton.checked = true;
    }
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.StartMenuDirectoryPageCallback = function() {
    console.log("GUI: Start Menu Page");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.ReadyForInstallationPageCallback = function() {
    console.log("GUI: Ready for Installation Page");
    gui.clickButton(buttons.CommitButton); // CommitButton is "Install"
}

Controller.prototype.FinishedPageCallback = function() {
    console.log("GUI: Finished Page");
    // Uncheck "Run program now" check box if present to avoid starting the app
    var widget = gui.currentPageWidget();
    if (widget && widget.RunItCheckBox) {
        widget.RunItCheckBox.checked = false;
    }
    gui.clickButton(buttons.FinishButton);
}
