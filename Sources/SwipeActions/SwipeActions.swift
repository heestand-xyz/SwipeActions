import SwiftUI
import MultiViews

struct SwipeActions<Content: View>: View {

    let style: SwipeActionsStyle
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let content: () -> Content
    
    @State private var endTimer: Timer?

    struct Drag {
        var isActive: Bool = false
        var translation: CGFloat = 0.0
        mutating func reset() {
            isActive = false
            translation = 0.0
        }
    }
    @State private var drag = Drag()
    
    enum Side {
        case leading
        case trailing
    }
    @State var side: Side?
    
    private var offset: CGFloat {
        guard let side: Side else { return 0.0 }
        var offset: CGFloat = drag.translation
        switch side {
        case .leading:
            if leadingActions.isEmpty { return 0.0 }
            offset = max(0.0, offset)
        case .trailing:
            if trailingActions.isEmpty { return 0.0 }
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
            if let side: Side {
                actionsBody(side: side)
                    .layoutPriority(-1)
            }
        }
        .gesture(gesture)
        .onChange(of: drag.translation) { newTranslation in
            if side != .leading, newTranslation > 0.0 {
                side = .leading
            } else if side != .trailing, newTranslation < 0.0 {
                side = .trailing
            }
        }
    }
    
    private func actionsBody(side: Side) -> some View {
        Group {
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
        .padding(.horizontal, style.padding.width)
        .padding(.vertical, style.padding.height)
    }
    
    private var leadingActionsBody: some View {
        HStack(spacing: style.spacing) {
            ForEach(leadingActions) { action in
                let width: CGFloat = length / CGFloat(leadingActions.count)
                button(action: action, side: .leading, width: width)
            }
        }
        .frame(width: length)
    }
    
    private var trailingActionsBody: some View {
        HStack(spacing: style.spacing) {
            ForEach(trailingActions) { action in
                let width: CGFloat = length / CGFloat(trailingActions.count)
                button(action: action, side: .trailing, width: width)
            }
        }
        .frame(width: length)
    }
    
    private func button(action: SwipeAction, side: Side, width: CGFloat) -> some View {
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
                .padding(.horizontal)
                .frame(minWidth: 0, alignment: side == .leading ? .trailing : .leading)
                .foregroundColor(action.style.foregroundColor)
                .frame(width: width, alignment: side == .leading ? .leading : .trailing)
            }
        }
        .clipShape(.rect(cornerRadius: style.cornerRadius))
    }
    
    private var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !drag.isActive {
                    drag.isActive = true
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
                    side = nil
                    endTimer = nil
                }
            }
    }
}

extension View {
    public func swipeActions(style: SwipeActionsStyle = .init(),
                             leading leadingActions: [SwipeAction] = [],
                             trailing trailingActions: [SwipeAction] = []) -> some View {
        SwipeActions(style: style,
                     leadingActions: leadingActions,
                     trailingActions: trailingActions) {
            self
        }
    }
}

fileprivate func mock(named name: String) -> some View {
    Text(name)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.primary
                .opacity(0.1)
        }
}

#Preview {
    ScrollView {
        VStack(spacing: 1.0) {
            mock(named: "First")
                .swipeActions(trailing: [
                    SwipeAction(text: "Remove", style: .init(backgroundColor: .red)) {}
                ])
            mock(named: "Second")
                .swipeActions(leading: [
                    SwipeAction(text: "Add", style: .init(backgroundColor: .green)) {}
                ])
            mock(named: "Third")
                .swipeActions(style: SwipeActionsStyle(
                    spacing: 5,
                    padding: CGSize(width: 5, height: 5),
                    cornerRadius: 5
                ), leading: [
                    SwipeAction(text: "Add", style: .init(backgroundColor: .green)) {},
                    SwipeAction(text: "Move", style: .init(backgroundColor: .blue)) {}
                ], trailing: [
                    SwipeAction(text: "Remove", style: .init(backgroundColor: .red)) {}
                ])
        }
    }
}
