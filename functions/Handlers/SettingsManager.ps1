function Show-Settings {
    param($Owner)
    
    try {
        # 0. CLONE Config for Transactional Session (Deep Copy via JSON)
        # This ensures we don't modify the live $global:config until "Aceptar" is clicked.
        $script:tempConfig = $global:config | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        
        # 0b. Use tempConfig for everything inside Settings
        
        # 0b. Use tempConfig for everything inside Settings
        
        $xamlPath = Join-Path $global:InstallationRoot "xaml\Windows\settings.xaml"
        $settingsWindow = New-AppWindow -XamlPath $xamlPath -Title "Ajustes de AI Hub" -Config $script:tempConfig -Owner $Owner
        
        # Referencias a controles
        $btnSave = $settingsWindow.FindName("BtnSave")
        $btnCancel = $settingsWindow.FindName("BtnCancel")
        $btnTools = $settingsWindow.FindName("BtnTools")
        $toggleTheme = $settingsWindow.FindName("ToggleTheme")
        # Custom Chrome Controls
        $btnCloseWindow = $settingsWindow.FindName("BtnCloseWindow")
        $titleBarArea = $settingsWindow.FindName("TitleBarArea")
        $btnRefreshIcons = $settingsWindow.FindName("BtnRefreshIcons")
        
        $backupDir = Join-Path $global:InstallationRoot "config\backups"
        if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir | Out-Null }

        # --- Window Chrome Logic ---
        if ($titleBarArea) {
            $titleBarArea.Add_MouseLeftButtonDown({
                    try { $settingsWindow.DragMove() } catch { Write-AppLog -Message "Settings DragMove error: $_" -Level 'DEBUG' }
                })
        }
        
        if ($btnCloseWindow) {
            $btnCloseWindow.Add_Click({
                    $settingsWindow.Close() # Triggers the existing Add_Closed logic below
                })
        }
        if ($btnRefreshIcons) {
            $btnRefreshIcons.Add_Click({
                    if (Show-CustomDialog -Message "¿Deseas borrar la caché de iconos? Se volverán a descargar de la web al reiniciar." -Title "Confirmar" -Owner $settingsWindow) {
                        Clear-IconCache
                        Show-ToolNotification -Title "Limpieza Completada" -Message "Los iconos se refrescarán al reiniciar la app." -Icon "Information" -Owner $settingsWindow
                    }
                })
        }
        # ---------------------------

        # Colores
        $colors = @{
            "ColorBlue" = "#3498db"; "ColorGreen" = "#2ecc71"; 
            "ColorPurple" = "#9b59b6"; "ColorOrange" = "#e67e22"; "ColorRed" = "#e74c3c"
        }
        
        # $selectedAccent = $script:config.Theme.Accent # Unused locally
        
        foreach ($colorName in $colors.Keys) {
            $btn = $settingsWindow.FindName($colorName)
            if ($btn) {
                $btn.Add_Click({
                        $colorCode = $colors[$this.Name]
                        $script:selectedAccentTemp = $colorCode
                    
                        # Efecto WOW: Actualizar recurso inmediatamente en ambas ventanas
                        $newBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($colorCode)
                    
                        # 1. Ventana de Ajustes
                        $settingsWindow.Resources["GlobalAccentBrush"] = $newBrush
                    
                        # 2. Ventana Principal (si existe)
                        if ($Owner) {
                            $Owner.Resources["GlobalAccentBrush"] = $newBrush
                        }
                    })
            }
        }
        $script:selectedAccentTemp = $script:tempConfig.Theme.Accent # Default to current



        # Pre-cargar valores actuales
        # Checked = Dark Mode, Unchecked = Light Mode
        # Resolve 'System' to actual state for the Toggle
        $initMode = $script:tempConfig.Theme.Mode
        $isToggleChecked = $true # Default Dark
        
        if ([string]::IsNullOrWhiteSpace($initMode) -or $initMode -eq "System") {
            if (Get-Command "Get-SystemTheme" -ErrorAction SilentlyContinue) {
                if ((Get-SystemTheme) -eq "Light") { $isToggleChecked = $false }
            }
        }
        elseif ($initMode -eq "Light") {
            $isToggleChecked = $false
        }
        
        $toggleTheme.IsChecked = $isToggleChecked
        


        # Evento: Cambio de Tema (Vista Previa Instantánea - Toggle)
        $themeAction = {
            $isChecked = $toggleTheme.IsChecked
            $newMode = if ($isChecked) { "Dark" } else { "Light" }
            


            # Crear configuración temporal para aplicar el tema
            $tempConfig = [PSCustomObject]@{
                Theme = @{
                    Accent = $script:selectedAccentTemp
                    Mode   = $newMode
                }
            }
            
            # Aplicar Tema a Settings (Self)
            Set-AppTheme -Window $settingsWindow -Config $tempConfig
            
            # Aplicar Tema a Main Window (Owner)
            if ($Owner) {
                Set-AppTheme -Window $Owner -Config $tempConfig
            }
        }

        $toggleTheme.Add_Checked($themeAction)
        $toggleTheme.Add_Unchecked($themeAction)
        
        # Aplicar el tema actual a la ventana de ajustes al abrir
        Set-AppTheme -Window $settingsWindow -Config $script:tempConfig


        # --- HOTKEY LOGIC ---
        $comboModifier = $settingsWindow.FindName("ComboHotkeyModifier")
        $comboKey = $settingsWindow.FindName("ComboHotkeyKey")

        if ($comboModifier -and $comboKey) {
            # Populate Keys (Standard + A-Z + 0-9 + F1-F12)
            $comboKey.Items.Clear()
            $standardKeys = @("Space", "Enter", "Tab", "Esc", "Back", "Up", "Down")
            $alphaKeys = 65..90 | ForEach-Object { [char]$_ }
            $numKeys = 0..9 | ForEach-Object { "$_" }
            $fKeys = 1..12 | ForEach-Object { "F$_" }
            
            $allKeys = $standardKeys + $alphaKeys + $numKeys + $fKeys
            foreach ($k in $allKeys) { [void]$comboKey.Items.Add($k) }

            # Set Current Values
            if ($script:tempConfig.Hotkey) {
                $comboModifier.Text = $script:tempConfig.Hotkey.Modifier
                $comboKey.Text = $script:tempConfig.Hotkey.Key
            }
            else {
                $comboModifier.Text = "Control"
                $comboKey.Text = "Space"
            }
        }

        $btnSave.Add_Click({
                try {
                    # 1. Update Theme Object (Memory - Temp)
                    $themeMode = if ($toggleTheme.IsChecked) { "Dark" } else { "Light" }
                    $script:tempConfig.Theme.Mode = $themeMode
                    $script:tempConfig.Theme.Accent = $script:selectedAccentTemp
                
                    # 1.5 Update Hotkey Config
                    if ($null -ne $comboModifier -and $null -ne $comboKey) {
                        if (-not $script:tempConfig.PSObject.Properties['Hotkey']) {
                            $script:tempConfig | Add-Member -MemberType NoteProperty -Name "Hotkey" -Value ([PSCustomObject]@{ Modifier = ""; Key = ""; Enabled = $true })
                        }
                        $script:tempConfig.Hotkey.Modifier = $comboModifier.Text
                        $script:tempConfig.Hotkey.Key = $comboKey.Text
                    }
                
                    # 2. GLOBAL SAVE (Commit Temp -> Live -> Disk)
                    $global:config = $script:tempConfig # Commit to Memory
                
                    $configPath = Join-Path $global:InstallationRoot "config\config.json"
                    
                    # 2.5 Automatic Backup before Save
                    try {
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmm"
                        $autoBackup = Join-Path $backupDir "auto_config_$timestamp.json"
                        Copy-Item -Path $configPath -Destination $autoBackup -Force
                    }
                    catch { 
                        Write-AppLog -Message "Auto-backup failed: $_" -Level "WARN"
                    }
                    
                    # Commit to Disk
                    Set-ConfigData -Path $configPath -Data $global:config
                    
                    # 3. Refresh Main UI and Sync Theme
                    # 3.1 ACTUALIZAR TODAS LAS VENTANAS AL INSTANTE (Sincronización Global)
                    if (Get-Command Sync-GlobalTheme -ErrorAction SilentlyContinue) {
                        Sync-GlobalTheme -Config $global:config
                    }
                    else {
                        # Fallback if Sync-GlobalTheme is not available (e.g., older version or specific context)
                        Set-AppTheme -Window $settingsWindow -Config $global:config
                        if ($Owner) {
                            Set-AppTheme -Window $Owner -Config $global:config
                        }
                    }
                    
                    if ($global:RefreshUIScript -is [ScriptBlock]) { & $global:RefreshUIScript }
                
                    $settingsSaved = $true
                    $settingsWindow.Close()
                }
                catch {
                    Show-ToolNotification -Title "Error" -Message "Error al guardar: $($_.Exception.Message)" -Icon "Error" -Owner $settingsWindow
                }
            })
        
        $btnCancel.Add_Click({
                $settingsWindow.Close()
            })

        # CRITICAL: Revert Theme if Cancelled or Closed via 'X'
        # CRITICAL: Revert Theme if Cancelled or Closed via 'X'
        $settingsWindow.Add_Closed({
                try {
                    if (-not $settingsSaved) {
                        # User cancelled: Revert Main Window to original config
                        if ($Owner) {
                            # Use Dispatcher to safely update UI thread if needed, though direct call usually works in single-thread PS
                            Set-AppTheme -Window $Owner -Config $global:config
                        }
                    }
                }
                catch {
                    Write-Warning "Error reverting theme: $_"
                }
            })


        
        # --- TOOL EDITOR LOGIC (Integrated) ---
        $treeTools = $settingsWindow.FindName("TreeSettingsTools")
        $searchTools = $settingsWindow.FindName("SearchSettingsTools") # Future Use
        
        $editForm = $settingsWindow.FindName("ToolEditForm")
        $emptySelectionMsg = $settingsWindow.FindName("EmptySelectionMessage")
        
        $txtToolName = $settingsWindow.FindName("TxtToolName")
        $dragInsertLine = $settingsWindow.FindName("DragInsertLine")
        $txtToolUrl = $settingsWindow.FindName("TxtToolUrl")
        $txtToolDesc = $settingsWindow.FindName("TxtToolDesc")
        $txtToolTags = $settingsWindow.FindName("TxtToolTags")



        
        $btnToolSave = $settingsWindow.FindName("BtnToolSave")
        $btnToolClear = $settingsWindow.FindName("BtnToolClear")
        $btnToolDelete = $settingsWindow.FindName("BtnToolDelete")
        
        # New Management Buttons
        $btnNewTab = $settingsWindow.FindName("BtnNewTab")
        $btnNewGroup = $settingsWindow.FindName("BtnNewGroup")
        $btnRename = $settingsWindow.FindName("BtnRename")
        
        $toolsStatusText = $settingsWindow.FindName("ToolsStatusText")
        $cmbToolCategory = $settingsWindow.FindName("CmbToolCategory")
        


        # Helpers
        $script:RefreshCategoryCombo = {
            if ($null -ne $cmbToolCategory) {
                $currentValue = $cmbToolCategory.Text
                $cmbToolCategory.Items.Clear()
                foreach ($tab in $script:tempConfig.Tabs) {
                    [void]$cmbToolCategory.Items.Add($tab.Title)
                }
                if ($cmbToolCategory.Items.Contains($currentValue)) {
                    $cmbToolCategory.Text = $currentValue
                }
                elseif ($cmbToolCategory.Items.Count -gt 0) {
                    $cmbToolCategory.SelectedIndex = 0
                }
            }
        }

        function Remove-ToolRef {
            param($Config, $ToolName)
            foreach ($tab in $Config.Tabs) {
                if ($tab.Tools) { $tab.Tools = $tab.Tools | Where-Object { $_.Name -ne $ToolName } }
                if ($tab.Groups) {
                    foreach ($grp in $tab.Groups) {
                        if ($grp.Tools) { $grp.Tools = $grp.Tools | Where-Object { $_.Name -ne $ToolName } }
                    }
                }
            }
        }


        
        $script:RefreshSettingsToolList = {
            $expandedState = @{}
            foreach ($item in $treeTools.Items) {
                $id = if ($item.Tag -and $item.Tag.Name) { $item.Tag.Name } else { $item.Header }
                if ($item.IsExpanded) { $expandedState[$id] = $true }
                
                foreach ($sub in $item.Items) {
                    $subId = if ($sub.Tag -and $sub.Tag.Name) { $sub.Tag.Name } else { $sub.Header }
                    if ($sub.IsExpanded) { $expandedState[$subId] = $true }
                }
            }

            $treeTools.Items.Clear()
            $searchTerm = $searchTools.Text
            $isSearching = -not [string]::IsNullOrWhiteSpace($searchTerm)
            $defaultExpanded = $isSearching

            foreach ($tab in $script:tempConfig.Tabs) {
                # Create Category Item
                $catItem = New-Object System.Windows.Controls.TreeViewItem
                
                # Header with CheckBox
                $headerStack = New-Object System.Windows.Controls.StackPanel
                $headerStack.Orientation = "Horizontal"
                
                $chkVisible = New-Object System.Windows.Controls.CheckBox
                $chkVisible.Margin = "0,0,8,0"
                $chkVisible.VerticalAlignment = "Center"
                $chkVisible.Focusable = $false # Prevent stealing focus from row
                # Default Visible = $true
                $isVis = $true
                if ($tab.PSObject.Properties['Visible']) { 
                    $isVis = $tab.Visible 
                }
                else {
                    # Force creation if missing
                    $tab | Add-Member -MemberType NoteProperty -Name "Visible" -Value $true
                }
                $chkVisible.IsChecked = $isVis
                
                # Capture $tab for event closure
                $targetTab = $tab
                $chkVisible.Add_Checked({ 
                        # Use Add-Member -Force to ensure we can update/set the property safely
                        $targetTab | Add-Member -MemberType NoteProperty -Name "Visible" -Value $true -Force
                    }.GetNewClosure())
                $chkVisible.Add_Unchecked({ 
                        $targetTab | Add-Member -MemberType NoteProperty -Name "Visible" -Value $false -Force
                    }.GetNewClosure())
                
                $headerTitle = New-Object System.Windows.Controls.TextBlock
                $headerTitle.Text = $tab.Title
                $headerTitle.VerticalAlignment = "Center"
                
                [void]$headerStack.Children.Add($chkVisible)
                [void]$headerStack.Children.Add($headerTitle)
                
                $catItem.Header = $headerStack
                $catItem.Tag = [PSCustomObject]@{ _Type = "CATEGORY"; Name = $tab.Title } 
                
                $shouldExpand = $defaultExpanded
                if ($expandedState.ContainsKey($tab.Title)) { $shouldExpand = $true }
                $catItem.IsExpanded = $shouldExpand
                
                $catItem.FontSize = 15
                $catItem.FontWeight = "Bold"
                
                # Groups
                if ($tab.Groups) {
                    foreach ($group in $tab.Groups) {
                        $groupItem = New-Object System.Windows.Controls.TreeViewItem
                        $groupItem.Header = $group.Title
                        $groupItem.Tag = [PSCustomObject]@{ _Type = "GROUP"; Name = $group.Title; _Category = $tab.Title }
                        
                        $grpExpand = $defaultExpanded
                        if ($expandedState.ContainsKey($group.Title)) { $grpExpand = $true }
                        $groupItem.IsExpanded = $grpExpand
                        
                        $groupItem.FontSize = 14
                        

                        
                        if ($group.Tools) {
                            foreach ($tool in $group.Tools) {
                                if ([string]::IsNullOrWhiteSpace($searchTerm) -or $tool.Name -match $searchTerm) {
                                    $tool | Add-Member -MemberType NoteProperty -Name "_Category" -Value $tab.Title -Force
                                    $tool | Add-Member -MemberType NoteProperty -Name "_IsGroup" -Value $true -Force
                                    $tool | Add-Member -MemberType NoteProperty -Name "_GroupName" -Value $group.Title -Force
                                    $tool | Add-Member -MemberType NoteProperty -Name "_Type" -Value "TOOL" -Force

                                    $toolItem = New-Object System.Windows.Controls.TreeViewItem
                                    
                                    $stack = New-Object System.Windows.Controls.StackPanel
                                    $stack.Orientation = "Horizontal"
                                    $iconBlock = New-Object System.Windows.Controls.TextBlock
                                    $iconBlock.Text = $tool.Icon
                                    $iconBlock.Margin = "0,0,8,0"
                                    $nameBlock = New-Object System.Windows.Controls.TextBlock
                                    $nameBlock.Text = $tool.Name
                                    $stack.Children.Add($iconBlock)
                                    $stack.Children.Add($nameBlock)
                                    
                                    $toolItem.Header = $stack
                                    $toolItem.Tag = $tool
                                    $toolItem.FontWeight = "Normal"
                                    [void]$groupItem.Items.Add($toolItem)
                                }
                            }
                        }
                        # Always add group, even if empty, to allow adding tools to it
                        [void]$catItem.Items.Add($groupItem)
                    }
                }
                
                # Direct Tools
                if ($tab.Tools) {
                    foreach ($tool in $tab.Tools) {
                        if ([string]::IsNullOrWhiteSpace($searchTerm) -or $tool.Name -match $searchTerm) {
                            # Add Metadata for Logic
                            $tool | Add-Member -MemberType NoteProperty -Name "_Category" -Value $tab.Title -Force
                            $tool | Add-Member -MemberType NoteProperty -Name "_IsGroup" -Value $false -Force
                            $tool | Add-Member -MemberType NoteProperty -Name "_Type" -Value "TOOL" -Force
                            
                            $toolItem = New-Object System.Windows.Controls.TreeViewItem
                            
                            $stack = New-Object System.Windows.Controls.StackPanel
                            $stack.Orientation = "Horizontal"
                            $iconBlock = New-Object System.Windows.Controls.TextBlock
                            $iconBlock.Text = $tool.Icon
                            $iconBlock.Margin = "0,0,8,0"
                            $nameBlock = New-Object System.Windows.Controls.TextBlock
                            $nameBlock.Text = $tool.Name
                            $stack.Children.Add($iconBlock)
                            $stack.Children.Add($nameBlock)
                            
                            $toolItem.Header = $stack
                            $toolItem.Tag = $tool
                            $toolItem.FontWeight = "Normal"
                            [void]$catItem.Items.Add($toolItem)
                        }
                    }
                }
                
                # Always add category, even if empty
                [void]$treeTools.Items.Add($catItem)
            }
        }
        # --- Drag & Drop Support ---
        $script:DragStartPoint = $null
        
        function Get-TreeViewItemAtPoint ($tree, $point) {
            $hitTest = $tree.InputHitTest($point)
            while ($hitTest -ne $null -and -not ($hitTest -is [System.Windows.Controls.TreeViewItem])) {
                $hitTest = [System.Windows.Media.VisualTreeHelper]::GetParent($hitTest)
            }
            return $hitTest
        }

        function Move-Tool ($Config, $SourceToolName, $TargetToolName, $TargetIsGroup, $InsertAfterOverride = $null) {
            # 1. LOCATE SOURCE
            $sourceContainer = $null
            $sourceIndex = -1
            $sourceTool = $null

            foreach ($t in $Config.Tabs) {
                if ($t.Tools) {
                    for ($i = 0; $i -lt $t.Tools.Count; $i++) {
                        if ($t.Tools[$i].Name -eq $SourceToolName) {
                            $sourceContainer = $t
                            $sourceIndex = $i
                            $sourceTool = $t.Tools[$i]
                            break
                        }
                    }
                }
                if ($sourceTool) { break }
            
                if ($t.Groups) {
                    foreach ($g in $t.Groups) {
                        if ($g.Tools) {
                            for ($i = 0; $i -lt $g.Tools.Count; $i++) {
                                if ($g.Tools[$i].Name -eq $SourceToolName) {
                                    $sourceContainer = $g
                                    $sourceIndex = $i
                                    $sourceTool = $g.Tools[$i]
                                    break
                                }
                            }
                        }
                        if ($sourceTool) { break }
                    }
                }
                if ($sourceTool) { break }
            }

            if (-not $sourceTool) { return $false }

            # 2. LOCATE TARGET CONTAINER & INDEX
            $targetContainer = $null
            $targetIndex = -1
            $isAppend = $false

            foreach ($t in $Config.Tabs) {
                # Case A: Target is a Category (Append to Category)
                if ($t.Title -eq $TargetToolName -and $TargetIsGroup) {
                    $targetContainer = $t
                    $isAppend = $true
                    break
                }
            
                # Case B: Target is a Tool in Category
                if ($t.Tools) {
                    for ($i = 0; $i -lt $t.Tools.Count; $i++) {
                        if ($t.Tools[$i].Name -eq $TargetToolName) {
                            $targetContainer = $t
                            $targetIndex = $i
                            break
                        }
                    }
                }
                if ($targetContainer) { break }

                if ($t.Groups) {
                    foreach ($g in $t.Groups) {
                        # Case C: Target is a Group (Append to Group)
                        if ($g.Title -eq $TargetToolName -and $TargetIsGroup) {
                            $targetContainer = $g
                            $isAppend = $true
                            break
                        }

                        # Case D: Target is a Tool in Group
                        if ($g.Tools) {
                            for ($i = 0; $i -lt $g.Tools.Count; $i++) {
                                if ($g.Tools[$i].Name -eq $TargetToolName) {
                                    $targetContainer = $g
                                    $targetIndex = $i
                                    break
                                }
                            }
                        }
                        if ($targetContainer) { break }
                    }
                }
                if ($targetContainer) { break }
            }

            if (-not $targetContainer) { return $false }

            # 3. EXECUTE MOVE
            # Convert Source and Target lists to ArrayLists for manipulation
        
            # Helper to get list ref (Since we need to assign back to property)
            # We will use the container object found.
        
            # Remove from Source
            $srcList = [System.Collections.ArrayList]$sourceContainer.Tools
            $srcList.RemoveAt($sourceIndex)
            $sourceContainer.Tools = $srcList.ToArray()

            # Insert into Target
            # Logic Fix for Up/Down Direction:
            $insertPos = 0
            
            if ($sourceContainer -eq $targetContainer) {
                # Same Container Reordering
                if ($targetIndex -lt $sourceIndex) {
                    # Moving Up (Target is above Source) -> Insert Before Target
                    # Note: TargetIndex refers to the item that is CURRENTLY at that position.
                    $insertPos = $targetIndex
                }
                else {
                    # Moving Down (Target is below Source) -> Insert After Target
                    # Note: Since we removed Source (which was before Target), Target shifted down.
                    # But we adjusted TargetIndex in step 3A. So TargetIndex points to the Target item.
                    $insertPos = $targetIndex + 1
                }
            }
            else {
                # Different Container -> Always Insert After Target
                $insertPos = $targetIndex + 1
            }

            if (-not $targetContainer.Tools) { $targetContainer.Tools = @() }
            $tgtList = [System.Collections.ArrayList]$targetContainer.Tools

            if ($isAppend) {
                [void]$tgtList.Add($sourceTool)
            }
            else {
                if ($insertPos -lt 0) { $insertPos = 0 }
                if ($insertPos -gt $tgtList.Count) { $insertPos = $tgtList.Count }
                $tgtList.Insert($insertPos, $sourceTool)
            }
            
            $targetContainer.Tools = $tgtList.ToArray()
            return $true
        }

        function Move-Category ($Config, $SourceTitle, $TargetTitle, $InsertAfterOverride = $null) {
            $tabs = [System.Collections.ArrayList]$Config.Tabs
            $srcIdx = -1; $tgtIdx = -1
            
            for ($i = 0; $i -lt $tabs.Count; $i++) {
                if ($tabs[$i].Title -eq $SourceTitle) { $srcIdx = $i }
                if ($tabs[$i].Title -eq $TargetTitle) { $tgtIdx = $i }
            }
            
            if ($srcIdx -eq -1 -or $tgtIdx -eq -1) { return $false }
            
            $item = $tabs[$srcIdx]
            $tabs.RemoveAt($srcIdx)
            
            # Recalculate target index because removal might have shifted it
            for ($i = 0; $i -lt $tabs.Count; $i++) {
                if ($tabs[$i].Title -eq $TargetTitle) { $tgtIdx = $i; break }
            }
            
            $insertPos = 0
            if ($InsertAfterOverride -ne $null) {
                if ($InsertAfterOverride) { $insertPos = $tgtIdx + 1 }
                else { $insertPos = $tgtIdx }
            }
            else {
                $insertPos = $tgtIdx # Default logic could be implied or dumb, we prefer override
            }
            
            if ($insertPos -gt $tabs.Count) { $insertPos = $tabs.Count }
            $tabs.Insert($insertPos, $item)
            
            $Config.Tabs = $tabs.ToArray()
            return $true
        }

        function Move-Group ($Config, $SourceTitle, $TargetTitle, $CategoryName, $InsertAfterOverride = $null) {
            $tab = ($Config.Tabs | Where-Object { $_.Title -eq $CategoryName })[0]
            if (-not $tab -or -not $tab.Groups) { return $false }
            
            $groups = [System.Collections.ArrayList]$tab.Groups
            $srcIdx = -1; $tgtIdx = -1
            
            for ($i = 0; $i -lt $groups.Count; $i++) {
                if ($groups[$i].Title -eq $SourceTitle) { $srcIdx = $i }
                if ($groups[$i].Title -eq $TargetTitle) { $tgtIdx = $i }
            }
            
            if ($srcIdx -eq -1 -or $tgtIdx -eq -1) { return $false }
            
            $item = $groups[$srcIdx]
            $groups.RemoveAt($srcIdx)
            
            # Recalculate target index because removal might have shifted it
            for ($i = 0; $i -lt $groups.Count; $i++) {
                if ($groups[$i].Title -eq $TargetTitle) { $tgtIdx = $i; break }
            }
            
            $insertPos = 0
            if ($InsertAfterOverride -ne $null) {
                if ($InsertAfterOverride) { $insertPos = $tgtIdx + 1 }
                else { $insertPos = $tgtIdx }
            }
            else {
                $insertPos = $tgtIdx 
            }

            if ($insertPos -gt $groups.Count) { $insertPos = $groups.Count }
            $groups.Insert($insertPos, $item)
            
            $tab.Groups = $groups.ToArray()
            return $true
        }

        function Init-DragDrop {
            $treeTools.Add_PreviewMouseLeftButtonDown({
                    param($sender, $e)
                    $script:DragStartPoint = $e.GetPosition($null)
                })

            $treeTools.Add_MouseMove({
                    param($sender, $e)
                    if ($e.LeftButton -eq [System.Windows.Input.MouseButtonState]::Pressed -and $script:DragStartPoint) {
                        $pos = $e.GetPosition($null)
                        $diffX = [Math]::Abs($pos.X - $script:DragStartPoint.X)
                        $diffY = [Math]::Abs($pos.Y - $script:DragStartPoint.Y)

                        if ($diffX -gt 5 -or $diffY -gt 5) {
                            $tvi = Get-TreeViewItemAtPoint $treeTools $e.GetPosition($treeTools)
                            # Tag is now always PSCustomObject due to Refresh update
                            if ($tvi -and $tvi.Tag -is [System.Management.Automation.PSCustomObject]) {
                                $script:DragSourceItem = $tvi
                                $data = New-Object System.Windows.DataObject
                                $data.SetData("ToolObject", $tvi.Tag)
                                [System.Windows.DragDrop]::DoDragDrop($treeTools, $data, [System.Windows.DragDropEffects]::Move)
                            }
                        }
                    }
                })

            $treeTools.Add_DragOver({
                    param($sender, $e)
                    $targetItem = Get-TreeViewItemAtPoint $treeTools $e.GetPosition($treeTools)
                    
                    # Default state
                    $dragInsertLine.Visibility = [System.Windows.Visibility]::Collapsed
                    $e.Effects = [System.Windows.DragDropEffects]::None
                    $e.Handled = $true
                    
                    if ($targetItem -and $script:DragSourceItem) {
                        $sourceTag = $script:DragSourceItem.Tag
                        $targetTag = $targetItem.Tag
                         
                        $allowed = $false
                         
                        if ($sourceTag._Type -eq "CATEGORY") {
                            if ($targetTag._Type -eq "CATEGORY") { $allowed = $true }
                        }
                        elseif ($sourceTag._Type -eq "GROUP") {
                            if ($targetTag._Type -eq "GROUP" -and $sourceTag._Category -eq $targetTag._Category) { $allowed = $true }
                        }
                        else {
                            # TOOL matching logic
                            $sourceCat = $sourceTag._Category
                            $targetCat = ""
                            if ($targetTag._Type -eq "TOOL") { $targetCat = $targetTag._Category }
                            elseif ($targetTag._Type -eq "GROUP") { $targetCat = $targetTag._Category }
                            elseif ($targetTag._Type -eq "CATEGORY") { $targetCat = $targetTag.Name }
                             
                            if ($sourceCat -eq $targetCat) { $allowed = $true }
                        }
                         
                        if (-not $allowed) {
                            return
                        }
                         
                        $e.Effects = [System.Windows.DragDropEffects]::Move
                        
                        # Calculate Position Relative to TARGET ITEM
                        $tgtPos = $targetItem.TranslatePoint((New-Object System.Windows.Point(0, 0)), $treeTools)
                        $mousePosInItem = $e.GetPosition($targetItem)
                        
                        $tgtH = $targetItem.ActualHeight
                        $tgtW = $targetItem.ActualWidth
                        $tgtX = $tgtPos.X
                        $tgtY = $tgtPos.Y

                        $lineY = 0
                        
                        # Logic: Top half = Insert Before, Bottom half = Insert After
                        if ($mousePosInItem.Y -lt ($tgtH / 2)) {
                            # Top Half -> Insert Before
                            $lineY = $tgtY
                            $script:DragInsertAfter = $false
                        }
                        else {
                            # Bottom Half -> Insert After
                            $lineY = $tgtY + $tgtH
                            $script:DragInsertAfter = $true
                        }
                        
                        $dragInsertLine.Width = $tgtW
                        $dragInsertLine.Margin = "$tgtX,$lineY,0,0"
                        $dragInsertLine.Visibility = [System.Windows.Visibility]::Visible
                    }
                })

            $treeTools.Add_DragLeave({
                    $dragInsertLine.Visibility = [System.Windows.Visibility]::Collapsed
                })

            $treeTools.Add_Drop({
                    param($sender, $e)
                    $dragInsertLine.Visibility = [System.Windows.Visibility]::Collapsed
                    
                    if ($e.Data.GetDataPresent("ToolObject")) {
                        $sourceTag = $e.Data.GetData("ToolObject")
                        $targetItem = Get-TreeViewItemAtPoint $treeTools $e.GetPosition($treeTools)
                        $insertAfter = $script:DragInsertAfter # Get the decision from DragOver
                    
                        if ($targetItem) {
                            $targetTag = $targetItem.Tag
                            $res = $false
                            
                            if ($sourceTag._Type -eq "CATEGORY" -and $targetTag._Type -eq "CATEGORY") {
                                if ($sourceTag.Name -ne $targetTag.Name) {
                                    $res = Move-Category -Config $script:tempConfig -SourceTitle $sourceTag.Name -TargetTitle $targetTag.Name -InsertAfterOverride $insertAfter
                                }
                            }
                            elseif ($sourceTag._Type -eq "GROUP" -and $targetTag._Type -eq "GROUP") {
                                if ($sourceTag._Category -eq $targetTag._Category -and $sourceTag.Name -ne $targetTag.Name) {
                                    $res = Move-Group -Config $script:tempConfig -SourceTitle $sourceTag.Name -TargetTitle $targetTag.Name -CategoryName $sourceTag._Category -InsertAfterOverride $insertAfter
                                }
                            }
                            elseif ($sourceTag._Type -eq "TOOL") {
                                if ($targetTag._Type -eq "TOOL" -and $sourceTag.Name -ne $targetTag.Name) {
                                    $res = Move-Tool -Config $script:tempConfig -SourceToolName $sourceTag.Name -TargetToolName $targetTag.Name -TargetIsGroup $false -InsertAfterOverride $insertAfter
                                }
                            }
                            
                            if ($res) {
                                & $script:RefreshSettingsToolList
                                $toolsStatusText.Text = "Movido (Pendiente guardar)."
                            }
                        }
                    }
                })
        }
        function Swap-Tools ($itemTag, $direction) {
            # $itemTag is the Tool Object (PSCustomObject)
            # $direction is -1 (Up) or 1 (Down)
            
            if (-not $itemTag) { return $false }
            
            # Find Parent Tab
            $tab = ($script:tempConfig.Tabs | Where-Object { $_.Title -eq $itemTag._Category })[0]
            if (-not $tab) { return $false }
            
            # Find Target List (Group or Direct)
            $targetList = $null
            
            if ($itemTag._IsGroup) {
                # It's inside a Group
                # Note: We need _GroupName on the tool. ensure Refresh-SettingsToolList added it.
                # My previous replacement for Refresh-SettingsToolList DID NOT add _GroupName for group items!
                # I need to fix Refresh-SettingsToolList to add _GroupName if missing, 
                # OR finding the group by iterating is safer.
                
                # Check if we have _GroupName property
                if ($itemTag | Get-Member -Name "_GroupName") {
                    $grp = ($tab.Groups | Where-Object { $_.Title -eq $itemTag._GroupName })[0]
                    if ($grp) { $targetList = $grp.Tools }
                }
                else {
                    # Fallback: Search all groups
                    if ($tab.Groups) {
                        foreach ($g in $tab.Groups) {
                            if ($g.Tools) {
                                foreach ($t in $g.Tools) {
                                    if ($t.Name -eq $itemTag.Name) { $targetList = $g.Tools; break }
                                }
                            }
                            if ($targetList) { break }
                        }
                    }
                }
            }
            else {
                $targetList = $tab.Tools
            }
            
            if ($targetList) {
                $idx = -1
                for ($i = 0; $i -lt $targetList.Count; $i++) {
                    if ($targetList[$i].Name -eq $itemTag.Name) { $idx = $i; break }
                }
                
                if ($idx -ne -1) {
                    $newIdx = $idx + $direction
                    if ($newIdx -ge 0 -and $newIdx -lt $targetList.Count) {
                        $temp = $targetList[$idx]
                        $targetList[$idx] = $targetList[$newIdx]
                        $targetList[$newIdx] = $temp
                        return $true
                    }
                }
            }
            return $false
        }

        # Events
        # Events
        
        # Helper for Dynamic Button Visibility
        $script:UpdateClearButtonState = {
            if ($btnToolClear.Content -eq "Nuevo") {
                # Edit Mode: Always Visible (to allow Cancel)
                $btnToolClear.Visibility = [System.Windows.Visibility]::Visible
            }
            else {
                # Creation Mode ("Limpiar"): Only Visible if there is text
                $hasText = ($txtToolName.Text.Length -gt 0) -or 
                ($txtToolUrl.Text.Length -gt 0) -or 
                ($txtToolDesc.Text.Length -gt 0) -or 
                ($txtToolTags.Text.Length -gt 0)
                
                if ($hasText) {
                    $btnToolClear.Visibility = [System.Windows.Visibility]::Visible
                }
                else {
                    $btnToolClear.Visibility = [System.Windows.Visibility]::Collapsed
                }
            }
        }

        # Attach Listeners to Inputs
        $txtToolName.Add_TextChanged($script:UpdateClearButtonState)
        $txtToolUrl.Add_TextChanged($script:UpdateClearButtonState)
        $txtToolDesc.Add_TextChanged($script:UpdateClearButtonState)
        $txtToolTags.Add_TextChanged($script:UpdateClearButtonState)

        $treeTools.Add_SelectedItemChanged({
                $selectedItem = $treeTools.SelectedItem
                
                # Default: Clear Form
                $txtToolName.Text = ""; $txtToolUrl.Text = ""; $txtToolDesc.Text = ""; $txtToolTags.Text = ""
                $btnToolDelete.Visibility = [System.Windows.Visibility]::Collapsed
                
                # Default button state for "New"
                $btnToolClear.Content = "Limpiar"
                $btnToolSave.Content = "Agregar"
                $toolsStatusText.Text = "Modo: Nueva Herramienta"
                
                if ($selectedItem) {
                    $tag = $selectedItem.Tag
                    
                    if ($tag -is [System.Management.Automation.PSCustomObject]) {
                        if ($tag._Type -eq "TOOL") {
                            # Populate Form
                            $txtToolName.Text = $tag.Name
                            $txtToolUrl.Text = $tag.URL
                            $txtToolDesc.Text = $tag.Desc
                            $txtToolTags.Text = $tag.Tags
                            
                            # Sync Category Combo
                            if ($null -ne $cmbToolCategory) {
                                $cmbToolCategory.Text = $tag._Category
                            }
                            
                            $btnToolDelete.Visibility = [System.Windows.Visibility]::Visible
                            $btnToolClear.Content = "Nuevo"
                            $btnToolSave.Content = "Aplicar"
                            $toolsStatusText.Text = "Editando: $($tag.Name)"
                        }
                        elseif ($tag._Type -eq "CATEGORY") {
                            $toolsStatusText.Text = "Categoría seleccionada: $($tag.Name)"
                        }
                        elseif ($tag._Type -eq "GROUP") {
                            $toolsStatusText.Text = "Grupo seleccionado: $($tag.Name)"
                        }
                    }
                }
                
                $script:UpdateClearButtonState.Invoke()
            })
        # Update Visibility based on new state
        & $script:UpdateClearButtonState
        
        $btnToolClear.Add_Click({
                $treeTools.Focus()
                # Reset to "New" mode
                $txtToolName.Text = ""; $txtToolUrl.Text = ""; $txtToolDesc.Text = ""; $txtToolTags.Text = ""
                
                $btnToolDelete.Visibility = [System.Windows.Visibility]::Collapsed
                
                $toolsStatusText.Text = "Modo: Nueva Herramienta"
                $btnToolClear.Content = "Limpiar"
                $btnToolSave.Content = "Agregar"
                
                # Force Update
                if ($script:UpdateClearButtonState -is [ScriptBlock]) { & $script:UpdateClearButtonState }
            })
            
        # --- NEW MANAGEMENT BUTTONS LOGIC ---
        
        $btnNewTab.Add_Click({
                try {
                    # Auto-Generate Name
                    $baseName = "Nueva Pestaña"
                    $count = 1
                    $name = "$baseName $count"
                
                    # Ensure Tabs exist
                    if (-not $script:tempConfig.PSObject.Properties['Tabs']) {
                        $script:tempConfig | Add-Member -MemberType NoteProperty -Name "Tabs" -Value @()
                    }

                    $existingNames = if ($script:tempConfig.Tabs) { $script:tempConfig.Tabs.Title } else { @() }
                
                    while ($existingNames -contains $name) {
                        $count++
                        $name = "$baseName $count"
                    }

                    $newTab = [PSCustomObject]@{
                        Title  = $name
                        Tools  = @()
                        Groups = @()
                    }
                
                    # Add to ArrayList
                    $tabsFlag = [System.Collections.ArrayList]$script:tempConfig.Tabs
                    [void]$tabsFlag.Add($newTab)
                    $script:tempConfig.Tabs = $tabsFlag.ToArray()
                
                    # Refresh-ToolCategories Removed
                    & $script:RefreshCategoryCombo
                    & $script:RefreshSettingsToolList
                    
                    # Auto-Select New Tab
                    foreach ($item in $treeTools.Items) {
                        if ($item.Tag -and $item.Tag.Name -eq $name) {
                            $item.IsSelected = $true
                            $treeTools.Focus() | Out-Null
                            $item.Focus() | Out-Null
                            break
                        }
                    }
                }
                catch {
                    Show-ToolNotification -Title "Error Crítico" -Message "Error al crear pestaña: $_" -Icon "Error" -Owner $settingsWindow
                    Write-Error $_
                }
            })
        
        $btnNewGroup.Add_Click({
                try {
                    $selItem = $treeTools.SelectedItem
                    if ($selItem -and $selItem.Tag -is [System.Management.Automation.PSCustomObject]) {
                        $tag = $selItem.Tag
                        $targetCatName = ""
                    
                        if ($tag._Type -eq "CATEGORY") { $targetCatName = $tag.Name }
                        elseif ($tag._Type -eq "GROUP" -or $tag._Type -eq "TOOL") { $targetCatName = $tag._Category }
                    
                        if ($targetCatName) {
                            # Find Category
                            $targetTab = ($script:tempConfig.Tabs | Where-Object { $_.Title -eq $targetCatName })[0]
                            if ($targetTab) {
                                # Ensure Groups property exists properly
                                if (-not $targetTab.PSObject.Properties['Groups']) {
                                    $targetTab | Add-Member -MemberType NoteProperty -Name "Groups" -Value @()
                                }
                            
                                # Auto-Generate Name
                                $baseName = "Nuevo Grupo"
                                $count = 1
                                $name = "$baseName $count"
                            
                                $existingNames = if ($targetTab.Groups) { $targetTab.Groups.Title } else { @() }
                                while ($existingNames -contains $name) {
                                    $count++
                                    $name = "$baseName $count"
                                }
                            
                                $newGroup = [PSCustomObject]@{
                                    Title = $name
                                    Tools = @()
                                }
                            
                                $grpsList = [System.Collections.ArrayList]$targetTab.Groups
                                [void]$grpsList.Add($newGroup)
                                $targetTab.Groups = $grpsList.ToArray()
                            
                                & $script:RefreshSettingsToolList
                            
                                # Auto-Select New Group
                                foreach ($item in $treeTools.Items) {
                                    if ($item.Tag -and $item.Tag.Name -eq $targetCatName) {
                                        # Parent Cat
                                        $item.IsExpanded = $true
                                        $treeTools.Focus() | Out-Null
                                        foreach ($sub in $item.Items) {
                                            if ($sub.Tag -and $sub.Tag.Name -eq $name) {
                                                $sub.IsSelected = $true
                                                $sub.Focus() | Out-Null
                                                break
                                            }
                                        }
                                        break
                                    }
                                }
                            }
                        }
                        else {
                            Show-ToolNotification -Title "Aviso" -Message "Selecciona una categoría primero." -Owner $settingsWindow
                        }
                    }
                    else {
                        Show-ToolNotification -Title "Aviso" -Message "Selecciona una categoría para agregar un grupo." -Owner $settingsWindow
                    }
                }
                catch {
                    Show-ToolNotification -Title "Error Crítico" -Message "Error al crear grupo: $_" -Icon "Error" -Owner $settingsWindow
                    Write-Error $_
                }
            })    

        
        $btnRename.Add_Click({
                $selItem = $treeTools.SelectedItem
                if ($selItem -and $selItem.Tag -is [System.Management.Automation.PSCustomObject]) {
                    $tag = $selItem.Tag
                
                    if ($tag._Type -eq "CATEGORY") {
                        $newName = Show-InputDialog -Title "Renombrar Categoría" -Message "Nuevo nombre:" -DefaultText $tag.Name -Owner $settingsWindow
                        if (-not [string]::IsNullOrWhiteSpace($newName) -and $newName -ne $tag.Name) {
                            # Update Title
                            $targetTab = ($script:tempConfig.Tabs | Where-Object { $_.Title -eq $tag.Name })[0]
                            if ($targetTab) { 
                                $targetTab.Title = $newName 
                                # Refresh-ToolCategories Removed
                                & $script:RefreshCategoryCombo
                                & $script:RefreshSettingsToolList
                            }
                        }
                    }
                    elseif ($tag._Type -eq "GROUP") {
                        $newName = Show-InputDialog -Title "Renombrar Grupo" -Message "Nuevo nombre:" -DefaultText $tag.Name -Owner $settingsWindow
                        if (-not [string]::IsNullOrWhiteSpace($newName) -and $newName -ne $tag.Name) {
                            # Find Parent Tab then Group
                            $targetTab = ($script:tempConfig.Tabs | Where-Object { $_.Title -eq $tag._Category })[0]
                            if ($targetTab -and $targetTab.Groups) {
                                $targetGrp = ($targetTab.Groups | Where-Object { $_.Title -eq $tag.Name })[0]
                                if ($targetGrp) {
                                    $targetGrp.Title = $newName
                                    & $script:RefreshSettingsToolList
                                }
                            }
                        }
                    }
                    else {
                        Show-ToolNotification -Title "Aviso" -Message "Solo se pueden renombrar Categorías y Grupos desde aquí. Para herramientas usa el formulario." -Owner $settingsWindow
                    }
                }
                else {
                    Show-ToolNotification -Title "Aviso" -Message "Selecciona una Categoría o Grupo para renombrar." -Owner $settingsWindow
                }
            })

        $btnToolSave.Add_Click({
                try {
                    $newName = $txtToolName.Text
                    if ([string]::IsNullOrWhiteSpace($newName)) {
                        Show-ToolNotification -Title "Error" -Message "El nombre es obligatorio." -Icon "Error" -Owner $settingsWindow
                        return
                    }

                    # Determine Target Helper
                    $targetCatName = ""
                    $targetGroupName = ""
                    
                    $selItem = $treeTools.SelectedItem
                    
                    $isEdit = ($btnToolSave.Content -eq "Aplicar")
                    $editToolRef = $null
                    
                    if ($isEdit) {
                        if ($selItem -and $selItem.Tag -is [System.Management.Automation.PSCustomObject] -and $selItem.Tag._Type -eq "TOOL") {
                            $editToolRef = $selItem.Tag
                            $targetCatName = $editToolRef._Category
                            if ($editToolRef._IsGroup) { $targetGroupName = $editToolRef._GroupName }
                        }
                    } 
                    else {
                        # NEW Tool Logic
                        if ($selItem -and $selItem.Tag -is [System.Management.Automation.PSCustomObject]) {
                            $tag = $selItem.Tag
                            
                            if ($tag._Type -eq "CATEGORY") {
                                $targetCatName = $tag.Name
                            }
                            elseif ($tag._Type -eq "GROUP") {
                                $targetCatName = $tag._Category
                                $targetGroupName = $tag.Name
                            }
                            elseif ($tag._Type -eq "TOOL") {
                                # Sibling
                                $targetCatName = $tag._Category
                                if ($tag._IsGroup) {
                                    $targetGroupName = $tag._GroupName
                                }
                            }
                        }
                        
                        if (-not $targetCatName) {
                            # Fallback
                            if ($script:tempConfig.Tabs.Count -gt 0) {
                                $targetCatName = $script:tempConfig.Tabs[0].Title
                            }
                            else {
                                Show-ToolNotification -Title "Error" -Message "No hay categorías. Crea una primero." -Icon "Error" -Owner $settingsWindow
                                return
                            }
                        }
                    }

                    # Logic to Add/Update
                    if ($isEdit) {
                        # Just update properties
                        $editToolRef.Name = $newName
                        $editToolRef.URL = $txtToolUrl.Text
                        $editToolRef.Desc = $txtToolDesc.Text
                        $editToolRef.Tags = $txtToolTags.Text
                        
                        # Handle Category Change if implemented (currently just visual sync)
                        # ...
                        
                        Show-ToolNotification -Title "Guardado" -Message "Herramienta actualizada." -Owner $settingsWindow
                    }
                    else {
                        # Create New Tool
                        $newTool = [PSCustomObject]@{
                            Name = $newName
                            URL  = $txtToolUrl.Text
                            Desc = $txtToolDesc.Text
                            Tags = $txtToolTags.Text
                        }
                        
                        # Add to Config
                        $tab = ($script:tempConfig.Tabs | Where-Object { $_.Title -eq $targetCatName })[0]
                        
                        if ($targetGroupName) {
                            $grp = ($tab.Groups | Where-Object { $_.Title -eq $targetGroupName })[0]
                            if (-not $grp.PSObject.Properties['Tools']) { $grp | Add-Member -MemberType NoteProperty -Name "Tools" -Value @() }
                            
                            $tList = [System.Collections.ArrayList]$grp.Tools
                            [void]$tList.Add($newTool)
                            $grp.Tools = $tList.ToArray()
                        }
                        else {
                            if (-not $tab.PSObject.Properties['Tools']) { $tab | Add-Member -MemberType NoteProperty -Name "Tools" -Value @() }
                            
                            $tList = [System.Collections.ArrayList]$tab.Tools
                            [void]$tList.Add($newTool)
                            $tab.Tools = $tList.ToArray()
                        }
                        Show-ToolNotification -Title "Guardado" -Message "Herramienta creada en '$targetCatName'." -Owner $settingsWindow
                    }

                    & $script:RefreshSettingsToolList
                    
                    if (-not $isEdit) {
                        $txtToolName.Text = ""; $txtToolUrl.Text = ""; $txtToolDesc.Text = ""; $txtToolTags.Text = ""
                    }
                    
                }
                catch {
                    Show-ToolNotification -Title "Error" -Message "Error al guardar: $_" -Icon "Error" -Owner $settingsWindow
                    Write-Error $_
                }
            })
        
        $btnToolDelete.Add_Click({
                $selItem = $treeTools.SelectedItem
                if ($selItem -and $selItem.Tag -is [System.Management.Automation.PSCustomObject]) {
                    $name = $selItem.Tag.Name
                    Remove-ToolRef -Config $script:tempConfig -ToolName $name
                
                
                    # In-Memory Only
                    & $script:RefreshSettingsToolList
                    $btnToolClear.RaiseEvent((New-Object System.Windows.RoutedEventArgs -ArgumentList ([System.Windows.Controls.Button]::ClickEvent)))
                    $toolsStatusText.Text = "Herramienta eliminada (Pendiente guardar)."
                }
            })

        # Move Up/Down Logic Removed - Using Drag & Drop instead

        # --- Backup Logic ---
        $btnCreateBackup = $settingsWindow.FindName("BtnCreateBackup")
        $listBackups = $settingsWindow.FindName("ListBackups")
        $btnRestore = $settingsWindow.FindName("BtnRestore")
        $btnDeleteBackup = $settingsWindow.FindName("BtnDeleteBackup")
        
        # $backupDir defined at top

        function Refresh-Backups {
            $listBackups.Items.Clear()
            $script:backupMapping = @{}
            
            $files = Get-ChildItem -Path $backupDir -Filter "*.json" | Sort-Object LastWriteTime -Descending
            foreach ($f in $files) {
                # Intentar extraer fecha exacta del nombre del archivo (yyyyMMdd_HHmm)
                $dateRaw = $f.LastWriteTime
                if ($f.Name -match '(\d{4})(\d{2})(\d{2})_(\d{2})(\d{2})') {
                    try {
                        $dateStr = "$($Matches[1])-$($Matches[2])-$($Matches[3]) $($Matches[4]):$($Matches[5])"
                        $dateRaw = [DateTime]::ParseExact($dateStr, "yyyy-MM-dd HH:mm", $null)
                    }
                    catch {}
                }

                $date = $dateRaw.ToString("dd MMM yyyy HH:mm")
                $type = if ($f.Name.StartsWith("auto")) { "Automática" } else { "Manual" }
                $displayName = "Copia $type ($date)"
                
                $listBackups.Items.Add($displayName)
                $script:backupMapping[$displayName] = $f.Name
            }
        }
        
        if ($listBackups) {
            # Safety check
            # ... (Rest of logic) ...
        }

        # INITIAL LOADS
        # Refresh-ToolCategories Removed
        & $script:RefreshCategoryCombo
        & $script:RefreshSettingsToolList
        Refresh-Backups
        
        # Initialize Drag & Drop Support
        Init-DragDrop

        $btnCreateBackup.Add_Click({
                try {
                    $timestamp = Get-Date -Format "yyyyMMdd_HHmm"
                    $dest = Join-Path $backupDir "config_$timestamp.json"
                
                    # Use global path for consistency
                    $currentConfigPath = Join-Path $global:InstallationRoot "config\config.json"
                    Copy-Item -Path $currentConfigPath -Destination $dest -Force
                
                    Refresh-Backups
                    Show-ToolNotification -Title "Backup" -Message "Backup guardado correctamente." -Icon "Information" -Owner $settingsWindow
                }
                catch {
                    [System.Windows.MessageBox]::Show("Error al crear backup: $_")
                }
            })

        $listBackups.Add_SelectionChanged({
                if ($listBackups.SelectedIndex -ge 0) {
                    $btnRestore.Visibility = [System.Windows.Visibility]::Visible
                    $btnDeleteBackup.Visibility = [System.Windows.Visibility]::Visible
                }
                else {
                    $btnRestore.Visibility = [System.Windows.Visibility]::Collapsed
                    $btnDeleteBackup.Visibility = [System.Windows.Visibility]::Collapsed
                }
            })

        $btnRestore.Add_Click({
                if ($listBackups.SelectedIndex -ge 0) {
                    $displayName = $listBackups.SelectedItem
                    $fileName = $script:backupMapping[$displayName]
                    if (-not $fileName) { return }
                    $fullPath = Join-Path $backupDir $fileName
                
                    $res = [System.Windows.MessageBox]::Show("¿Estás seguro de restaurar este backup?`nSe sobrescribirá la configuración actual.", "Confirmar Restauración", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
                
                    if ($res -eq "Yes") {
                        try {
                            # Pre-Backup current just in case
                            $preRestore = Join-Path $backupDir "pre_restore_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
                            $currentConfigPath = Join-Path $PSScriptRoot "..\config\config.json"
                            Copy-Item -Path $currentConfigPath -Destination $preRestore -Force
                        
                            # Restore
                            Copy-Item -Path $fullPath -Destination $currentConfigPath -Force
                        
                            # Reload Global
                            $script:config = Get-ConfigData -Path $script:configPath
                            $global:config = $script:config

                            # 1. ACTUALIZAR TODAS LAS VENTANAS AL INSTANTE
                            if (Get-Command Sync-GlobalTheme -ErrorAction SilentlyContinue) {
                                Sync-GlobalTheme -Config $script:config
                            }

                            if ($global:RefreshUIScript -is [ScriptBlock]) { & $global:RefreshUIScript }
                        
                            Show-ToolNotification -Title "Restaurado" -Message "Configuración restaurada con éxito." -Icon "Information" -Owner $settingsWindow
                        }
                        catch {
                            [System.Windows.MessageBox]::Show("Error al restaurar: $_")
                        }
                    }
                }
            })

        $btnDeleteBackup.Add_Click({
                if ($listBackups.SelectedIndex -ge 0) {
                    $displayName = $listBackups.SelectedItem
                    $fileName = $script:backupMapping[$displayName]
                    if (-not $fileName) { return }
                    $fullPath = Join-Path $backupDir $fileName
                    try {
                        Remove-Item -Path $fullPath -Force
                        Refresh-Backups
                    }
                    catch {
                        [System.Windows.MessageBox]::Show("Error al borrar: $_")
                    }
                }
            })

        # --- NEW: Delete All Backups ---
        $btnDeleteAll = $settingsWindow.FindName("BtnDeleteAllBackups")
        if ($btnDeleteAll) {
            $btnDeleteAll.Add_Click({
                    if ($listBackups.Items.Count -eq 0) {
                        Show-ToolNotification -Title "Backups" -Message "No hay backups para eliminar." -Icon "Information" -Owner $settingsWindow
                        return
                    }

                    $confirmed = Show-ConfirmDialog -Title "Confirmar Eliminación Total" `
                        -Message "¿Estás SEGURO de eliminar TODOS los backups?`n`nEsta acción no se puede deshacer." `
                        -Owner $settingsWindow
                
                    if ($confirmed) {
                        try {
                            Get-ChildItem -Path $backupDir -Filter "*.json" | Remove-Item -Force
                            Refresh-Backups
                            Show-ToolNotification -Title "Limpieza" -Message "Todos los backups eliminados." -Icon "Information" -Owner $settingsWindow
                        }
                        catch {
                            Show-ToolNotification -Title "Error" -Message "Error al eliminar: $_" -Icon "Error" -Owner $settingsWindow
                        }
                    }
                })
        }

        


        # Initial Load
        Refresh-Backups
        
        # Auto-Select First Item
        if ($treeTools.Items.Count -gt 0) {
            $treeTools.Items[0].IsSelected = $true
            $treeTools.Items[0].Focus()
        }
            
        [void]$settingsWindow.ShowDialog()
    }
    catch {
        Write-Error "Error al abrir Settings: $_"
        Show-ToolNotification -Title "Error" -Message "No se pudo abrir la configuración: $($_.Exception.Message)" -Icon "Error" -Owner $Owner
    }
}

