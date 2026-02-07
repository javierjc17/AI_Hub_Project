function Resolve-SmartUrl {
    param([string]$Url)
    
    # 1. Configurar protocolos
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls
    }
    catch {
        Write-AppLog -Message "Error al restaurar SSL callback: $_" -Level "WARN"
    }

    # 2. Ignorar SSL
    $oldCallback = [Net.ServicePointManager]::ServerCertificateValidationCallback
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    
    $userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    $result = [PSCustomObject]@{
        Success  = $false
        FinalUrl = $Url
        Changed  = $false
    }

    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $request.Method = "GET" # HEAD a veces falla en redirects complejos, GET es más seguro para esto
        $request.Timeout = 5000
        $request.UserAgent = $userAgent
        $request.AllowAutoRedirect = $true
        
        $response = $request.GetResponse()
        $finalUrl = $response.ResponseUri.AbsoluteUri
        $status = [int]$response.StatusCode
        $response.Close()
        
        if ($status -ge 200 -and $status -lt 400) {
            $result.Success = $true
            
            # Normalizar URLs para comparación (quitar slash final)
            $normOriginal = $Url.TrimEnd("/")
            $normFinal = $finalUrl.TrimEnd("/")
            
            # Comparar ignorando case y www
            if ($normOriginal -ne $normFinal) {
                # Evitar falsos positivos por http/https o www
                $cleanOrg = $normOriginal -replace "^https?://(www\.)?", ""
                $cleanFin = $normFinal -replace "^https?://(www\.)?", ""
                
                if ($cleanOrg -ne $cleanFin) {
                    $result.FinalUrl = $finalUrl
                    $result.Changed = $true
                }
            }
        }
    }
    catch {
        Write-AppLog -Message "Error al resolver URL (${Url}): $_" -Level "WARN"
        # Fallback: Si falla, asumimos que no hay cambio seguro, pero validamos si existe
        if ($_.Exception.InnerException -and $_.Exception.InnerException.Message -match "401|403|405") {
            $result.Success = $true 
        }
    }
    finally {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = $oldCallback
    }
    
    return $result
}

function Test-UrlAvailability {
    param([string]$Url)
    # Wrapper simple para compatibilidad
    $res = Resolve-SmartUrl -Url $Url
    return $res.Success
}

