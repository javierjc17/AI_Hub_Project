try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing -ErrorAction Stop } catch { Write-Warning "Error loading assemblies: $_" }

# La compilación C# (Add-Type) es LENTA. La moveremos al evento Loaded.
$script:hotkeySource = @"
    using System;
    using System.Runtime.InteropServices;
    public class Win32 {
        [DllImport("user32.dll")]
        public static extern bool RegisterHotKey(IntPtr hWnd, int id, int fsModifiers, int vKey);
        [DllImport("user32.dll")]
        public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    }
"@

# Compilar inmediatamente la clase Win32 para que esté disponible en SourceInitialized
try { Add-Type -TypeDefinition $script:hotkeySource -ErrorAction Stop } catch { Write-Warning "Win32 Class already added." }

# Configuración Global de Seguridad (TLS 1.2+)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls

$PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path

# 0. CONSTANTES GLOBALES (CRÍTICO - GLOBAL SCOPE)
# Usamos $global: para garantizar visibilidad en eventos y módulos dot-sourced
$global:InstallationRoot = $PSScriptRoot
$global:ConfigPath = "$global:InstallationRoot\config\config.json"
$statsPath = "$global:InstallationRoot\config\stats.json"

# 0. Asegurar directorios
$dirs = @("$global:InstallationRoot\config", "$global:InstallationRoot\logs", "$global:InstallationRoot\functions", "$global:InstallationRoot\xaml", "$global:InstallationRoot\icons")
foreach ($dir in $dirs) { if (-not (Test-Path $dir)) { New-Item -Path $dir -ItemType Directory | Out-Null } }

# 1. Cargar módulos de funciones (Recursivo para nueva estructura)
$script:startupSw = [System.Diagnostics.Stopwatch]::StartNew()
Get-ChildItem -Path "$PSScriptRoot\functions" -Filter *.ps1 -Recurse | ForEach-Object { . $_.FullName }
Write-AppLog -Message "Módulos cargados en $($script:startupSw.ElapsedMilliseconds)ms"

# 1.1 Pre-compilar utilidades de ventana (C#) para evitar lag en renderizado
Initialize-WindowUtils

# 3. Cargar datos iniciales
$global:config = Get-ConfigData -Path $global:ConfigPath
if (-not $global:config) {  
    [System.Windows.MessageBox]::Show("Error crítico: No se pudo cargar config.json.", "Error", 0, 16)
    exit 1 
}

Import-Stats -Path $statsPath

# Iniciar Pre-fetching de iconos en segundo plano
Start-IconPreFetch -Config $global:config

# 4. Logs
Write-AppLog -Message "Aplicación AI Hub Architect iniciada (Root: $global:InstallationRoot)"

# 5. Variables de estado
$script:currentTab = "Imagenes"
$script:allTools = @()
$script:selectedTool = $null

# 6. Cargar Ventana Principal (Usando la nueva Factoría)
try {
    $xamlPath = Join-Path $global:InstallationRoot "xaml\Windows\main.xaml"
    $window = New-AppWindow -XamlPath $xamlPath -Title "AI Hub Architect" -Config $global:config
}
catch {
    Write-AppLog -Message "Error al cargar la interfaz principal: $($_.Exception.Message)" -Level "ERROR"
    [System.Windows.MessageBox]::Show("Error al cargar la interfaz: $($_.Exception.Message)", "Error", 0, 16)
    exit 1
}

# 7. Referencias a elementos UI
$toolsPanel = $window.FindName("ToolsPanel")
$searchBox = $window.FindName("SearchBox")
$tabsContainer = $window.FindName("TabsContainer")
$statsTotal = $window.FindName("StatsTotal")
$statsCategories = $window.FindName("StatsCategories")
$statsMostUsed = $window.FindName("StatsMostUsed")
$toolInfoPanel = $window.FindName("ToolInfoPanel")
$infoName = $window.FindName("InfoName")
$infoDesc = $window.FindName("InfoDesc")
$infoCategory = $window.FindName("InfoCategory")

# Validar elementos críticos
if (-not $toolsPanel -or -not $tabsContainer -or -not $searchBox) {
    Write-AppLog -Message "Error Crítico: No se encontraron elementos esenciales en el XAML." -Level "ERROR"
    [System.Windows.MessageBox]::Show("Error de estructura XAML. Revisa app.log", "Error", 0, 16)
    exit 1
}

# 8. Registrar Atajos
Register-AppShortcuts -Window $window -SearchBox $searchBox

