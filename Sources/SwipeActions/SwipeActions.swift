import SwiftUI
import MultiViews

struct SwipeActions<Content: View>: View {

    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let content: () -> Content
    
    @State private var endTimer: Timer?

    struct Drag {
        var isActive: Bool = false
        enum Side {
            case leading
            case trailing
        }
        var side: Side?
        var translation: CGFloat = 0.0
        mutating func reset() {
            isActive = false
            side = nil
            translation = 0.0
        }
    }
    @State private var drag = Drag()
    
    private var offset: CGFloat {
        guard let side: Drag.Side = drag.side else { return 0.0 }
        var offset: CGFloat = drag.translation
        switch side {
        case .leading:
            offset = max(0.0, offset)
        case .trailing:
            offset = min(0.0, offset)
        }
        return offset
    }
    
    private var length: CGFloat {
        abs(offset)
    }
    
    var body: some View {
        ZStack {
            content()
                .offset(x: offset)
            if let side: Drag.Side = drag.side {
                actionsBody(side: side)
                    .layoutPriority(-1)
            }
        }
        .gesture(gesture)
    }
    
    @ViewBuilder
    private func actionsBody(side: Drag.Side) -> some View {
        switch side {
        case .leading:
            HStack(spacing: 0.0) {
                leadingActionsBody
                Spacer(minLength: 0.0)
            }
        case .trailing:
            HStack(spacing: 0.0) {
                Spacer(minLength: 0.0)
                trailingActionsBody
            }
        }
    }
    
    private var leadingActionsBody: some View {
        HStack(spacing: 0.0) {
            ForEach(leadingActions) { action in
                button(action: action)
            }
        }
        .frame(width: length)
    }
    
    private var trailingActionsBody: some View {
        HStack(spacing: 0.0) {
            ForEach(trailingActions) { action in
                button(action: action)
            }
        }
        .frame(width: length)
    }
    
    private func button(action: SwipeAction) -> some View {
        Button(action: action.call) {
            ZStack {
                action.style.backgroundColor
                Group {
                    if let icon: Image = action.icon {
                        icon
                    } else {
                        Text(action.text)
                    }
                }
                .fixedSize()
                .layoutPriority(-1)
                .foregroundColor(action.style.foregroundColor)
            }
            .clipped()
        }
    }
    
    private var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !drag.isActive {
                    drag.isActive = true
                    drag.side = value.translation.width < 0.0 ? .trailing : .leading
                    if let endTimer: Timer {
                        endTimer.invalidate()
                        self.endTimer = nil
                    }
                }
                drag.translation = value.translation.width
            }
            .onEnded { value in
                withAnimation(.easeInOut(duration: 0.5)) {
                    drag.translation = 0.0
                }
                endTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    drag.reset()
                    endTimer = nil
                }
            }
    }
}

extension View {
    public func swipeActions(leading leadingActions: [SwipeAction] = [],
                             trailing trailingActions: [SwipeAction] = []) -> some View {
        SwipeActions(leadingActions: leadingActions,
                     trailingActions: trailingActions) {
            self
        }
    }
}

#Preview {
    ScrollView {
        VStack {
            ForEach(0..<10) { index in
                Text("Item \(index + 1)")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        Color.primary
                            .opacity(0.1)
                    }
                    .swipeActions(leading: [
                        SwipeAction(text: "Add", style: .init(backgroundColor: .green)) {},
                        SwipeAction(text: "Move", style: .init(backgroundColor: .blue)) {},
                    ], trailing: [
                        SwipeAction(text: "Remove", style: .init(backgroundColor: .red)) {},
                    ])
            }
        }
    }
}
