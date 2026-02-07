
Add-Type -AssemblyName System.Drawing

function Convert-PngToIco {
    param(
        [string]$PngPath,
        [string]$IcoPath
    )

    try {
        $img = [System.Drawing.Bitmap]::FromFile($PngPath)
        $handle = $img.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($handle)
        
        $fs = [System.IO.File]::OpenWrite($IcoPath)
        $icon.Save($fs)
        $fs.Close()
        
        $icon.Dispose()
        $img.Dispose()
        
        Write-Host "Converted $PngPath to $IcoPath"
    }
    catch {
        Write-Error "Conversion Failed: $_"
    }
}



