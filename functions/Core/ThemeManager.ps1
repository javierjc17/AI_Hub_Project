function Set-AppTheme {
    # Wrapper for backward compatibility
    param($Window, $Config)
    Set-ThemeResources -Window $Window -Config $Config
    Set-WindowEffects -Window $Window -Config $Config
}

function Set-ThemeResources {
    param($Window, $Config)
    
    if ($null -eq $Config) { 
        Write-AppLog -Message "Set-ThemeResources: Config es nulo, ignorando tematización." -Level "WARN"
        return 
    }
    
    if (-not $Config.Theme -or -not $Config.Theme.Accent) { return }
    $accent = $Config.Theme.Accent
    
    try {
        # 1. Update Accent Color
        $accentBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($accent)
        $Window.Resources["GlobalAccentBrush"] = $accentBrush

        # 2. Update Mode Colors
        $mode = $Config.Theme.Mode
        if ([string]::IsNullOrWhiteSpace($mode) -or $mode -eq "System") {
            $mode = Get-SystemTheme
        }
        
        $windowAllowsTransparency = $Window.AllowsTransparency
        
        function Get-SolidBrush ($hex) {
            return [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex)
        }

        # --- LÓGICA DE FONDO UNIFICADA (SISTEMA DE PLANTILLA) ---
        # 1. Si la ventana PERMITE transparencia (Diálogos), el fondo debe ser invisible para las esquinas.
        # 2. Si la ventana NO permite transparencia (Principal), DEBE ser sólido para evitar el fondo negro.
        
        $isTransparent = ($Config.Theme.Transparency -eq "True")
        
        if ($mode -eq "Light") {
            # Modo Claro
            if ($windowAllowsTransparency) {
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush "#00000000" # Invisible para diálogos
            } else {
                # MICA FIX: Si la transparencia está activa, el fondo debe ser 'Transparent' real.
                $color = if ($isTransparent) { "#00000000" } else { "#FFF0F2F5" }
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush $color
            }
            
            # PANELES TRASLÚCIDOS: Bajamos el alfa para que Mica se vea
            $panelAlpha = if ($isTransparent) { "#88" } else { "#FF" }
            $secondaryAlpha = if ($isTransparent) { "#44" } else { "#FF" }
            
            $Window.Resources["GlobalPanelBrush"] = Get-SolidBrush "${panelAlpha}F9F5F7"
            $Window.Resources["GlobalSecondaryBrush"] = Get-SolidBrush "${secondaryAlpha}E0E0E0"
            $Window.Resources["GlobalTextBrush"] = Get-SolidBrush "#1A1A1A"
            $Window.Resources["GlobalSubTextBrush"] = Get-SolidBrush "#666666"
            $Window.Resources["GlobalBorderBrush"] = Get-SolidBrush "#25000000"
            $Window.Resources["GlobalPopupBrush"] = Get-SolidBrush "#FFFFFFFF"
        }
        else {
            # Modo Oscuro
            if ($windowAllowsTransparency) {
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush "#00000000"
            }
            else {
                # MICA FIX: Totalmente transparente para permitir el vidrio oscuro Mica
                $color = if ($isTransparent) { "#00000000" } else { "#FF121212" }
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush $color
            }
            
            # PANELES TRASLÚCIDOS (Oscuro)
            $panelAlpha = if ($isTransparent) { "#77" } else { "#FF" }
            $secondaryAlpha = if ($isTransparent) { "#55" } else { "#FF" }
            
            $Window.Resources["GlobalPanelBrush"] = Get-SolidBrush "${panelAlpha}1E1E1E"
            $Window.Resources["GlobalSecondaryBrush"] = Get-SolidBrush "${secondaryAlpha}2C2C2C"
            $Window.Resources["GlobalTextBrush"] = Get-SolidBrush "#FFFFFF"
            $Window.Resources["GlobalSubTextBrush"] = Get-SolidBrush "#CCCCCC"
            $Window.Resources["GlobalBorderBrush"] = Get-SolidBrush "#33FFFFFF"
            $Window.Resources["GlobalPopupBrush"] = Get-SolidBrush "#FF1E1E1E"
        }
        
        # 3. NO FORZAR Background para ventanas con Mica (dejar que XAML lo maneje)
        # Solo aplicar si la ventana usa AllowsTransparency (diálogos)
        if ($windowAllowsTransparency) {
            $Window.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, "GlobalBackgroundBrush")
        }
    }
    catch {
        Write-AppLog -Message "Error setting theme resources: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Set-WindowEffects {
    param($Window, $Config)
    
    # 0. Check for New Helper
    if (-not ("WindowHelperV3" -as [type])) { return }
    
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        if ($hwnd -eq [IntPtr]::Zero) { return }
        
        $mode = $Config.Theme.Mode
        if ([string]::IsNullOrWhiteSpace($mode) -or $mode -eq "System") {
            $mode = Get-SystemTheme
        }
        $isDark = ($mode -ne "Light")
        
        # 1. Native Windows Theme (Caption/Border)
        [WindowHelperV3]::SetWindowTheme($hwnd, $isDark)
        
        # 2. Unified Backdrop / Blur (Windows 10 & 11)
        if ($Config.Theme.Transparency -eq "True" -or $Window.AllowsTransparency) {
             [WindowHelperV3]::ApplyBlur($hwnd, $isDark)
        }
        
        # Also update Quick Launcher if open
        if ($script:QuickLauncherWindow -and $script:QuickLauncherWindow.IsVisible) {
            $qlHwnd = (New-Object System.Windows.Interop.WindowInteropHelper($script:QuickLauncherWindow)).Handle
            [WindowHelperV3]::SetWindowTheme($qlHwnd, $isDark)
            if ($Config.Theme.Transparency -eq "True") {
                 [WindowHelperV3]::ApplyBlur($qlHwnd, $isDark)
            }
        }
    }
    catch { Write-Warning "Theme Sync Error: $_" }
}

# Helper: Detect Windows System Theme (Global)
function Get-SystemTheme {
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $val = Get-ItemProperty -Path $regKey -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
    if ($val -and $val.AppsUseLightTheme -eq 1) { return "Light" }
    return "Dark"
}
