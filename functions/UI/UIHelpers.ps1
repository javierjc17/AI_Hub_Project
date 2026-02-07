# UIHelpers.ps1 - Encoded safely to prevent PowerShell parser errors
# Emojis are defined via Unicode to avoid literal encoding issues

$script:icons = @{
    Error   = [char]0x274C
    Info    = [char]0x2139
    Warning = [char]0x26A0
    Wrench  = "$([char]0xD83D)$([char]0xDD27)" # Surrogate pair for 🔧
}

function Show-ToolNotification {
    param($Title, $Message, $Icon = "Information", $Owner = $null)
    $emoji = if ($Icon -eq "Error") { $script:icons.Error } else { $script:icons.Info }
    [void](Show-CustomDialog -Title $Title -Message $Message -Icon $emoji -ShowCancel $false -Owner $Owner)
}

function Show-CustomDialog {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Icon = $([char]0x26A0),
        [bool]$ShowCancel = $true,
        $Owner = $null
    )
    
    try {
        $xamlPath = Join-Path $global:InstallationRoot "xaml\Windows\dialog.xaml"
        $config = $global:config
        
        $dialog = New-AppWindow -XamlPath $xamlPath -Title $Title -Config $config -Owner $Owner
        
        $dialog.FindName("DialogTitle").Text = $Title
        $dialog.FindName("DialogMessage").Text = $Message
        $dialog.FindName("DialogIcon").Text = $Icon
        
        $btnConfirm = $dialog.FindName("BtnConfirm")
        $btnCancel = $dialog.FindName("BtnCancel")
        
        if (-not $ShowCancel) {
            if ($btnCancel) { $btnCancel.Visibility = [System.Windows.Visibility]::Collapsed }
            if ($btnConfirm) { $btnConfirm.Content = "Aceptar" }
        }
        
        $script:dialogResult = $false
        
        if ($btnConfirm) {
            $btnConfirm.Add_Click({
                    $script:dialogResult = $true
                    $dialog.DialogResult = $true
                    $dialog.Close()
                })
        }
        
        if ($btnCancel) {
            $btnCancel.Add_Click({
                    $script:dialogResult = $false
                    $dialog.DialogResult = $false
                    $dialog.Close()
                })
        }
        
        $dialog.Add_KeyDown({
                if ($_.Key -eq "Enter" -and $btnConfirm) { $btnConfirm.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) }
                if ($_.Key -eq "Escape" -and $btnCancel) { $btnCancel.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) }
            })
        
        [void]$dialog.ShowDialog()
        return $script:dialogResult
    }
    catch {
        Write-AppLog -Message "Error en Show-CustomDialog: $_" -Level "ERROR"
        $btnType = if ($ShowCancel) { 4 } else { 0 }
        $res = [System.Windows.MessageBox]::Show($Message, $Title, $btnType)
        return ($res -eq "Yes" -or $res -eq "OK")
    }
}

