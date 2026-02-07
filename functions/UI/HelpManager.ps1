function Show-HelpWindow {
    param($OwnerWindow)

    $xamlPath = Join-Path $global:InstallationRoot "xaml\Windows\help.xaml"
    $window = New-AppWindow -XamlPath $xamlPath -Title "Ayuda y Guía - AI Hub" -Config $global:config -Owner $OwnerWindow
    
    # Close Button Logic
    $btnClose = $window.FindName("BtnCloseHelp")
    if ($btnClose) {
        $btnClose.Add_Click({
                $window.Close()
            })
    }

    [void]$window.ShowDialog()
}