# 9. Inicializar Pestañas y UI (SINCRONO - PRE SHOW)
if ($tabsContainer) {
    # 9.0 Callback para actualizar estadísticas
    $script:UpdateStatsCallback = {
        Update-StatsDisplay -StatsPath $statsPath `
            -TxtTotal $statsTotal -TxtCategories $statsCategories -TxtMostUsed $statsMostUsed
    }

    # 9.1 Conectar Eventos de Pestañas
    $script:TabAction = {
        $senderBtn = $this
        if ($senderBtn.IsChecked) {
            $script:currentTab = $senderBtn.Content
            Update-ToolsPanel -ToolsPanel $toolsPanel -Config $global:config -CurrentTab $script:currentTab `
                -SearchTerm $searchBox.Text -Window $window `
                -StatsPath $statsPath -StatsDisplayCallback $script:UpdateStatsCallback `
                -ToolInfoPanel $toolInfoPanel -InfoName $infoName -InfoDesc $infoDesc -InfoCategory $infoCategory
        }
    }
    
    # Init Tabs (Startup) with Event Handler
    Initialize-MainTabs -TabsContainer $tabsContainer -Config $global:config -Window $window -OnTabSelected $script:TabAction

    # Seleccionar primera pestaña
    if ($tabsContainer.Children.Count -gt 0) {
        $tabsContainer.Children[0].IsChecked = $true
    }
    
    if ($statsTotal) { & $script:UpdateStatsCallback }
}

# 12. Otros Eventos
$searchBox.Add_TextChanged({ 
        Update-ToolsPanel -ToolsPanel $toolsPanel -Config $global:config -CurrentTab $script:currentTab `
            -SearchTerm $this.Text -Window $window `
            -StatsPath $statsPath -StatsDisplayCallback $script:UpdateStatsCallback `
            -ToolInfoPanel $toolInfoPanel -InfoName $infoName -InfoDesc $infoDesc -InfoCategory $infoCategory
    })
# 10. Eventos de Botones de Ventana
$window.FindName("BtnClose").Add_Click({ $window.Close() })
$window.FindName("BtnMaximize").Add_Click({ 
        if ($window.WindowState -eq "Maximized") { $window.WindowState = "Normal" } else { $window.WindowState = "Maximized" } 
    })
$window.FindName("BtnMinimize").Add_Click({ $window.WindowState = "Minimized" })
    
$window.FindName("BtnSettings").Add_Click({ Show-Settings -Owner $window })
$window.FindName("BtnHelp").Add_Click({ Show-HelpWindow -OwnerWindow $window })

# 11. Eventos del Sidebar
$window.FindName("BtnOpenAll").Add_Click({ Open-AllTools -Config $global:config -CurrentTab $script:currentTab })
$window.FindName("BtnRefresh").Add_Click({ 
        $global:config = Get-ConfigData -Path $global:ConfigPath
        if ($global:config) {
            # Refresh UI (don't recreate tabs, just update content)
            & $script:UpdateStatsCallback
            Update-ToolsPanel -ToolsPanel $toolsPanel -Config $global:config -CurrentTab $script:currentTab `
                -SearchTerm $searchBox.Text -Window $window `
                -StatsPath $statsPath -StatsDisplayCallback $script:UpdateStatsCallback `
                -ToolInfoPanel $toolInfoPanel -InfoName $infoName -InfoDesc $infoDesc -InfoCategory $infoCategory
            Show-ToolNotification -Title "Refrescar" -Message "Configuración recargada." -Owner $window
        }
    })
$window.FindName("BtnExportHtml").Add_Click({ 
        $configPath = Join-Path $global:InstallationRoot "config\config.json"
        $exportPath = Join-Path $global:InstallationRoot "AI_Hub_Bookmarks.html"
        $result = Export-ConfigurationToHTML -ConfigPath $configPath -OutputPath $exportPath
        
        if ($result) {
            Show-ToolNotification -Title "Exportación Exitosa" -Message "Archivo generado: $exportPath`nPuedes importarlo en tu navegador." -Icon "Information" -Owner $window
            Invoke-Item $global:InstallationRoot
        }
        else {
            Show-ToolNotification -Title "Error" -Message "No se pudo exportar." -Icon "Error" -Owner $window
        }
    })
    


