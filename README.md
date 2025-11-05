# 🎨 Pixel Art Studio

A beautiful and feature-rich pixel art painting application built with Flutter. Create stunning pixel art with multiple layers, advanced drawing tools, and a modern, responsive interface.

## ✨ Features

### 🖌️ Drawing Tools
- **Brush** - Paint with customizable brush sizes (1x1, 2x2, 3x3)
- **Eraser** - Remove pixels with precision
- **Fill Tool** - Flood fill entire areas with one click
- **Eyedropper** - Pick colors from your canvas
- **Line Tool** - Draw straight lines with start and end points
- **Rectangle Tool** - Create rectangular shapes
- **Circle Tool** - Draw perfect circles

### 🎨 Color Management
- **Color Palette** - 16 predefined colors for quick access
- **Custom Color Picker** - RGB sliders for precise color selection
- **Color History** - Quick access to recently used colors
- **Live Preview** - See your selected color before applying

### 📚 Layer System
- **Multiple Layers** - Create complex artwork with layer management
- **Layer Visibility** - Toggle layers on/off for better workflow
- **Layer Reordering** - Move layers up and down to change stacking order
- **Layer Thumbnails** - Visual preview of each layer's content
- **Active Layer Selection** - Work on different layers independently
- **Layer Opacity** - Adjust transparency for advanced blending

### 🔧 Advanced Features
- **Symmetry Mode** - Draw with vertical, horizontal, or both-axis symmetry
- **Grid Overlay** - Toggle grid visibility for precise alignment
- **Canvas Transformations**:
  - Flip horizontal/vertical
  - Rotate 90°, 180°, or 270°
- **Zoom Controls** - Pinch to zoom or use buttons (0.5x to 3x)
- **Undo/Redo** - Full history support with up to 50 actions
- **Copy/Paste** - Duplicate canvas content between layers
- **Grid Size Options** - Choose from 16x16, 32x32, or 64x64 canvas sizes

### 💾 Save & Export
- **Save to Gallery** - Export your artwork as PNG images
- **High Quality** - 512x512 pixel output resolution
- **Automatic Naming** - Files are saved with timestamps

### 📱 Responsive Design
- **Cross-Platform** - Works on iOS, Android, Web, Windows, macOS, and Linux
- **Tablet Optimized** - Enhanced UI for larger screens
- **Phone Friendly** - Compact layout for mobile devices
- **Adaptive Layout** - Automatically adjusts to different screen sizes
- **Orientation Support** - Works in both portrait and landscape modes

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK (comes with Flutter)
- Android Studio / Xcode (for mobile development)
- VS Code (recommended) or Android Studio

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/pixel-art-studio.git
   cd pixel-art-studio
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
- Minimum SDK version: 21
- Target SDK version: Latest
- Storage permissions are handled automatically for saving images

#### iOS
- Minimum iOS version: 12.0
- Photo library permissions are requested when saving images

#### Web
```bash
flutter run -d chrome
```

#### Desktop (Windows/macOS/Linux)
```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

## 📖 Usage Guide

### Basic Drawing
1. Select a tool from the toolbar at the top
2. Choose a color from the palette or use the custom color picker
3. Tap or drag on the canvas to draw

### Using Layers
1. Tap the **Layers** icon in the app bar
2. Use **Add New Layer** to create additional layers
3. Toggle visibility with the eye icon
4. Tap a layer to make it active
5. Use arrow buttons to reorder layers
6. Delete layers with the trash icon (minimum 1 layer required)

### Advanced Tools
- **Line/Rectangle/Circle**: Tap once to set start point, tap again to set end point
- **Symmetry Mode**: Select from None, Vertical, Horizontal, or Both
- **Zoom**: Pinch with two fingers or use the zoom controls at the bottom
- **Grid**: Toggle grid visibility for precise pixel placement

### Saving Your Artwork
1. Tap the **Save** icon in the app bar
2. Your artwork will be saved to your device's gallery/photos
3. A success message will confirm the save

## 🛠️ Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  image_gallery_saver: ^2.0.3
```

## 📱 Screenshots

*Screenshots coming soon!*

## 🎯 Roadmap

- [ ] Export to different formats (GIF, SVG)
- [ ] Animation support
- [ ] Import images for tracing
- [ ] Export as sprite sheets
- [ ] Cloud save/backup
- [ ] Custom color palettes
- [ ] Pattern brushes
- [ ] Selection tool improvements
- [ ] Layer blend modes
- [ ] Project file format

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Inspired by classic pixel art tools
- Icons from Material Design

## 📧 Contact

Your Name - [@yourusername](https://twitter.com/yourusername)

Project Link: [https://github.com/yourusername/pixel-art-studio](https://github.com/yourusername/pixel-art-studio)

---

Made with ❤️ using Flutter
