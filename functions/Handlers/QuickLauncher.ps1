function Show-QuickLauncher {
    param($OwnerWindow)

    if ($script:QuickLauncherWindow -and $script:QuickLauncherWindow.IsVisible) {
        $script:QuickLauncherWindow.Activate()
        $script:QuickLauncherWindow.FindName("TxtSearch").Focus()
        return
    }

    $xamlPath = Join-Path $global:InstallationRoot "xaml\Windows\quick_launcher.xaml"
    $window = New-AppWindow -XamlPath $xamlPath -Title "Quick Launcher" -Config $global:config -Owner $OwnerWindow
    
    # Inject Resources from Owner (Theme)
    if ($OwnerWindow) {
        foreach ($key in $OwnerWindow.Resources.Keys) {
            if ($key -is [string] -and $key.StartsWith("Global")) {
                $window.Resources[$key] = $OwnerWindow.Resources[$key]
            }
        }
    }

    $txtSearch = $window.FindName("TxtSearch")
    $listResults = $window.FindName("ListResults")

    # --- LOGIC ---
    
    # --- LOGIC (Script Scoped for Event Visibility) ---
    
    # Caché inteligente: Solo regeneramos si config cambió
    $configHash = ($global:config | ConvertTo-Json -Compress).GetHashCode()
    
    if ($script:QL_CachedHash -ne $configHash -or -not $script:QL_AllTools) {
        Write-AppLog -Message "Quick Launcher: Regenerando caché de herramientas..." -Level "DEBUG"
        
        $script:QL_AllTools = @()
        foreach ($tab in $global:config.Tabs) {
            if ($tab.Tools) {
                foreach ($t in $tab.Tools) {
                    # Clonar para no ensuciar el objeto global con IconSource
                    $tClone = $t | ConvertTo-Json -Depth 2 | ConvertFrom-Json
                    
                    $tClone | Add-Member -MemberType NoteProperty -Name "_Category" -Value $tab.Title -Force
                    $iconPath = Get-Favicon -URL $t.URL -Name $t.Name
                    if ($iconPath) {
                        $fullPath = [System.IO.Path]::GetFullPath($iconPath).Replace("\", "/")
                        $uri = "file:///$fullPath"
                        $tClone | Add-Member -MemberType NoteProperty -Name "IconSource" -Value $uri -Force
                    }
                    else {
                        $tClone | Add-Member -MemberType NoteProperty -Name "IconSource" -Value $null -Force
                    }
                    $script:QL_AllTools += $tClone
                }
            }
            if ($tab.Groups) {
                foreach ($grp in $tab.Groups) {
                    foreach ($t in $grp.Tools) {
                        # Clonar
                        $tClone = $t | ConvertTo-Json -Depth 2 | ConvertFrom-Json
                        
                        $tClone | Add-Member -MemberType NoteProperty -Name "_Category" -Value "$($tab.Title) > $($grp.Title)" -Force
                        $iconPath = Get-Favicon -URL $t.URL -Name $t.Name
                        if ($iconPath) {
                            $fullPath = [System.IO.Path]::GetFullPath($iconPath).Replace("\", "/")
                            $uri = "file:///$fullPath"
                            $tClone | Add-Member -MemberType NoteProperty -Name "IconSource" -Value $uri -Force
                        }
                        else {
                            $tClone | Add-Member -MemberType NoteProperty -Name "IconSource" -Value $null -Force
                        }
                        $script:QL_AllTools += $tClone
                    }
                }
            }
        }
        
        # Guardar hash para futuras comparaciones
        $script:QL_CachedHash = $configHash
        Write-AppLog -Message "Quick Launcher: Caché actualizado con $($script:QL_AllTools.Count) herramientas" -Level "DEBUG"
    }
    else {
        Write-AppLog -Message "Quick Launcher: Usando caché existente ($($script:QL_AllTools.Count) herramientas)" -Level "DEBUG"
    }
    
    
    # Store references for scriptblocks
    $script:QL_TxtSearch = $txtSearch
    $script:QL_ListResults = $listResults
    $script:QL_Window = $window
    $script:QL_IsClosing = $false

    $script:QL_CloseWindow = {
        if (-not $script:QL_IsClosing) {
            $script:QL_IsClosing = $true
            try { $script:QL_Window.Close() } catch { Write-AppLog -Message "Error cerrando Quick Launcher (ya estaba cerrado)" -Level "DEBUG" }
        }
    }

    $script:QL_FilterList = {
        $query = $script:QL_TxtSearch.Text
        $script:QL_ListResults.Items.Clear()
        
        if ([string]::IsNullOrWhiteSpace($query)) {
            for ($i = 0; $i -lt [Math]::Min($script:QL_AllTools.Count, 10); $i++) {
                [void]$script:QL_ListResults.Items.Add($script:QL_AllTools[$i])
            }
        }
        else {
            foreach ($tool in $script:QL_AllTools) {
                if ($tool.Name -match $query -or $tool.Tags -match $query -or $tool.Desc -match $query) {
                    [void]$script:QL_ListResults.Items.Add($tool)
                }
            }
        }
        
        if ($script:QL_ListResults.Items.Count -gt 0) {
            $script:QL_ListResults.SelectedIndex = 0
        }
    }

    $script:QL_OpenSelected = {
        if ($script:QL_ListResults.SelectedIndex -ge 0) {
            $tool = $script:QL_ListResults.SelectedItem
            Start-Process $tool.URL
            & $script:QL_CloseWindow
        }
    }

    $txtSearch.Add_TextChanged({
            & $script:QL_FilterList
        })

    $window.Add_KeyDown({
            param($objSender, $e)
            if ($e.Key -eq "Escape") {
                & $script:QL_CloseWindow
            }
            if ($e.Key -eq "Enter") {
                & $script:QL_OpenSelected
            }
            if ($e.Key -eq "Down") {
                if ($listResults.SelectedIndex -lt $listResults.Items.Count - 1) {
                    $listResults.SelectedIndex++
                    $listResults.ScrollIntoView($listResults.SelectedItem)
                }
            }
            if ($e.Key -eq "Up") {
                if ($listResults.SelectedIndex -gt 0) {
                    $listResults.SelectedIndex--
                    $listResults.ScrollIntoView($listResults.SelectedItem)
                }
            }
        })
    
    # Auto-close on Deactivate
    $window.Add_Deactivated({
            & $script:QL_CloseWindow
        })

    # Initial Populate
    & $script:QL_FilterList
    $txtSearch.Focus()

    $script:QuickLauncherWindow = $window
    $window.Show()
}
