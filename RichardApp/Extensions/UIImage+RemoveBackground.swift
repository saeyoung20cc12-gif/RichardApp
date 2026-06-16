import UIKit

// MARK: - UIImage + 검정 배경 제거
/// 픽셀 아트 PNG처럼 불투명한 검정 배경을 가진 이미지에서
/// 어두운 픽셀의 알파값을 0으로 만들어 투명하게 처리합니다.
extension UIImage {

    /// threshold 이하(0~255)의 밝기를 가진 픽셀을 투명하게 만들어 반환합니다.
    /// - Parameter threshold: 이 값 이하의 R·G·B 픽셀을 투명 처리 (기본값 40)
    func removingDarkBackground(threshold: Int = 40) -> UIImage {
        guard let cgImage = self.cgImage else { return self }

        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow   = bytesPerPixel * width

        // RGBA 버퍼 생성
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                     | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return self }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 어두운 픽셀 → 투명 처리
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Int(rawData[i])
                let g = Int(rawData[i + 1])
                let b = Int(rawData[i + 2])
                if r < threshold && g < threshold && b < threshold {
                    rawData[i + 3] = 0   // alpha → 투명
                }
            }
        }

        guard let newCG = ctx.makeImage() else { return self }
        return UIImage(cgImage: newCG, scale: self.scale, orientation: self.imageOrientation)
    }
}
