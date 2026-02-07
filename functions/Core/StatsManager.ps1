function Import-Stats {
    param([string]$Path)
    $script:usageStats = @{}
    try {
        if (Test-Path $Path) {
            $data = Get-ConfigData -Path $Path
            if ($data.usage) {
                foreach ($prop in $data.usage.psobject.properties) {
                    $script:usageStats[$prop.Name] = $prop.Value
                }
            }
        }
    }
    catch {
        Write-AppLog -Message "Error cargando estadísticas: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Export-Stats {
    param([string]$Path)
    try {
        $mostUsed = "N/A"
        if ($script:usageStats.Count -gt 0) {
            $mostUsed = ($script:usageStats.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Name
        }
        
        $statsObj = @{
            usage       = $script:usageStats
            lastUpdated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            totalClicks = ($script:usageStats.Values | Measure-Object -Sum).Sum
            mostUsed    = $mostUsed
        }
        Set-ConfigData -Path $Path -Data $statsObj
    }
    catch {
        Write-AppLog -Message "Error guardando estadísticas: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Add-ToolUsage {
    param([string]$ToolName)
    if (-not $script:usageStats.ContainsKey($ToolName)) {
        $script:usageStats[$ToolName] = 0
    }
    $script:usageStats[$ToolName]++
}

function Update-StatsDisplay {
    param($StatsPath, $TxtTotal, $TxtCategories, $TxtMostUsed)
    
    try {
        # 1. Total Clicks
        $total = 0
        if ($script:usageStats) {
            $total = ($script:usageStats.Values | Measure-Object -Sum).Sum
        }

        # 2. Most Used
        $mostUsed = "-"
        if ($script:usageStats -and $script:usageStats.Count -gt 0) {
            $mostUsed = ($script:usageStats.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Name
        }

        # 3. Categories Count (From Global Config)
        $catCount = 0
        if ($script:config -and $script:config.Tabs) {
            $catCount = ($script:config.Tabs | Where-Object { $_.Visible -eq $true }).Count
        }

        # 4. Update UI Elements
        if ($TxtTotal) { $TxtTotal.Text = "Total: $total" }
        if ($TxtCategories) { $TxtCategories.Text = "Categorías: $catCount" }
        if ($TxtMostUsed) { $TxtMostUsed.Text = "Más usada: $mostUsed" }
    }
    catch {
         Write-AppLog -Message "Error actualizando display de estadísticas: $_" -Level "WARN"
    }
}
