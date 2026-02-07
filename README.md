# 🚀 AI Hub Architect

**AI Hub Architect** es una aplicación de escritorio moderna desarrollada en PowerShell con WPF que centraliza el acceso rápido a las mejores herramientas de Inteligencia Artificial para creación de contenido.

![AI Hub Architect](imagenes-referencia/imagen-de-referencia.png)

## 📋 Características

- ✅ **Interfaz Moderna**: Diseño oscuro con efectos glassmorphism y animaciones suaves
- 🎨 **Categorías Organizadas**: Imágenes, Video, Audio y Herramientas generales
- ⭐ **Sistema de Favoritos**: Marca tus herramientas más usadas con clic derecho
- 🔍 **Búsqueda Rápida**: Encuentra herramientas al instante
- 📊 **Estadísticas de Uso**: Rastrea qué herramientas usas más
- ⚙️ **Personalizable**: Configura temas, colores y preferencias
- 💾 **Persistencia**: Tus favoritos y estadísticas se guardan automáticamente

## 🛠️ Requisitos

- **Sistema Operativo**: Windows 10/11
- **PowerShell**: 5.1 o superior (incluido en Windows)
- **.NET Framework**: 4.5 o superior (incluido en Windows)

## 🚀 Instalación

1. **Clonar o descargar** este repositorio
2. **Navegar** a la carpeta del proyecto
3. **Ejecutar** `Main.ps1`:

```powershell
.\Main.ps1
```

O hacer **doble clic** en `Main.ps1` desde el Explorador de Windows.

## 📁 Estructura del Proyecto

```
AI_Hub_Project/
├── Main.ps1                    # Script principal de la aplicación
├── README.md                   # Este archivo
├── .gitignore                  # Archivos ignorados por Git
│
├── config/                     # Archivos de configuración
│   ├── config.json            # Configuración de herramientas y tema
│   ├── favorites.json         # Favoritos del usuario
│   └── stats.json             # Estadísticas de uso
│
├── xaml/                       # Interfaces de usuario
│   ├── main.xaml              # Ventana principal
│   └── settings.xaml          # Ventana de configuración
│
├── functions/                  # Módulos de código
│   ├── FileManager.ps1        # Gestión de archivos JSON
│   ├── StatsManager.ps1       # Gestión de estadísticas
│   ├── FavoritesManager.ps1   # Gestión de favoritos
│   ├── UIHelpers.ps1          # Funciones de interfaz
│   ├── SettingsManager.ps1    # Gestión de configuración
│   └── KeyboardShortcuts.ps1  # Atajos de teclado
│
└── imagenes-referencia/        # Imágenes de referencia
    └── imagen-de-referencia.png
```

## 🎮 Uso

### Navegación Básica

1. **Seleccionar Categoría**: Haz clic en las pestañas superiores (Imágenes, Video, Audio, Herramientas)
2. **Abrir Herramienta**: Clic izquierdo en cualquier botón de herramienta
3. **Agregar a Favoritos**: Clic derecho en una herramienta
4. **Buscar**: Escribe en la caja de búsqueda superior

### Acciones Rápidas (Sidebar)

- **Abrir Todas**: Abre todas las herramientas de la categoría actual
- **Refrescar**: Recarga la configuración desde `config.json`
- **Exportar Favoritos**: Guarda tus favoritos en un archivo de texto

### Atajos de Teclado

- `Ctrl + F`: Enfocar búsqueda
- `Ctrl + R`: Refrescar herramientas
- `Ctrl + Q`: Cerrar aplicación
- `F1`: Ayuda

### Panel de Información

Al pasar el mouse sobre una herramienta, se muestra:
- Nombre completo
- Descripción detallada
- Categoría
- Botón para abrir directamente

## ⚙️ Configuración

### Personalizar Herramientas

Edita `config/config.json` para agregar o modificar herramientas:

```json
{
  "Theme": {
    "Background": "#121418",
    "Accent": "#3498db",
    "Text": "#FFFFFF",
    "Radius": "15",
    "FontSize": "12",
    "Mode": "Dark"
  },
  "Tabs": [
    {
      "Title": "Imagenes",
      "Tools": [
        {
          "Name": "Midjourney",
          "URL": "https://www.midjourney.com",
          "Desc": "Generacion Artistica",
          "Icon": "🎨"
        }
      ]
    }
  ]
}
```

### Cambiar Tema

1. Haz clic en el botón **⚙️ Configuración**
2. Selecciona tu color de acento favorito
3. Ajusta el tamaño de fuente
4. Haz clic en **Guardar**

## 🔧 Desarrollo

### Agregar Nuevas Funciones

1. Crea un archivo `.ps1` en la carpeta `functions/`
2. Define tus funciones
3. Se cargarán automáticamente al iniciar la app

### Modificar la Interfaz

Edita `xaml/main.xaml` para cambiar la apariencia de la ventana principal.

## 📊 Estadísticas

Las estadísticas se guardan automáticamente en `config/stats.json`:
- Contador de uso por herramienta
- Última actualización
- Herramienta más usada

## 🐛 Solución de Problemas

### La aplicación no inicia

1. Verifica que PowerShell 5.1+ esté instalado:
   ```powershell
   $PSVersionTable.PSVersion
   ```

2. Ejecuta PowerShell como administrador si es necesario

### Error al cargar configuración

1. Verifica que `config/config.json` sea JSON válido
2. Usa un validador JSON online si es necesario
3. Restaura desde backup si existe

### Las herramientas no se abren

1. Verifica tu conexión a Internet
2. Comprueba que las URLs en `config.json` sean válidas
3. Verifica que tu navegador predeterminado esté configurado

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Para contribuir:

1. Fork este repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto es de código abierto y está disponible bajo la licencia MIT.

## 🙏 Agradecimientos

- Todas las increíbles herramientas de IA incluidas
- La comunidad de PowerShell
- Iconos emoji de Unicode

## 📧 Contacto

¿Preguntas o sugerencias? Abre un issue en este repositorio.

---

**Hecho con ❤️ y PowerShell**
