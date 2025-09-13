import SwiftUI
import UIKit
import Combine

class ColorExtractor: ObservableObject {
    @Published var dominantColors: [Color] = []
    @Published var primaryColor: Color = .primary
    @Published var accentColor: Color = .accentColor
    
    private var cancellables = Set<AnyCancellable>()
    
    func extractColors(from imageURL: String?) {
        guard let urlString = imageURL,
              let url = URL(string: urlString) else {
            resetToDefault()
            return
        }
        
        loadImage(from: url) { [weak self] image in
            guard let image = image else {
                DispatchQueue.main.async {
                    self?.resetToDefault()
                }
                return
            }
            
            let colors = self?.getDominantColors(from: image) ?? []
            
            DispatchQueue.main.async {
                self?.dominantColors = colors
                self?.primaryColor = colors.first ?? .primary
                self?.accentColor = colors.count > 1 ? colors[1] : colors.first ?? .accentColor
            }
        }
    }
    
    private func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else {
                completion(nil)
                return
            }
            completion(image)
        }.resume()
    }
    
    private func getDominantColors(from image: UIImage) -> [Color] {
        guard let cgImage = image.cgImage,
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return [.primary]
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = cgImage.bytesPerRow
        
        var colorCounts: [UIColor: Int] = [:]
        let sampleSize = 10 // Sample every 10th pixel for performance
        
        for y in stride(from: 0, to: height, by: sampleSize) {
            for x in stride(from: 0, to: width, by: sampleSize) {
                let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                
                let red = CGFloat(bytes[pixelIndex + 2]) / 255.0
                let green = CGFloat(bytes[pixelIndex + 1]) / 255.0
                let blue = CGFloat(bytes[pixelIndex]) / 255.0
                let alpha = CGFloat(bytes[pixelIndex + 3]) / 255.0
                
                // Skip transparent pixels
                if alpha < 0.5 { continue }
                
                let color = UIColor(red: red, green: green, blue: blue, alpha: alpha)
                let quantizedColor = quantizeColor(color)
                
                colorCounts[quantizedColor, default: 0] += 1
            }
        }
        
        // Get the most frequent colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let dominantUIColors = Array(sortedColors.prefix(3).map { $0.key })
        
        // Convert to SwiftUI Colors and ensure good contrast
        return dominantUIColors.map { Color($0) }
    }
    
    private func quantizeColor(_ color: UIColor) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Quantize to reduce color variations
        let quantization: CGFloat = 0.2
        let quantizedRed = round(red / quantization) * quantization
        let quantizedGreen = round(green / quantization) * quantization
        let quantizedBlue = round(blue / quantization) * quantization
        
        return UIColor(red: quantizedRed, green: quantizedGreen, blue: quantizedBlue, alpha: alpha)
    }
    
    private func resetToDefault() {
        dominantColors = []
        primaryColor = .primary
        accentColor = .accentColor
    }
}

extension Color {
    var isLight: Bool {
        let uiColor = UIColor(self)
        var white: CGFloat = 0
        uiColor.getWhite(&white, alpha: nil)
        return white > 0.5
    }
    
    var readableTextColor: Color {
        return isLight ? .black : .white
    }
}