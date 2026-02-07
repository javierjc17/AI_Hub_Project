function Update-StatsUI {
    param($StatsTotal, $StatsCategories, $StatsMostUsed, $Config, $UsageStats)
    if (-not $Config.Tabs) { return }
    $totalCount = ($Config.Tabs | ForEach-Object { $_.Tools.Count } | Measure-Object -Sum).Sum
    if ($StatsTotal) { $StatsTotal.Text = "Total: $totalCount" }
    if ($StatsCategories) { $StatsCategories.Text = "Categorías: $($Config.Tabs.Count)" }
    
    if ($StatsMostUsed) {
        if ($UsageStats.Count -gt 0) {
            $best = $UsageStats.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
            $StatsMostUsed.Text = "Más usada: $($best.Name)"
        }
        else {
            $StatsMostUsed.Text = "Más usada: -"
        }
    }
}

function Update-FavoritesUI {
    param($FavoritesList, $Favorites, $AllTools, $Window)
    $FavoritesList.Items.Clear()
    foreach ($fav in $Favorites) {
        $starIcon = [char]0x2B50 # Star Emoji
        $item = New-Object System.Windows.Controls.ListBoxItem -Property @{
            Content         = "$starIcon $fav"
            Foreground      = if ($Window) { $Window.FindResource("GlobalTextBrush") } else { [System.Windows.Media.Brushes]::White }
            Background      = [System.Windows.Media.Brushes]::Transparent
            BorderThickness = 0
            Cursor          = [System.Windows.Input.Cursors]::Hand
        }
        
        $item.Add_MouseDoubleClick({
                # Clean prefix for robust matching
                $favName = $this.Content.ToString().Substring(2)
                $tool = $AllTools | Where-Object { $_.Name -eq $favName } | Select-Object -First 1
                if ($tool) { Start-Process $tool.URL } 
            })
        
        [void]$FavoritesList.Items.Add($item)
    }
}

function Update-ToolInfoUI {
    param($Panel, $NameText, $DescText, $CategoryText, $ToolData)
    $Panel.Visibility = [System.Windows.Visibility]::Visible
    $NameText.Text = $ToolData.Name
    $DescText.Text = $ToolData.Desc
    $CategoryText.Text = "Categoría: $($ToolData.Category)"
}

function Initialize-MainTabs {
    param($TabsContainer, $Config, $Window, $ScriptScope, $OnTabSelected)
    
    if (-not $TabsContainer) { return }
    $TabsContainer.Children.Clear()
    
    foreach ($tab in $Config.Tabs) {
        $isVisible = $true
        if ($tab.PSObject.Properties['Visible']) { $isVisible = $tab.Visible }
        
        if ($isVisible) {
            $rb = New-Object System.Windows.Controls.RadioButton
            $rb.Content = $tab.Title
            if ($null -ne $Window) { try { $rb.Style = $Window.FindResource("NavTabButton") } catch { Write-AppLog -Message "Estilo NavTabButton no encontrado, usando predeterminado" -Level "WARN" } }
            $rb.GroupName = "NavTabs"
            $rb.Cursor = [System.Windows.Input.Cursors]::Hand
            $rb.Tag = $tab.Title
            
            # Attach Event Handler if provided
            if ($OnTabSelected) {
                $rb.Add_Checked($OnTabSelected)
            }
            
            [void]$TabsContainer.Children.Add($rb)
        }
    }
}

