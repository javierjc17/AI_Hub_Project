function Start-HealthCheckTimer {
    param($Window, $Config, $CurrentTab, $ToolsPanel)
    
    # Detener timer previo si existe en el ámbito global del script para evitar duplicados
    if ($script:healthTimer) {
        $script:healthTimer.Stop()
    }
    
    $script:healthTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:healthTimer.Interval = [TimeSpan]::FromMinutes(5) # Verificación cada 5 minutos
    
    $script:healthTimer.Add_Tick({
            Update-ToolsHealth -Config $Config -CurrentTab $CurrentTab -ToolsPanel $ToolsPanel
        })
    
    $script:healthTimer.Start()
    
    # IMPORTANTE: NO hacemos ejecución inicial inmediata aquí porque bloquea el hilo de UI
    # al realizar peticiones de red síncronas. El timer se activará solo cuando pasen los 5 min,
    # o podemos dispararlo con un delay menor si fuera crítico.
    # Por ahora, priorizamos la velocidad de arranque.
}

function Update-ToolsHealth {
    param($Config, $CurrentTab, $ToolsPanel)
    
    if (-not $ToolsPanel) { return }
    
    $tabData = $Config.Tabs | Where-Object { $_.Title -eq $CurrentTab }
    if (-not $tabData) { return }
    
    $toolsToCheck = @()
    if ($tabData.Tools) { $toolsToCheck += $tabData.Tools }
    if ($tabData.Groups) {
        foreach ($grp in $tabData.Groups) { $toolsToCheck += $grp.Tools }
    }
    
    foreach ($tool in $toolsToCheck) {
        $toolName = $tool.Name
        $toolUrl = $tool.URL

        # Lanzar verificación en un hilo de fondo (ThreadPool)
        # Esto NO bloquea la interfaz de usuario
        [System.Threading.ThreadPool]::QueueUserWorkItem({
                param($state)
                try {
                    $name = $state.Name
                    $url = $state.Url
                    $panel = $state.Panel

                    # 1. Petición de red (Lenta - ocurre en el hilo de fondo)
                    $isAvailable = Test-UrlAvailability -Url $url
                
                    # 2. Volver al hilo de UI solo para actualizar el color del puntito
                    $panel.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action] {
                            foreach ($child in $panel.Children) {
                                if ($child -is [System.Windows.Controls.WrapPanel]) {
                                    foreach ($btn in $child.Children) {
                                        if ($btn -is [System.Windows.Controls.Button] -and $null -ne $btn.Tag -and $btn.Tag.Name -eq $name) {
                                            Set-ToolHealthStatus -Button $btn -IsOnline $isAvailable
                                        }
                                    }
                                }
                            }
                        })
                }
                catch {
                    Write-AppLog -Message "Error en health check background thread: $_" -Level "WARN"
                }
            }, @{ Name = $toolName; Url = $toolUrl; Panel = $ToolsPanel })
    }
}
