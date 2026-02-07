function Register-AppShortcuts {
    param($Window, $SearchBox)
    
    $Window.Add_KeyDown({
            param($sender, $e)
        
            # Ctrl + F: Buscar
            if ($e.Key -eq "F" -and [System.Windows.Input.Keyboard]::Modifiers -eq "Control") {
                $SearchBox.Focus()
            }
        
            # Ctrl + Q: Salir
            if ($e.Key -eq "Q" -and [System.Windows.Input.Keyboard]::Modifiers -eq "Control") {
                $Window.Close()
            }
        
            # F5 o Ctrl + R: Refrescar
            if ($e.Key -eq "F5" -or ($e.Key -eq "R" -and [System.Windows.Input.Keyboard]::Modifiers -eq "Control")) {
                # Aquí se podría disparar el evento del botón Refresh si es accesible
            }
        })
}

