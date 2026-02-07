function Get-Favicon {
    param($URL, $Name, [switch]$ForceDownload)
    
    $iconsDir = Join-Path $global:InstallationRoot "icons"
    if (-not (Test-Path $iconsDir)) { New-Item -ItemType Directory -Path $iconsDir -Force | Out-Null }
    
    # Sanitize Filename
    $safeName = $Name -replace '[\\/*?:"<>|]', ""
    $localPath = Join-Path $iconsDir "$safeName.png"
    
    # Check Cache
    if (Test-Path $localPath) {
        return $localPath
    }
    
    # Si no está en caché y no se fuerza la descarga, salir
    if (-not $ForceDownload) { return $null }

    # Download Logic
    try {
        # Extract Domain
        $uri = [System.Uri]$URL
        $domain = $uri.Host
        
        # Google Favicon API (High Res 64px)
        $iconUrl = "https://www.google.com/s2/favicons?domain=$domain&sz=64"
        
        # Download (Silently)
        Invoke-WebRequest -Uri $iconUrl -OutFile $localPath -ErrorAction Stop
        
        return $localPath
    }
    catch {
        Write-AppLog -Message "Failed to fetch icon for $Name : $_" -Level WARN
        return $null
    }
}

function Start-IconPreFetch {
    param($Config)
    Write-AppLog -Message "Iniciando Pre-fetching de iconos en segundo plano..."
    
    # Pass InstallationRoot explicitly because Jobs are isolated
    Start-Job -ScriptBlock {
        param($Tabs, $FuncPath, $InstRoot)
        $global:InstallationRoot = $InstRoot # Inject into job scope as Global to be safe
        . $FuncPath
        foreach ($tab in $Tabs) {
            $tools = @()
            if ($tab.Tools) { $tools += $tab.Tools }
            if ($tab.Groups) { foreach ($g in $tab.Groups) { $tools += $g.Tools } }
            
            foreach ($t in $tools) {
                # Aquí sí forzamos la descarga porque estamos en segundo plano
                Get-Favicon -URL $t.URL -Name $t.Name -ForceDownload | Out-Null
            }
        }

    } -ArgumentList $Config.Tabs, (Join-Path $global:InstallationRoot "functions\UI\IconManager.ps1"), $global:InstallationRoot
}

function Clear-IconCache {
    $iconsDir = Join-Path $global:InstallationRoot "icons"
    if (Test-Path $iconsDir) {
        Remove-Item -Path "$iconsDir\*.png" -Force -ErrorAction SilentlyContinue
        Write-AppLog -Message "Caché de iconos limpiada."
    }
}
