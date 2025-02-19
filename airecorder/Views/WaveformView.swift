import SwiftUI

struct WaveformView: View {
    let level: Float
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<Int(geometry.size.width / 6), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue)
                        .frame(width: 3)
                        .frame(height: geometry.size.height * CGFloat(level) * randomHeight())
                        .animation(.easeInOut(duration: 0.1), value: level)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    private func randomHeight() -> CGFloat {
        return CGFloat.random(in: 0.3...1.0)
    }
}

