function Set-AppTheme {
    # Wrapper for backward compatibility
    param($Window, $Config)
    Set-ThemeResources -Window $Window -Config $Config
    
    # Try to set effects if HWND is ready (will fail silently if not showed yet)
    if ("WindowHelperV2" -as [type]) {
        try {
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
            if ($hwnd -ne [IntPtr]::Zero) {
                Set-WindowEffects -Window $Window -Config $Config
            }
        }
        catch {
            Write-AppLog -Message "No se pudo aplicar efectos a la ventana: $_" -Level "WARN"
        }
    }
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
        
        $transparent = ($Config.Theme.Transparency -eq "True")
        
        function Get-SolidBrush ($hex) {
            return [System.Windows.Media.BrushConverter]::new().ConvertFromString($hex)
        }

        # --- LÓGICA DE FONDO DE SEGURIDAD ---
        # Si la ventana NO es nativamente transparente (AllowsTransparency=False), 
        # usar un color sólido evita que se vea negro ("agujero negro") en modo claro.
        
        if ($mode -eq "Light") {
            # Light Mode
            if ($transparent -and $Window.AllowsTransparency) {
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush "#01000000" # Real transparency
            } else {
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush "#FFF0F2F5" # Solid Safety Fallback
            }
            $Window.Resources["GlobalPanelBrush"] = Get-SolidBrush "#F9F5F7FA"
            $Window.Resources["GlobalSecondaryBrush"] = Get-SolidBrush "#20000000"
            $Window.Resources["GlobalTextBrush"] = Get-SolidBrush "#1A1A1A"
            $Window.Resources["GlobalSubTextBrush"] = Get-SolidBrush "#666666"
            $Window.Resources["GlobalBorderBrush"] = Get-SolidBrush "#25000000"
            $Window.Resources["GlobalPopupBrush"] = Get-SolidBrush "#FFFFFFFF"
        }
        else {
            # Dark Mode
            if ($transparent -and $Window.AllowsTransparency) {
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush "#01000000"
            } else {
                $Window.Resources["GlobalBackgroundBrush"] = Get-SolidBrush "#FF121212" # Solid Safety Fallback
            }
            $Window.Resources["GlobalPanelBrush"] = Get-SolidBrush "#FA121212"
            $Window.Resources["GlobalSecondaryBrush"] = Get-SolidBrush "#30FFFFFF"
            $Window.Resources["GlobalTextBrush"] = Get-SolidBrush "#FFFFFF"
            $Window.Resources["GlobalSubTextBrush"] = Get-SolidBrush "#CCCCCC"
            $Window.Resources["GlobalBorderBrush"] = Get-SolidBrush "#33FFFFFF"
            $Window.Resources["GlobalPopupBrush"] = Get-SolidBrush "#FF1E1E1E"
        }
        
        # 3. Apply Background globally
        $Window.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, "GlobalBackgroundBrush")
    }
    catch {
        Write-AppLog -Message "Error setting theme resources: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Set-WindowEffects {
    param($Window, $Config)
    
    # Requires Window to be Shown (HWND valid)
    if (-not ("WindowHelperV2" -as [type])) { return }
    
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        if ($hwnd -eq [IntPtr]::Zero) { return }
        
        $mode = $Config.Theme.Mode
        if ([string]::IsNullOrWhiteSpace($mode) -or $mode -eq "System") {
            $mode = Get-SystemTheme
        }
        $isDark = ($mode -ne "Light")
        
        # 1. Native Windows Theme (Caption/Border)
        [WindowHelperV2]::SetWindowTheme($hwnd, $isDark)
        
        # 2. Unified Backdrop / Blur (Windows 10 & 11)
        if ($Config.Theme.Transparency -eq "True" -or $Window.AllowsTransparency) {
             [WindowHelperV2]::ApplyBlur($hwnd, $isDark)
        }
        
        # Also update Quick Launcher if open
        if ($script:QuickLauncherWindow -and $script:QuickLauncherWindow.IsVisible) {
            $qlHwnd = (New-Object System.Windows.Interop.WindowInteropHelper($script:QuickLauncherWindow)).Handle
            [WindowHelperV2]::SetWindowTheme($qlHwnd, $isDark)
            if ($Config.Theme.Transparency -eq "True") {
                 [WindowHelperV2]::ApplyBlur($qlHwnd, $isDark)
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
