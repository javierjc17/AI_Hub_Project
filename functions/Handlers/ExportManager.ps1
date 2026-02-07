function Export-ConfigurationToHTML {
    param(
        [string]$ConfigPath,
        [string]$OutputPath
    )

    try {
        if (-not (Test-Path $ConfigPath)) { throw "Config file not found: $ConfigPath" }
        
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        if (-not $config.Tabs) { throw "No Tabs found in configuration." }

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine("<!DOCTYPE NETSCAPE-Bookmark-file-1>")
        [void]$sb.AppendLine("<!-- This is an automatically generated file. It will be read and overwritten. -->")
        [void]$sb.AppendLine("<!-- DO NOT EDIT! -->")
        [void]$sb.AppendLine("<META HTTP-EQUIV=`"Content-Type`" CONTENT=`"text/html; charset=UTF-8`">")
        [void]$sb.AppendLine("<TITLE>Bookmarks</TITLE>")
        [void]$sb.AppendLine("<H1>Bookmarks</H1>")
        [void]$sb.AppendLine("<DL><p>")

        # Root Folder: AI Hub Tools
        [void]$sb.AppendLine("    <DT><H3 ADD_DATE=`"$([DateTimeOffset]::Now.ToUnixTimeSeconds())`" LAST_MODIFIED=`"$([DateTimeOffset]::Now.ToUnixTimeSeconds())`">AI Hub Tools</H3>")
        [void]$sb.AppendLine("    <DL><p>")

        foreach ($tab in $config.Tabs) {
            # Tab -> Folder
            [void]$sb.AppendLine("        <DT><H3 ADD_DATE=`"$([DateTimeOffset]::Now.ToUnixTimeSeconds())`">$($tab.Title)</H3>")
            [void]$sb.AppendLine("        <DL><p>")

            # Direct Tools in Tab
            if ($tab.Tools) {
                foreach ($tool in $tab.Tools) {
                    $iconAttr = ""
                    if ($tool.Icon -and $tool.Icon.StartsWith("http")) { 
                        # Only use ICON attribute if it's a URL (favicons), but browsers often ignore this or expect base64.
                        # We'll skip complex base64 logic for simplicity unless requested.
                    }
                    [void]$sb.AppendLine("            <DT><A HREF=`"$($tool.URL)`" ADD_DATE=`"$([DateTimeOffset]::Now.ToUnixTimeSeconds())`">$($tool.Name)</A>")
                }
            }

            # Groups in Tab
            if ($tab.Groups) {
                foreach ($group in $tab.Groups) {
                    [void]$sb.AppendLine("            <DT><H3 ADD_DATE=`"$([DateTimeOffset]::Now.ToUnixTimeSeconds())`">$($group.Title)</H3>")
                    [void]$sb.AppendLine("            <DL><p>")
                    
                    if ($group.Tools) {
                        foreach ($gTool in $group.Tools) {
                            [void]$sb.AppendLine("                <DT><A HREF=`"$($gTool.URL)`" ADD_DATE=`"$([DateTimeOffset]::Now.ToUnixTimeSeconds())`">$($gTool.Name)</A>")
                        }
                    }
                    [void]$sb.AppendLine("            </DL><p>")
                }
            }

            [void]$sb.AppendLine("        </DL><p>")
        }

        [void]$sb.AppendLine("    </DL><p>")
        [void]$sb.AppendLine("</DL><p>")

        $sb.ToString() | Out-File $OutputPath -Encoding UTF8
        return $true
    }
    catch {
        Write-Error "Error exporting to HTML: $_"
        return $false
    }
}