function New-ToolButton {
    param($Tool, $Category, $Window)
    
    $btnStyle = $null
    if ($null -ne $Window) { 
        try { 
            $btnStyle = $Window.FindResource("ToolButton") 
        }
        catch { 
            Write-AppLog -Message "Estilo ToolButton no encontrado" -Level "WARN" 
        } 
    }

    $btn = New-Object System.Windows.Controls.Button -Property @{
        Style = $btnStyle
        Tag   = @{
            Name     = $Tool.Name
            URL      = $Tool.URL
            Desc     = $Tool.Desc
            Category = $Category
            Icon     = $(if ($Tool.Icon) { $Tool.Icon } else { $script:icons.Wrench })
        }
    }
    
    $stack = New-Object System.Windows.Controls.StackPanel -Property @{
        VerticalAlignment   = [System.Windows.VerticalAlignment]::Center
        HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
    }
    
    try {
        $iconPath = Get-Favicon -URL $Tool.URL -Name $Tool.Name
    }
    catch { 
        $iconPath = $null 
    }
    
    $iconLoaded = $false
    if ($iconPath -and (Test-Path $iconPath)) {
        try {
            $iconImage = New-Object System.Windows.Controls.Image -Property @{
                Width               = 32
                Height              = 32
                HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
                Margin              = "0,0,0,6"
            }
            
            $stream = [System.IO.File]::OpenRead($iconPath)
            $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
            $bitmap.BeginInit()
            $bitmap.StreamSource = $stream
            $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
            $bitmap.EndInit()
            $stream.Close()
            $stream.Dispose()
            
            $iconImage.Source = $bitmap
            [void]$stack.Children.Add($iconImage)
            $iconLoaded = $true
        }
        catch {
            Write-AppLog -Message "Error visualizando icono para $($Tool.Name): $_" -Level "WARN"
        }
    }
    
    if (-not $iconLoaded) {
        $iconBlock = New-Object System.Windows.Controls.TextBlock -Property @{
            Text                = $(if ($Tool.Icon) { $Tool.Icon } else { $script:icons.Wrench })
            FontSize            = 24
            HorizontalAlignment = [System.Windows.HorizontalAlignment]::Center
            Margin              = "0,0,0,6"
        }
        try { $iconBlock.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "GlobalTextBrush") } catch {}
        [void]$stack.Children.Add($iconBlock)
    }
    
    $nameBlock = New-Object System.Windows.Controls.TextBlock -Property @{
        Text          = $Tool.Name
        FontSize      = 11
        FontWeight    = [System.Windows.FontWeights]::Bold
        TextAlignment = [System.Windows.TextAlignment]::Center
        TextWrapping  = [System.Windows.TextWrapping]::Wrap
        Margin        = "4,0"
    }
    $nameBlock.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, "GlobalTextBrush")
    [void]$stack.Children.Add($nameBlock)

    $statusIndicator = New-Object System.Windows.Shapes.Ellipse -Property @{
        Width               = 10
        Height              = 10
        Fill                = [System.Windows.Media.Brushes]::Gray
        HorizontalAlignment = [System.Windows.HorizontalAlignment]::Right
        VerticalAlignment   = [System.Windows.VerticalAlignment]::Top
        Margin              = "0,5,5,0"
        ToolTip             = "Desconocido"
    }

    $grid = New-Object System.Windows.Controls.Grid -Property @{
        HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch
        VerticalAlignment   = [System.Windows.VerticalAlignment]::Stretch
    }
    
    [void]$grid.Children.Add($stack)
    [void]$grid.Children.Add($statusIndicator)
    
    $btn.Content = $grid
    $btn.Tag += @{ StatusIndicator = $statusIndicator }
    
    return $btn
}

function Set-ToolHealthStatus {
    param($Button, $IsOnline)
    $indicator = $Button.Tag.StatusIndicator
    if (-not $indicator) { return }
    if ($IsOnline) { 
        $indicator.Fill = [System.Windows.Media.Brushes]::Green 
        $indicator.ToolTip = "Online" 
    }
    else { 
        $indicator.Fill = [System.Windows.Media.Brushes]::Red 
        $indicator.ToolTip = "Offline" 
    }
}

function Show-InputDialog {
    param(
        [string]$Title,
        [string]$Message,
        [string]$DefaultText = "",
        $Owner = $null
    )
    
    try {
        $xamlPath = Join-Path $global:InstallationRoot "xaml\Windows\input_dialog.xaml"
        $config = $global:config
        
        $dialog = New-AppWindow -XamlPath $xamlPath -Title $Title -Config $config -Owner $Owner
        
        $dialog.FindName("InputTitle").Text = $Title
        $dialog.FindName("InputMessage").Text = $Message
        $txtInput = $dialog.FindName("InputText")
        $txtInput.Text = $DefaultText
        
        $dialog.Add_Loaded({
                $txtInput.Focus()
                $txtInput.SelectAll()
            })
        
        $btnOk = $dialog.FindName("BtnOk")
        $btnCancel = $dialog.FindName("BtnCancel")
        
        $script:inputResult = $null
        
        if ($btnOk) {
            $btnOk.Add_Click({
                    $script:inputResult = $txtInput.Text
                    $dialog.DialogResult = $true
                    $dialog.Close()
                })
        }
        
        if ($btnCancel) {
            $btnCancel.Add_Click({
                    $script:inputResult = $null
                    $dialog.DialogResult = $false
                    $dialog.Close()
                })
        }
        
        if ($txtInput) {
            $txtInput.Add_KeyDown({
                    if ($_.Key -eq "Enter") {
                        $script:inputResult = $txtInput.Text
                        $dialog.DialogResult = $true
                        $dialog.Close()
                    }
                })
        }
        
        [void]$dialog.ShowDialog()
        return $script:inputResult
    }
    catch {
        Write-AppLog -Message "Error mostrando input dialog: $_" -Level "ERROR"
        return $null
    }
}