function Update-ToolsPanel {
    param(
        $ToolsPanel, 
        $Config, 
        $CurrentTab, 
        $SearchTerm, 
        $Window, 
        $StatsPath, 
        $StatsDisplayCallback,
        # Info Panel Controls for Hover Event
        $ToolInfoPanel,
        $InfoName,
        $InfoDesc,
        $InfoCategory
    )
    
    if (-not $ToolsPanel) { return }
    $ToolsPanel.Children.Clear()
    
    if (-not $Config.Tabs) { return }
    
    $tabData = $Config.Tabs | Where-Object { $_.Title -eq $CurrentTab }
    if (-not $tabData) { $tabData = $Config.Tabs[0] }

    if ($null -eq $tabData) { return }

    # Trigger Animation
    $storyboard = $Window.Resources["FadeInAnimation"]
    if ($storyboard) {
        $ToolsPanel.RenderTransform = New-Object System.Windows.Media.TranslateTransform
        $storyboard.Begin($ToolsPanel)
    }
    
    # --- Helper Logic Inlined to ensure scope safety ---
    
    # 0. Fuzzy Search Helper REMOVED to prevent array arithmetic crashes
    # Using strict substring matching instead.

    # 1. Search Mode (Flatten) with Smart Search (GLOBAL SEARCH)
    if ($SearchTerm) {
        $flatTools = @()
        
        # Iterate ALL tabs for global search
        foreach ($tab in $Config.Tabs) {
            $catTitle = $tab.Title
            # Add Direct Tools
            if ($tab.Tools) { 
                foreach ($t in $tab.Tools) {
                    $flatTools += [PSCustomObject]@{ Tool = $t; Category = $catTitle }
                }
            }
            # Add Group Tools
            if ($tab.Groups) { 
                foreach ($grp in $tab.Groups) {
                    $grpTitle = "$catTitle > $($grp.Title)"
                    foreach ($t in $grp.Tools) {
                        $flatTools += [PSCustomObject]@{ Tool = $t; Category = $grpTitle }
                    }
                }
            }
        }
        
        $wrap = New-Object System.Windows.Controls.WrapPanel
        [void]$ToolsPanel.Children.Add($wrap)

        foreach ($item in $flatTools) {
            try {
                $toolRef = $item.Tool
                $catRef = $item.Category
                
                $match = $true
                if ($null -ne $SearchTerm) {
                    $searchTokens = $SearchTerm.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
                }
                else {
                    $searchTokens = @()
                }
            
                foreach ($token in $searchTokens) {
                    if (-not ($toolRef.Name -like "*$token*" -or $toolRef.Desc -like "*$token*" -or $toolRef.Tags -like "*$token*")) {
                        $match = $false
                        break
                    }
                }
            
                if ($match) {
                    $btn = New-ToolButton -Tool $toolRef -Category $catRef -Window $Window
                    $btn.Add_Click({
                            $t = $this.Tag
                            $check = Resolve-SmartUrl -Url $t.URL
                            
                            # Actualizar el puntito visual (Lazy Health Check)
                            Set-ToolHealthStatus -Button $this -IsOnline $check.Success
                            
                            if ($check.Success) {
                                if ($check.Changed) {
                                    Write-AppLog -Message "Smart URL: Updating $($t.Name) from $($t.URL) to $($check.FinalUrl)"
                                    
                                    # 1. Update Object in Memory
                                    $t.URL = $check.FinalUrl
                                    
                                    # 2. Save to Disk (Lazy Save)
                                    $topPath = Join-Path $global:InstallationRoot "config\config.json"
                                    Set-ConfigData -Path $topPath -Data $global:config
                                    
                                    # 3. Notify User
                                    Show-ToolNotification -Title "Enlace Actualizado" -Message "El dominio cambió. Guardado nuevo enlace: $($check.FinalUrl)" -Icon "Information" -Owner $Window
                                }
                                
                                Start-Process $check.FinalUrl
                                Add-ToolUsage -ToolName $t.Name
                                Export-Stats -Path $StatsPath
                                if ($StatsDisplayCallback -is [ScriptBlock]) { & $StatsDisplayCallback }
                            }
                            else {
                                Show-ToolNotification -Title "Error" -Message "URL inaccesible" -Icon "Error" -Owner $Window
                            }
                        })

                    if ($ToolInfoPanel) {
                        $btn.Add_MouseEnter({ 
                                Update-ToolInfoUI -Panel $ToolInfoPanel -NameText $InfoName -DescText $InfoDesc -CategoryText $InfoCategory -ToolData $this.Tag
                            })
                    }
                    [void]$wrap.Children.Add($btn)
                }
            }
            catch {
                Write-AppLog -Message "Error rendering tool (search): $_" -Level Error
            }
        }
        return
    }

    # 2. Direct Tools Mode (Optimizado: Síncrono y seguro)
    if ($null -ne $tabData.Tools) {
        $wrap = New-Object System.Windows.Controls.WrapPanel
        [void]$ToolsPanel.Children.Add($wrap)
        
        # Forzar array para manejar casos de una sola herramienta en JSON
        $toolsList = @($tabData.Tools)
        
        foreach ($tool in $toolsList) {
            try {
                $btn = New-ToolButton -Tool $tool -Category $CurrentTab -Window $Window
        
                $btn.Add_Click({
                        $t = $this.Tag
                        $check = Resolve-SmartUrl -Url $t.URL
                        
                        # Actualizar el puntito visual (Lazy Health Check)
                        Set-ToolHealthStatus -Button $this -IsOnline $check.Success
                        
                        if ($check.Success) {
                            if ($check.Changed) {
                                Write-AppLog -Message "Smart URL: Updating $($t.Name) from $($t.URL) to $($check.FinalUrl)"
                                # 1. Update Object in Memory
                                $t.URL = $check.FinalUrl
                                # 2. Save to Disk
                                $topPath = Join-Path $global:InstallationRoot "config\config.json"
                                Set-ConfigData -Path $topPath -Data $global:config
                                # 3. Notify
                                Show-ToolNotification -Title "Enlace Actualizado" -Message "El dominio cambió. Nuevo enlace guardado." -Icon "Information" -Owner $Window
                            }
                            
                            Start-Process $check.FinalUrl
                            Add-ToolUsage -ToolName $t.Name
                            Export-Stats -Path $StatsPath
                            if ($StatsDisplayCallback -is [ScriptBlock]) { & $StatsDisplayCallback }
                        }
                        else {
                            Show-ToolNotification -Title "Error" -Message "URL inaccesible" -Icon "Error" -Owner $Window
                        }
                    })

                if ($ToolInfoPanel) {
                    $btn.Add_MouseEnter({ 
                            Update-ToolInfoUI -Panel $ToolInfoPanel -NameText $InfoName -DescText $InfoDesc -CategoryText $InfoCategory -ToolData $this.Tag
                        })
                }
                [void]$wrap.Children.Add($btn)
            }
            catch {
                Write-AppLog -Message "Error rendering tool (direct): $_" -Level Error
            }
        }
    }

    # 3. Group Mode (Now Second)
    if ($null -ne $tabData.Groups) {
        foreach ($group in $tabData.Groups) {
            # Header
            if ($group.Title) {
                $header = New-Object System.Windows.Controls.TextBlock -Property @{
                    Text       = $group.Title
                    FontSize   = 14
                    FontWeight = "Bold"
                    Foreground = $Window.Resources["GlobalTextBrush"]
                    Margin     = "5,15,0,5"
                }
                [void]$ToolsPanel.Children.Add($header)
            }
        
            # WrapPanel for this group
            $wrap = New-Object System.Windows.Controls.WrapPanel
            foreach ($tool in $group.Tools) {
                $btn = New-ToolButton -Tool $tool -Category $CurrentTab -Window $Window
                
                $btn.Add_Click({
                        $t = $this.Tag
                        $check = Resolve-SmartUrl -Url $t.URL
                        
                        # Actualizar el puntito visual (Lazy Health Check)
                        Set-ToolHealthStatus -Button $this -IsOnline $check.Success
                        
                        if ($check.Success) {
                            if ($check.Changed) {
                                Write-AppLog -Message "Smart URL: Updating $($t.Name) from $($t.URL) to $($check.FinalUrl)"
                                $t.URL = $check.FinalUrl
                                $topPath = Join-Path $global:InstallationRoot "config\config.json"
                                Set-ConfigData -Path $topPath -Data $global:config
                                Show-ToolNotification -Title "Enlace Actualizado" -Message "El dominio cambió. Nuevo enlace guardado." -Icon "Information" -Owner $Window
                            }
                            
                            Start-Process $check.FinalUrl
                            Add-ToolUsage -ToolName $t.Name
                            Export-Stats -Path $StatsPath
                            if ($StatsDisplayCallback -is [ScriptBlock]) { & $StatsDisplayCallback }
                        }
                        else {
                            Show-ToolNotification -Title "Error" -Message "URL inaccesible" -Icon "Error" -Owner $Window
                        }
                    })

                if ($ToolInfoPanel) {
                    $btn.Add_MouseEnter({ 
                            Update-ToolInfoUI -Panel $ToolInfoPanel -NameText $InfoName -DescText $InfoDesc -CategoryText $InfoCategory -ToolData $this.Tag
                        })
                }
                [void]$wrap.Children.Add($btn)
            }
            [void]$ToolsPanel.Children.Add($wrap)
        }
    }
}

function Open-AllTools {
    param($Config, $CurrentTab)
    
    if (-not $Config.Tabs) { return }
    
    $tabData = $Config.Tabs | Where-Object { $_.Title -eq $CurrentTab }
    if (-not $tabData) { return }
    
    $urlsToOpen = @()
    
    # Direct Tools
    if ($tabData.Tools) {
        $urlsToOpen += $tabData.Tools.URL
    }
    
    # Group Tools
    if ($tabData.Groups) {
        foreach ($grp in $tabData.Groups) {
            if ($grp.Tools) {
                $urlsToOpen += $grp.Tools.URL
            }
        }
    }
    
    # Confirm
    if ($urlsToOpen.Count -eq 0) { return }
    if ($urlsToOpen.Count -gt 10) {
        $res = [System.Windows.MessageBox]::Show("Vas a abrir $($urlsToOpen.Count) pestañas. ¿Continuar?", "Confirmar", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($res -ne [System.Windows.MessageBoxResult]::Yes) { return }
    }
    
    foreach ($url in $urlsToOpen) {
        if (-not [string]::IsNullOrWhiteSpace($url)) {
            Start-Process $url
        }
    }
}

