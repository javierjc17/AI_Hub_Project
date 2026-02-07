function Register-SystemHotkeys {
    param($WindowHandle, $HotkeyConfig)
    
    try {
        # Validar Configuración
        if (-not $HotkeyConfig -or -not $HotkeyConfig.Enabled) {
            return $true # Deshabilitado intencionalmente
        }

        # Lookup Tables (Hex Values)
        $Modifiers = @{
            "None"    = 0x0000
            "Alt"     = 0x0001
            "Control" = 0x0002
            "Shift"   = 0x0004
            "Win"     = 0x0008
        }

        $Keys = @{
            "Space" = 0x20
            "Enter" = 0x0D
            "Tab"   = 0x09
            "Esc"   = 0x1B
            "Back"  = 0x08
            "Up"    = 0x26
            "Down"  = 0x28
        }
        
        # Add A-Z (0x41 - 0x5A)
        0..25 | ForEach-Object { 
            $char = [char](65 + $_)
            $Keys["$char"] = (65 + $_)
        }
        
        # Add F1-F12 (0x70 - 0x7B)
        1..12 | ForEach-Object {
            $Keys["F$_"] = (111 + $_)
        }

        # Add 0-9 (0x30 - 0x39)
        0..9 | ForEach-Object {
            $Keys["$_"] = (48 + $_)
        }

        # Parse Modifier
        $modValue = 0
        if ($HotkeyConfig.Modifier) {
            $mods = $HotkeyConfig.Modifier.Split("+")
            foreach ($m in $mods) {
                $m = $m.Trim()
                if ($Modifiers.ContainsKey($m)) {
                    $modValue = $modValue -bor $Modifiers[$m]
                }
            }
        }

        # Parse Key
        $vkValue = 0
        $keyName = $HotkeyConfig.Key
        if ($Keys.ContainsKey($keyName)) {
            $vkValue = $Keys[$keyName]
        }
        else {
            Write-AppLog -Message "Tecla no reconocida: $keyName" -Level "WARN"
            return $false
        }

        # Register (ID 9000 used for Main Hotkey)
        $id = 9000 
        $success = [Win32]::RegisterHotKey($WindowHandle, $id, $modValue, $vkValue)
        
        if (-not $success) {
            Write-AppLog -Message "No se pudo registrar el atajo global $($HotkeyConfig.Modifier)+$($HotkeyConfig.Key)." -Level "WARN"
            return $false
        }
        
        return $true
    }
    catch {
        Write-AppLog -Message "Error registrando hotkeys: $_" -Level "ERROR"
        return $false
    }
}

function Unregister-SystemHotkeys {
    param($WindowHandle, $HotkeyId)
    try {
        [Win32]::UnregisterHotKey($WindowHandle, $HotkeyId) | Out-Null
    }
    catch {
        Write-AppLog -Message "Error al gestionar el icono de bandeja: $_" -Level "ERROR"
    }
}

function Initialize-SystemTray {
    param($Window, $WindowHandle, $RestoreAction)
    
    try {
        $script:RestoreAction = $RestoreAction
        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
        $notifyIcon.Icon = $icon
        $notifyIcon.Text = "AI Hub Architect"
        $notifyIcon.Visible = $false
        
        $contextMenu = New-Object System.Windows.Forms.ContextMenu
        
        $menuItemRestore = New-Object System.Windows.Forms.MenuItem -Property @{ Text = "Restaurar" }
        $menuItemRestore.Add_Click({ 
                if ($script:RestoreAction -is [ScriptBlock]) { & $script:RestoreAction } 
                $notifyIcon.Visible = $false
            })
        [void]$contextMenu.MenuItems.Add($menuItemRestore)
        
        $menuItemSettings = New-Object System.Windows.Forms.MenuItem -Property @{ Text = "Configuración" }
        $menuItemSettings.Add_Click({ 
                if ($script:RestoreAction -is [ScriptBlock]) { & $script:RestoreAction }
                $notifyIcon.Visible = $false
                Show-Settings -Owner $Window 
            })
        [void]$contextMenu.MenuItems.Add($menuItemSettings)
        
        [void]$contextMenu.MenuItems.Add("-")
        
        $menuItemExit = New-Object System.Windows.Forms.MenuItem -Property @{ Text = "Salir" }
        $menuItemExit.Add_Click({ 
                $notifyIcon.Visible = $false
                $script:ForceExit = $true
                $Window.Close() 
            })
        [void]$contextMenu.MenuItems.Add($menuItemExit)
        
        $notifyIcon.ContextMenu = $contextMenu
        $notifyIcon.Add_MouseClick({
                param($s, $e)
                if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { 
                    if ($script:RestoreAction -is [ScriptBlock]) { & $script:RestoreAction } 
                    $notifyIcon.Visible = $false
                }
            })
        
        return $notifyIcon
    }
    catch {
        Write-AppLog -Message "Error inicializando bandeja: $_" -Level "ERROR"
        return $null
    }
}
