using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

namespace AIHubLauncher
{
    class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                // Obtener la carpeta donde está el ejecutable
                string exePath = Assembly.GetExecutingAssembly().Location;
                string exeDir = Path.GetDirectoryName(exePath);
                
                // Ruta al script principal
                string mainScript = Path.Combine(exeDir, "Main.ps1");
                
                // Verificar que Main.ps1 existe
                if (!File.Exists(mainScript))
                {
                    MessageBox.Show(
                        "Error: No se encontró Main.ps1 en la carpeta de la aplicación.\n\n" +
                        "Ruta esperada: " + mainScript,
                        "AI Hub - Error",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error
                    );
                    return;
                }
                
                // Configurar el proceso de PowerShell
                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File \"" + mainScript + "\"",
                    WorkingDirectory = exeDir,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                
                // Iniciar PowerShell
                Process.Start(startInfo);
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "Error al iniciar AI Hub:\n\n" + ex.Message,
                    "AI Hub - Error Crítico",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error
                );
            }
        }
    }
}
