function Get-ConfigData {
    param([string]$Path)
    try {
        if (Test-Path $Path) {
            return Get-Content $Path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }
    }
    catch {
        Write-Error "Error al leer configuración en $($Path): $($_.Exception.Message)"
    }
    return $null
}

function Set-ConfigData {
    param(
        [string]$Path,
        [Parameter(ValueFromPipeline)] $Data
    )
    try {
        # Clonar datos para no afectar la memoria viva mientras limpiamos para disco
        # Usamos la conversión a JSON y vuelta para una "clonación profunda" rápida
        $json = $Data | ConvertTo-Json -Depth 10
        $cleanData = $json | ConvertFrom-Json
        
        Optimize-ConfigForSave -Data $cleanData
        
        $cleanData | ConvertTo-Json -Depth 10 | Set-Content $Path -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Error "Error al guardar configuración en $($Path): $($_.Exception.Message)"
    }
}

function Optimize-ConfigForSave {
    param($Data)
    
    if ($Data.Tabs) {
        foreach ($tab in $Data.Tabs) {
            # Eliminar propiedades temporales de la pestaña
            $props = $tab.PSObject.Properties | Where-Object { $_.Name -like "_*" }
            foreach ($p in $props) { $tab.PSObject.Properties.Remove($p.Name) }

            if ($tab.Tools) {
                foreach ($tool in $tab.Tools) {
                    Clear-ToolRuntimeProperties -Tool $tool
                }
            }
            if ($tab.Groups) {
                foreach ($grp in $tab.Groups) {
                    $grpProps = $grp.PSObject.Properties | Where-Object { $_.Name -like "_*" }
                    foreach ($p in $grpProps) { $grp.PSObject.Properties.Remove($p.Name) }

                    if ($grp.Tools) {
                        foreach ($tool in $grp.Tools) {
                            Clear-ToolRuntimeProperties -Tool $tool
                        }
                    }
                }
            }
        }
    }
}

function Clear-ToolRuntimeProperties {
    param($Tool)
    # Lista de propiedades que NO deben ir al JSON
    $toRemove = @("IconSource")
    foreach ($name in $toRemove) {
        if ($Tool.PSObject.Properties[$name]) {
            $Tool.PSObject.Properties.Remove($name)
        }
    }
    
    # Eliminar cualquier propiedad que empiece por guion bajo (Metadatos de UI)
    $metaProps = $Tool.PSObject.Properties | Where-Object { $_.Name -like "_*" }
    foreach ($p in $metaProps) {
        $Tool.PSObject.Properties.Remove($p.Name)
    }

    # Convertir rutas absolutas a relativas (si fuera necesario en el futuro para campos custom)
    # Por ahora IconSource es el principal "infractor" y ya lo eliminamos arriba.
}


function Write-AppLog {
    param([string]$Message, [string]$Level = "INFO")
    $logFile = Join-Path $global:InstallationRoot "logs\app.log"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fullMsg = "[$timestamp] [$Level] $Message"
    
    try {
        Add-Content -Path $logFile -Value $fullMsg -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Si falla (ej: corrupción de encoding), intentamos borrar y recrear
        try {
            Remove-Item $logFile -Force -ErrorAction SilentlyContinue
            Add-Content -Path $logFile -Value $fullMsg -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            # Silencioso en archivo, pero visible en terminal para debug
            Write-Error "Fallo crítico en sub-sistema de logs: $_"
        }
    }

}