# 13. SOLUCIÓN ROBUSTA: SourceInitialized para Temas y Efectos
$window.Add_SourceInitialized({
        try {
            Write-AppLog -Message "SourceInitialized: Forzando modo oscuro nativo..." -Level "INFO"

            # 1. Obtener HWND Inmediatamente
            $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
            $script:windowHandle = $helper.Handle

            # 2. CRITICO: Detectar y aplicar tema (Mecanismo compatible con C# Helper)
            $isDark = ($global:config.Theme.Mode -ne "Light")
            if ("WindowHelperV3" -as [type]) {
                [WindowHelperV3]::SetWindowTheme($script:windowHandle, $isDark)
            }
            elseif ("WindowHelperV2" -as [type]) {
                [WindowHelperV2]::SetWindowTheme($script:windowHandle, $isDark)
            }

            # 3. Aplicar Efectos Completos (Mica, Round Corners)
            Set-WindowEffects -Window $window -Config $global:config

            # 3.5 Inicializar System Tray (Bandeja del Sistema)
            # CRÍTICO: Sin esto, la lógica de minimizar falla porque $notifyIcon es nulo.
            $restoreAction = {
                $window.ShowInTaskbar = $true
                $window.Show()
                $window.WindowState = 'Normal'
                $window.Activate()
                $window.Opacity = 1
            }
            $script:notifyIcon = Initialize-SystemTray -Window $window -WindowHandle $script:windowHandle -RestoreAction $restoreAction

            # 4. Registrar Hotkeys
            $success = Register-SystemHotkeys -WindowHandle $script:windowHandle -HotkeyConfig $global:config.Hotkey
            if (-not $success) {
                # Silenciar error visual al inicio para evitar interrumpir la carga limpia.
                # El usuario puede ver el log si el atajo no funciona.
                Write-AppLog -Message "Conflicto de Atajo: $($global:config.Hotkey.Modifier)+$($global:config.Hotkey.Key) ya está en uso por otra aplicación." -Level "WARN"
                # Show-ToolNotification -Title "Atajo Ocupado" ... (DISABLED FOR CLEAN STARTUP)
            }

            # 5. Hook Message Loop
            $source = [System.Windows.Interop.HwndSource]::FromHwnd($script:windowHandle)
            if ($null -ne $source -and $null -ne $source.CompositionTarget) {
                $source.CompositionTarget.BackgroundColor = [System.Windows.Media.Colors]::Transparent
                $source.AddHook({
                        param($hwnd, $msg, $wParam, $lParam, $handled)
                        try {
                            if ($msg -eq 0x0312 -and $null -ne $wParam -and $wParam.ToInt32() -eq 9000) {
                                # ID 9000
                                [void](Show-QuickLauncher -OwnerWindow $window)
                            }
                        }
                        catch {
                            Write-AppLog -Message "Error en Hotkey Hook: $_" -Level Error
                        }
                        return [IntPtr]::Zero
                    })
            }

        }
        catch {
            Write-AppLog -Message "Error SourceInitialized: $_" -Level Error
        }
    })

# 6. REVEAL WINDOW (ContentRendered guarantees pixels are ready)
$window.Add_ContentRendered({
        # Use InvokeAsync with Background priority to let the UI finish ALL rendering first
        $window.Dispatcher.InvokeAsync({
                Write-AppLog -Message "ContentRendered: Teletransportando ventana al centro..." -Level "INFO"

                # 0. TELEPORT: Move from off-screen (-32000) to Center Screen
                $screenWidth = [System.Windows.SystemParameters]::PrimaryScreenWidth
                $screenHeight = [System.Windows.SystemParameters]::PrimaryScreenHeight
                $window.Left = ($screenWidth - $window.Width) / 2
                $window.Top = ($screenHeight - $window.Height) / 2
        
                # 1. VISIBILITY: Show in Taskbar and make visible
                $window.ShowInTaskbar = $true
                $window.Opacity = 1 
        
                # 2. ANIMATE: Fade out the curtain
                $hideAnim = $window.Resources["HideOverlayAnimation"]
                if ($hideAnim) {
                    $hideAnim.Begin()
                }
                else {
                    # Fallback direct collapse
                    $overlay = $window.FindName("LoadingOverlay")
                    if ($overlay) { $overlay.Visibility = "Collapsed" }
                }
            }, [System.Windows.Threading.DispatcherPriority]::Background)
    })

# Restaurar el evento Closing al final para seguridad
$window.Add_Closing({
        param($objSender, $e)
        if (-not $script:ForceExit -and $notifyIcon) {
            $e.Cancel = $true # Cancel the real close
    
            # Minimize to Tray logic
            try {
                $window.WindowState = 'Minimized'
                if ("WindowHelper" -as [type]) {
                    [WindowHelper]::HideFromTaskbar($script:windowHandle)
                }
                else {
                    $window.ShowInTaskbar = $false
                }
            }
            catch {
                Write-AppLog -Message "Error al ocultar de barra de tareas: $_" -Level "WARN"
                $window.ShowInTaskbar = $false
            }
            $notifyIcon.Visible = $true
        }
    })

$window.Add_Closed({
        try {
            $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
            [Win32]::UnregisterHotKey($helper.Handle, $script:HOTKEY_ID)
        }
        catch {}
        if ($notifyIcon) { $notifyIcon.Dispose() }
    })

try {
    Write-AppLog -Message "Llamando a ShowDialog()..." -Level "INFO"
    $window.ShowDialog() | Out-Null
}
catch {
    Write-Host "--- ERROR NO CONTROLADO ---" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    Write-AppLog -Message "Error No Controlado: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -Level "ERROR"
}

Write-Host "La aplicación ha finalizado." -ForegroundColor Green
Read-Host "Presione Enter para cerrar la consola..."
