$global:AppWindows = @()

function Sync-GlobalTheme {
    <#
    .SYNOPSIS
        Synchronizes theme and effects across ALL registered application windows.
    #>
    param(
        [Parameter(Mandatory = $true)]
        $Config
    )

    Write-AppLog -Message "Iniciando sincronización global de temas para $($global:AppWindows.Count) ventanas." -Level "INFO"
    
    # Cleanup closed windows first
    $global:AppWindows = $global:AppWindows | Where-Object { $_.IsVisible -or $_.IsLoaded }

    foreach ($win in $global:AppWindows) {
        try {
            if (Get-Command Set-ThemeResources -ErrorAction SilentlyContinue) {
                Set-ThemeResources -Window $win -Config $Config
            }
            if (Get-Command Set-WindowEffects -ErrorAction SilentlyContinue) {
                Set-WindowEffects -Window $win -Config $Config
            }
        }
        catch {
            Write-AppLog -Message "Sync-GlobalTheme: No se pudo actualizar una ventana: $_" -Level "WARN"
        }
    }
}

function New-AppWindow {
    <#
    .SYNOPSIS
        Creates and initializes a premium application window with consistent styles and effects.
    
    .PARAMETER XamlPath
        Absolute path to the XAML definition of the window.
    
    .PARAMETER Title
        Window title.
    
    .PARAMETER Config
        Global configuration object (for theme/effects).
    
    .PARAMETER Owner
        Parent window (optional).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$XamlPath,
        [Parameter(Mandatory = $false)]
        [string]$Title,
        [Parameter(Mandatory = $true)]
        $Config,
        [Parameter(Mandatory = $false)]
        $Owner
    )

    try {
        # 1. Prepare XML and Inject Global Styles BEFORE loading
        # This is critical for StaticResource resolution
        [xml]$xamlContent = Get-Content $XamlPath -Encoding UTF8
        $root = $xamlContent.DocumentElement
        
        $stylesPath = Join-Path $global:InstallationRoot "xaml\Shared\GlobalStyles.xaml"
        if (Test-Path $stylesPath) {
            Write-AppLog -Message "Inyectando estilos globales en ${XamlPath}" -Level "DEBUG"
            
            # Find or Create Resources node (e.g., Window.Resources)
            $resNodeName = "$($root.LocalName).Resources"
            $resourcesNode = $root.ChildNodes | Where-Object { $_.LocalName -eq $resNodeName } | Select-Object -First 1
            if (-not $resourcesNode) {
                $resourcesNode = $xamlContent.CreateElement($resNodeName, $root.NamespaceURI)
                [void]$root.PrependChild($resourcesNode)
            }

            # WPF Requirement: If using MergedDictionaries, you MUST have a single ResourceDictionary child
            # if the Resources node has direct children (Style, Storyboard), we must wrap them.
            $resDict = $resourcesNode.ChildNodes | Where-Object { $_.LocalName -eq "ResourceDictionary" } | Select-Object -First 1
            
            if (-not $resDict) {
                # Create a new ResourceDictionary in the standard WPF namespace
                $resDict = $xamlContent.CreateElement("ResourceDictionary", "http://schemas.microsoft.com/winfx/2006/xaml/presentation")
                
                # Move all existing content of resourcesNode into this new dictionary
                $existingNodes = @($resourcesNode.ChildNodes)
                foreach ($node in $existingNodes) {
                    [void]$resourcesNode.RemoveChild($node)
                    [void]$resDict.AppendChild($node)
                }
                
                # Add the new dictionary back to the resources node
                [void]$resourcesNode.AppendChild($resDict)
            }

            # Find or Create MergedDictionaries
            $mergedDicts = $resDict.ChildNodes | Where-Object { $_.LocalName -eq "ResourceDictionary.MergedDictionaries" } | Select-Object -First 1
            if (-not $mergedDicts) {
                $mergedDicts = $xamlContent.CreateElement("ResourceDictionary.MergedDictionaries", $resDict.NamespaceURI)
                [void]$resDict.PrependChild($mergedDicts)
            }

            # Inject GlobalStyles source using absolute File URI
            $stylesUri = (New-Object System.Uri $stylesPath).AbsoluteUri
            $newDict = $xamlContent.CreateElement("ResourceDictionary", $resDict.NamespaceURI)
            $newDict.SetAttribute("Source", $stylesUri)
            
            # Prepend to ensure it's available for other resources in the same file
            [void]$mergedDicts.PrependChild($newDict)
        }

        # 2. Load the modified XAML
        $reader = New-Object System.Xml.XmlNodeReader($xamlContent)
        $window = [Windows.Markup.XamlReader]::Load($reader)

        # 2.5 APPLY THEME IMMEDIATELY (Before showing, for dynamic resources)
        if (Get-Command Set-ThemeResources -ErrorAction SilentlyContinue) {
            Set-ThemeResources -Window $window -Config $Config
        }

        # 3. Setup Owner & Title
        if ($Owner) { $window.Owner = $Owner }
        if ($Title) { $window.Title = $Title }

        # 4. Standard Behavior: Title Bar Dragging
        $titleBar = $window.FindName("TitleBar")
        if (-not $titleBar) { $titleBar = $window.FindName("TopBar") }
        
        if ($titleBar) {
            $titleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
        }

        # 5. Connect Essential Window Controls (if present)
        $btnClose = $window.FindName("BtnClose")
        if ($btnClose) { $btnClose.Add_Click({ $window.Close() }) }
        
        $btnMinimize = $window.FindName("BtnMinimize")
        if ($btnMinimize) { $btnMinimize.Add_Click({ $window.WindowState = 'Minimized' }) }

        # 6. Apply Theme & Effects on Source Initialized
        $window.Add_SourceInitialized({
                # Apply native dark mode and backdrop effects
                if (Get-Command Set-ThemeResources -ErrorAction SilentlyContinue) {
                    Set-ThemeResources -Window $window -Config $Config
                }
                if (Get-Command Set-WindowEffects -ErrorAction SilentlyContinue) {
                    Set-WindowEffects -Window $window -Config $Config
                }
            })

        # 7. Global Registration (For Sync-GlobalTheme)
        $global:AppWindows += $window
        $window.Add_Closed({
                $global:AppWindows = $global:AppWindows | Where-Object { $_ -ne $this }
            })

        return $window
    }
    catch {
        $errorMsg = "Error crítico cargando ventana: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            $errorMsg += "`nDetalles: $($_.Exception.InnerException.Message)"
            if ($_.Exception.InnerException.InnerException) {
                $errorMsg += "`nCausa Raíz: $($_.Exception.InnerException.InnerException.Message)"
            }
        }
        
        Write-AppLog -Message "[$XamlPath] $errorMsg" -Level "ERROR"
        
        # Opcional: Mostrar diálogo de error detallado si no es la ventana principal
        if ($null -ne $global:config) {
            [System.Windows.MessageBox]::Show($errorMsg, "Error de Interfaz", 0, 16)
        }
        
        throw $_
    }
}

