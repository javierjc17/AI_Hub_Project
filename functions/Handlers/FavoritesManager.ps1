function Get-FavoriteList {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            $data = Get-ConfigData -Path $Path
            if ($data.Favorites) { return $data.Favorites } else { return @() }
        }
    }
    catch {
        Write-AppLog -Message "Error cargando favoritos: $($_.Exception.Message)" -Level "ERROR"
    }
    return @()
}

function Set-FavoriteList {
    param([string]$Path, [array]$Favorites)
    try {
        Set-ConfigData -Path $Path -Data @{ Favorites = $Favorites }
    }
    catch {
        Write-AppLog -Message "Error guardando favoritos: $($_.Exception.Message)" -Level "ERROR"
    }
}

function Invoke-FavoriteToggle {
    param([array]$Favorites, [string]$ToolName)
    if ($Favorites -contains $ToolName) {
        return $Favorites | Where-Object { $_ -ne $ToolName }
    }
    else {
        return $Favorites + $ToolName
    }
}

