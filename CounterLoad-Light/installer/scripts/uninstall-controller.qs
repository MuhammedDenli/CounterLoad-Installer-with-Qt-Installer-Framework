// CounterLoad GUI Uninstaller Automation Script
// Used by test-installers.sh to automate GUI page clicks for MaintenanceTool uninstallation

function Controller() {
    // Constructor
}

Controller.prototype.IntroductionPageCallback = function() {
    console.log("GUI Uninstall: Introduction Page");
    var widget = gui.currentPageWidget();
    if (widget) {
        // Select 'Remove all components' radio button if present
        if (widget.RemoveAllComponentsRadioButton) {
            widget.RemoveAllComponentsRadioButton.checked = true;
        }
    }
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.ReadyForInstallationPageCallback = function() {
    console.log("GUI Uninstall: Ready to Uninstall");
    gui.clickButton(buttons.CommitButton);
}

Controller.prototype.FinishedPageCallback = function() {
    console.log("GUI Uninstall: Finished");
    gui.clickButton(buttons.FinishButton);
}
