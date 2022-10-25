import SwiftUI

struct RangeSlider: View {
    @ObservedObject var viewModel: ViewModel
    @State private var isActive: Bool = false
    let sliderPositionChanged: (ClosedRange<Float>) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            sliderView(sliderSize: geometry.size,
                       sliderViewYCenter: geometry.size.height / 2)
        }
        .frame(height: 20)
    }
    
    @ViewBuilder private func sliderView(sliderSize: CGSize, sliderViewYCenter: CGFloat) -> some View {
        lineBetweenThumbs(from: viewModel.leftThumbLocation(width: sliderSize.width,
                                                            sliderViewYCenter: sliderViewYCenter),
                          to: viewModel.rightThumbLocation(width: sliderSize.width,
                                                           sliderViewYCenter: sliderViewYCenter))
        
        thumbView(position: viewModel.leftThumbLocation(width: sliderSize.width,
                                                        sliderViewYCenter: sliderViewYCenter),
                  value: Float(viewModel.sliderPosition.lowerBound))
        .highPriorityGesture(DragGesture().onChanged { dragValue in
            let newValue = viewModel.newThumbLocation(dragLocation: dragValue.location,
                                                      width: sliderSize.width)
            
            if newValue < viewModel.sliderPosition.upperBound {
                viewModel.sliderPosition = newValue...viewModel.sliderPosition.upperBound
                sliderPositionChanged(viewModel.sliderPosition)
                isActive = true
            }
        })
        
        thumbView(position: viewModel.rightThumbLocation(width: sliderSize.width,
                                                         sliderViewYCenter: sliderViewYCenter),
                  value: Float(viewModel.sliderPosition.upperBound))
        .highPriorityGesture(DragGesture().onChanged { dragValue in
            let newValue = viewModel.newThumbLocation(dragLocation: dragValue.location,
                                                      width: sliderSize.width)
            
            if newValue > viewModel.sliderPosition.lowerBound {
                viewModel.sliderPosition = viewModel.sliderPosition.lowerBound...newValue
                sliderPositionChanged(viewModel.sliderPosition)
                isActive = true
            }
        })
    }
    
    @ViewBuilder func lineBetweenThumbs(from: CGPoint, to: CGPoint) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(.gray)
                .frame(height: 4)
            
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(isActive ? .blue : .gray,
                    lineWidth: 4)
        }
    }
    
    @ViewBuilder func thumbView(position: CGPoint, value: Float) -> some View {
        Circle()
            .frame(width: 20, height: 20
            )
            .foregroundColor(isActive ? .gray  : .gray)
            .contentShape(Rectangle())
            .position(x: position.x, y: position.y)
            .animation(.spring(), value: isActive)
    }
}

extension RangeSlider {
    final class ViewModel: ObservableObject {
        @Published var sliderPosition: ClosedRange<Float>
        let sliderBounds: ClosedRange<Int>
        
        let sliderBoundDifference: Int
        
        init(sliderPosition: ClosedRange<Float>,
             sliderBounds: ClosedRange<Int>) {
            self.sliderPosition = sliderPosition
            self.sliderBounds = sliderBounds
            self.sliderBoundDifference = sliderBounds.count - 1
        }
        
        func leftThumbLocation(width: CGFloat, sliderViewYCenter: CGFloat = 0) -> CGPoint {
            let sliderLeftPosition = CGFloat(sliderPosition.lowerBound - Float(sliderBounds.lowerBound))
            return .init(x: sliderLeftPosition * stepWidthInPixel(width: width),
                         y: sliderViewYCenter)
        }
        
        func rightThumbLocation(width: CGFloat, sliderViewYCenter: CGFloat = 0) -> CGPoint {
            let sliderRightPosition = CGFloat(sliderPosition.upperBound - Float(sliderBounds.lowerBound))
            
            return .init(x: sliderRightPosition * stepWidthInPixel(width: width),
                         y: sliderViewYCenter)
        }
        
        func newThumbLocation(dragLocation: CGPoint, width: CGFloat) -> Float {
            let xThumbOffset = min(max(0, dragLocation.x), width)
            return Float(sliderBounds.lowerBound) + Float(xThumbOffset / stepWidthInPixel(width: width))
        }
        
        private func stepWidthInPixel(width: CGFloat) -> CGFloat {
            width / CGFloat(sliderBoundDifference)
        }
    }
}

struct RangeSlider_Previews: PreviewProvider {
    static var previews: some View {
        RangeSlider(viewModel: .init(sliderPosition: 2...8,
                                     sliderBounds: 1...10),
                    sliderPositionChanged: { _ in })
    }
}
