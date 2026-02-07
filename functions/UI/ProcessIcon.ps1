
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class IconProcessor {
    public static void MakeBlackTransparent(string inputPath, string outputPath) {
        try {
            using (Bitmap bmp = new Bitmap(inputPath)) {
                // Lock bits for speed
                Rectangle rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
                BitmapData bmpData = bmp.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
                
                int bytes = Math.Abs(bmpData.Stride) * bmp.Height;
                byte[] rgbValues = new byte[bytes];
                Marshal.Copy(bmpData.Scan0, rgbValues, 0, bytes);
                
                // Iterate (BGRA format)
                for (int i = 0; i < rgbValues.Length; i += 4) {
                    byte b = rgbValues[i];
                    byte g = rgbValues[i + 1];
                    byte r = rgbValues[i + 2];
                    // Alpha is i+3
                    
                    // Simple luminance check for 'Black' (or very dark gray)
                    // If R, G, and B are all low (< 30), make transparent
                    if (r < 30 && g < 30 && b < 30) {
                        rgbValues[i + 3] = 0; // Alpha 0
                    }
                }
                
                Marshal.Copy(rgbValues, 0, bmpData.Scan0, bytes);
                bmp.UnlockBits(bmpData);
                
                bmp.Save(outputPath, ImageFormat.Png);
                Console.WriteLine("Processed image saved to " + outputPath);
            }
        } catch (Exception ex) {
            Console.WriteLine("Error: " + ex.Message);
        }
    }
}
"@ -ReferencedAssemblies System.Drawing

function Invoke-IconProcessing {
    param($src, $dst)
    [IconProcessor]::MakeBlackTransparent($src, $dst)
}

