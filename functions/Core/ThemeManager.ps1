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
        # ESTRATEGIA REVISADA: Transparencia REAL para ver Mica
        # - Si Transparency=True: Alfas bajos para efecto visible
        # - Si Transparency=False: Sólido total
        
        $isTransparent = ($Config.Theme.Transparency -eq "True")
        
        if ($mode -eq "Light") {
            # Modo Claro
            if ($windowAllowsTransparency) {
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush "#00000000" # Invisible para diálogos
            } else {
                # Transparencia REAL para Mica o sólido
                $color = if ($isTransparent) { "#88F0F2F5" } else { "#FFF0F2F5" }
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush $color
            }
            
            # Paneles con transparencia visible
            $panelAlpha = if ($isTransparent) { "#BB" } else { "#FF" }
            $secondaryAlpha = if ($isTransparent) { "#99" } else { "#FF" }
            
            $Window.Resources["GlobalPanelBrush"] = Get-SolidBrush "${panelAlpha}F5F7FA"
            $Window.Resources["GlobalSecondaryBrush"] = Get-SolidBrush "${secondaryAlpha}E8E8E8"
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
                # Transparencia REAL para Mica oscuro
                $color = if ($isTransparent) { "#881A1A1A" } else { "#FF1A1A1A" }
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush $color
            }
            
            # Paneles oscuros traslúcidos
            $panelAlpha = if ($isTransparent) { "#BB" } else { "#FF" }
            $secondaryAlpha = if ($isTransparent) { "#99" } else { "#FF" }
            
            $Window.Resources["GlobalPanelBrush"] = Get-SolidBrush "${panelAlpha}252525"
            $Window.Resources["GlobalSecondaryBrush"] = Get-SolidBrush "${secondaryAlpha}333333"
            $Window.Resources["GlobalTextBrush"] = Get-SolidBrush "#FFFFFF"
            $Window.Resources["GlobalSubTextBrush"] = Get-SolidBrush "#CCCCCC"
            $Window.Resources["GlobalBorderBrush"] = Get-SolidBrush "#33FFFFFF"
            $Window.Resources["GlobalPopupBrush"] = Get-SolidBrush "#FF2A2A2A"
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
