import SwiftUI

public struct SwipeAction: Identifiable {
    
    public var id: String {
        text
    }
    
    let text: String
    let icon: Image?
    
    public struct Style {
        let foregroundColor: Color
        let backgroundColor: Color
        public init(foregroundColor: Color = .white, backgroundColor: Color) {
            self.foregroundColor = foregroundColor
            self.backgroundColor = backgroundColor
        }
    }
    let style: Style
    
    let call: () -> ()
    
    public init(text: String, icon: Image? = nil, style: Style, _ call: @escaping () -> ()) {
        self.text = text
        self.icon = icon
        self.style = style
        self.call = call
    }
}
