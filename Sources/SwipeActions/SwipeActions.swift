import SwiftUI
import MultiViews
import CoreGraphicsExtensions

// MARK: Modifier

extension View {
    
    public func swipe(isEnabled: Bool,
                      style: SwipeActionsStyle = .init(),
                      leadingActions: [SwipeAction] = [],
                      trailingActions: [SwipeAction] = []) -> some View {
        // TODO: Use `isEnabled`
        SwipeActions(style: style,
                     leadingActions: leadingActions,
                     trailingActions: trailingActions) {
            self
        }
    }
}

// MARK: View

struct SwipeActions<Content: View>: View {

    var resetLocation: CGFloat { macOS ? 50 : 100 }
#if !os(macOS)
    var primaryActionLocation: CGFloat { size.width * 0.75 }
    var primaryActionTranslation: CGFloat { size.width * 0.5 }
#endif
    
    let style: SwipeActionsStyle
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let content: () -> Content
    
    private enum ViewState: Equatable {
        
        case inactive
        case options
        case dragging
        case draggingPrimaryAction(SwipeAction)
        case action(SwipeAction, isPrimary: Bool)
        
        var isDragging: Bool {
            switch self {
            case .dragging, .draggingPrimaryAction:
                true
            default:
                false
            }
        }
        
        var action: SwipeAction? {
            switch self {
            case .draggingPrimaryAction(let action), 
                    .action(let action, _):
                action
            default:
                nil
            }
        }
        
        var isPrimaryAction: Bool {
            switch self {
            case .draggingPrimaryAction:
                true
            case .action(_, let isPrimary):
                isPrimary
            default:
                false
            }
        }
    }
    @State private var viewState: ViewState = .inactive {
        didSet {
            DispatchQueue.main.async {
                lastViewState = viewState
            }
        }
    }
    @State private var lastViewState: ViewState = .inactive
    
    @State private var startOffset: CGFloat = 0.0
    @State private var offset: CGFloat = 0.0
    
    enum Side {
        
        case leading
        case trailing
        
        var opposite: Side {
            switch self {
            case .leading:
                return .trailing
            case .trailing:
                return .leading
            }
        }
        
        var multiplier: CGFloat {
            switch self {
            case .leading:
                return 1.0
            case .trailing:
                return -1.0
            }
        }
        
        var alignment: Alignment {
            switch self {
            case .leading:
                return .leading
            case .trailing:
                return .trailing
            }
        }
    }
    @State private var side: Side?
    
    @State private var buttonWidths: [UUID: CGFloat] = [:]
    
    @State private var size: CGSize = .one
    
#if os(macOS)
    @State private var scrollTranslation: CGFloat = 0.0
    @State private var scrollTimer: Timer?
#endif
    
    // MARK: Body
    
    var body: some View {
        ZStack {
            actionsBody(side: .leading)
                .opacity(side == .leading ? 1.0 : 0.0)
                .layoutPriority(-1)
            actionsBody(side: .trailing)
                .opacity(side == .trailing ? 1.0 : 0.0)
                .layoutPriority(-1)
            content()
                .offset(x: length * (side?.multiplier ?? 0.0))
        }
        .readGeometry(size: $size)
#if os(macOS)
        .background { interaction }
#else
        .simultaneousGesture(gesture)
#endif
    }
}

// MARK: - Bodies

extension SwipeActions {
    
    private func actionsBody(side: Side) -> some View {
        
        HStack(spacing: viewState.isPrimaryAction ? 0.0 : spacing(side: side)) {
            
            ForEach(actions(side: side)) { action in
                
                let isPrimary: Bool = primaryAction(side: side) == action
                
                button(action: action, side: .leading)
                    .frame(width: {
                        if viewState.isPrimaryAction && isPrimary {
                            return actionsInnerLength(side: side)
                        } else if viewState == .options || {
                            if case .action(_, let isPrimary) = viewState {
                                return !isPrimary
                            }
                            return false
                        }() {
                            return buttonWidths[action.id] ?? 0.0
                        }
                        return nil
                    }())
                    .opacity(viewState.isPrimaryAction && !isPrimary ? 0.0 : 1.0)
            }
        }
        .padding(.horizontal, paddingWidth)
        .padding(.vertical, style.padding.height)
        .frame(width: viewState == .options ? nil : actionsOuterLength(side: side))
        .frame(maxWidth: .infinity, alignment: side.alignment)
    }
}

// MARK: - Button

extension SwipeActions {
    
    private func button(action: SwipeAction, side: Side) -> some View {
        
        Button {
            guard lastViewState == .options else { return }
            self.doAction(with: action)
        } label: {
            
            ZStack {
                
                action.style.backgroundColor
                
                let showLoadingIndicator: Bool = {
                    if action.style.showLoadingIndicator,
                       case .action(let a, _) = viewState {
                        return action == a
                    }
                    return false
                }()
                
                Group {
                    switch action.content {
                    case .text(let string):
                        Text(string)
                    case .icon(let image):
                        image
                    case .label(let string, let image):
                        Label(title: { Text(string) },
                              icon: { image })
                    }
                }
                .opacity(showLoadingIndicator ? 0.0 : 1.0)
                .animation(.easeInOut, value: showLoadingIndicator)
                .fixedSize()
                .padding(.horizontal)
                .readGeometry(size: Binding(get: { .zero }, set: { newSize in
                    buttonWidths[action.id] = newSize.width
                }))
                .frame(minWidth: 0, alignment: side.alignment)
                .foregroundColor(action.style.foregroundColor)
                .frame(maxWidth: .infinity, alignment: side.alignment)
                .overlay {
                    if showLoadingIndicator {
                        ProgressView()
                            .scaleEffect(macOS ? 0.5 : 1.0)
#if os(macOS)
                            .colorInvert()
#else
                            .tint(action.style.foregroundColor)
#endif
                    }
                }
            }
            .clipShape(.rect(cornerRadius: style.shape.cornerRadius(height: size.height)))
        }
        .buttonStyle(.borderless)
    }
}

// MARK: Lengths

extension SwipeActions {
    
    private var dragLength: CGFloat {
        guard let side: Side else { return 0.0 }
        switch side {
        case .leading:
            if leadingActions.isEmpty { return 0.0 }
        case .trailing:
            if trailingActions.isEmpty { return 0.0 }
        }
        let length = min(offset * side.multiplier, size.width)
        #if os(macOS)
        let maxLength: CGFloat = buttonWidths(side: side)
        if length > maxLength {
            return maxLength + (length - maxLength) * 0.25
        }
        #endif
        return length
    }
    
    private var length: CGFloat {
        guard let side: Side else { return 0.0 }
        switch viewState {
        case .inactive:
            return 0.0
        case .options:
            return actionsOuterLength(side: side)
        case .dragging:
            return dragLength
        case .draggingPrimaryAction:
            return size.width
        case .action(_, let isPrimary):
            return isPrimary ? size.width : actionsOuterLength(side: side)
        }
    }
    
    private var minLength: CGFloat? {
        switch viewState {
        case .inactive:
            return 0.0
        case .options:
            return nil
        case .dragging:
            return dragLength
        case .draggingPrimaryAction, .action:
            return nil
        }
    }
    
    private var paddingWidth: CGFloat {
        guard let minLength: CGFloat else {
            return style.padding.width
        }
        return min(style.padding.width * 4, minLength) / 4
    }
    
    private func spacing(side: Side) -> CGFloat {
        guard let minLength: CGFloat else {
            return style.spacing
        }
        let spacing: CGFloat = min(style.spacing * CGFloat(actions(side: side).count) * 2, minLength)
        return spacing / CGFloat(leadingActions.count) / 2
    }
    
    private func actions(side: Side) -> [SwipeAction] {
        switch side {
        case .leading:
            return leadingActions
        case .trailing:
            return trailingActions
        }
    }
    
    private func primaryAction(side: Side) -> SwipeAction? {
        switch side {
        case .leading:
            return leadingActions.first
        case .trailing:
            return trailingActions.last
        }
    }
    
    private func buttonWidths(side: Side) -> CGFloat {
        let actions: [SwipeAction] = actions(side: side)
        if actions.isEmpty { return 0.0 }
        return actions
            .compactMap { action in
                buttonWidths[action.id]
            }
            .reduce(0.0, +)
        + style.spacing * CGFloat(actions.count - 1)
        + style.padding.width * 2
    }
    
    private func actionsOuterLength(side: Side) -> CGFloat {
        if viewState.isPrimaryAction {
          return size.width
        } else if viewState == .options || (viewState.action != nil && !viewState.isPrimaryAction) {
            return buttonWidths(side: side)
        }
        return length
    }
    
    private func actionsInnerLength(side: Side) -> CGFloat {
        max(0.0, actionsOuterLength(side: side) - paddingWidth * 2.0)
    }
    
    private func buttonAverageWidth(side: Side) -> CGFloat {
        let actionCount: Int = actions(side: side).count
        return (length - style.spacing * CGFloat(actionCount - 1) - style.padding.width * 2) / CGFloat(actionCount)
    }
}

// MARK: - Gestures

extension SwipeActions {
    
#if os(macOS)
    private var interaction: some View {
        MVInteractView(interacted: { _ in }, scrolling: { offset in
            scrollTimer?.invalidate()
            if !viewState.isDragging {
                if case .action = viewState { return }
                gestureStart()
            }
            scrollTranslation += offset.x
            gestureUpdate(translation: scrollTranslation,
                          location: nil)
            scrollTimer = .scheduledTimer(withTimeInterval: 0.25, repeats: false, block: { _ in
                gestureEnd()
                scrollTranslation = 0.0
                scrollTimer = nil
            })
        })
    }
#else
    private var gesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !viewState.isDragging {
                    if case .action = viewState { return }
                    gestureStart()
                }
                gestureUpdate(translation: value.translation.width,
                              location: value.location.x)
            }
            .onEnded { _ in
                gestureEnd()
            }
    }
#endif
}

// MARK: Gesture Actions

extension SwipeActions {
    
    private func gestureStart() {
        startOffset = offset
    }
    
    private func gestureUpdate(translation: CGFloat,
                               location: CGFloat?) {
        
#if !os(macOS)
        var draggingAbsolutePrimaryAction: Bool {
            guard let side: Side else { return false }
            guard let location: CGFloat else { return false }
            switch side {
            case .leading:
                return location > primaryActionLocation
            case .trailing:
                return location < size.width - primaryActionLocation
            }
        }
        
        var draggingRelativePrimaryAction: Bool {
            return length > primaryActionTranslation
        }
#endif
        
        var draggingPrimaryAction: Bool {
#if os(macOS)
            return false
#else
            return draggingRelativePrimaryAction && draggingAbsolutePrimaryAction
#endif
        }
        
        if draggingPrimaryAction {
            
            if case .draggingPrimaryAction = viewState {} else {
                
                if let side: Side,
                    let action: SwipeAction = primaryAction(side: side) {
                    
                    withAnimation {
                        viewState = .draggingPrimaryAction(action)
                    }
                }
            }
            
        } else if viewState != .dragging {
            
            if case .draggingPrimaryAction = viewState {
                
                // TODO: Animate to .dragging
            }
            
            viewState = .dragging
        }

        offset = startOffset + translation
        
        if side != .leading, offset > 0.0 {
            side = .leading
        } else if side != .trailing, offset < 0.0 {
            side = .trailing
        }
    }
    
    private func gestureEnd() {
        
        var canReset: Bool = false
        if viewState == .dragging {
            canReset = abs(offset) < resetLocation
        }
        
        if case .draggingPrimaryAction(let action) = viewState {
            doAction(with: action)
        } else if canReset {
            withAnimation {
                reset()
            }
        } else {
            guard let side: Side else { return }
            withAnimation {
                viewState = .options
                offset = actionsOuterLength(side: side) * side.multiplier
            }
        }
    }
}

// MARK: Button Actions

extension SwipeActions {
    
    private func doAction(with action: SwipeAction) {
        willAction(with: action)
        Task {
            await action.call()
            didAction(with: action)
        }
    }
    
    private func willAction(with action: SwipeAction) {
        let isPrimary: Bool = {
            guard let side: Side else { return false }
            return primaryAction(side: side) == action
        }()
        withAnimation {
            viewState = .action(action, isPrimary: isPrimary)
        }
    }
    
    private func didAction(with action: SwipeAction) {
        withAnimation {
            reset()
        }
    }
}

// MARK: Reset

extension SwipeActions {
    
    func reset() {
        side = nil
        viewState = .inactive
        offset = 0.0
        startOffset = 0.0
    }
}

// MARK: Mocks

fileprivate func mock(named name: String) -> some View {
    Text(name)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            Color.primary
                .opacity(0.1)
        }
}

// MARK: Preview

#Preview {
    ScrollView {
        VStack(spacing: 1.0) {
            mock(named: "First")
                .swipe(trailingActions: [
                    SwipeAction(
                        .label(text: "Remove", icon: Image(systemName: "trash")),
                        style: .init(backgroundColor: .red)) {
                            print("Remove")
                        }
                ])
            mock(named: "Second")
                .swipe(leadingActions: [
                    SwipeAction(
                        .icon(Image(systemName: "plus")),
                        style: .init(backgroundColor: .green)) {
                            print("Add")
                        }
                ])
            mock(named: "Third")
                .swipe(style: SwipeActionsStyle(
                    spacing: 5,
                    padding: CGSize(width: 5, height: 5),
                    shape: .capsule
                ), leadingActions: [
                    SwipeAction(
                        .text("Add"),
                        style: .init(backgroundColor: .green)) {
                            print("Add")
                        },
                    SwipeAction(
                        .text("Move"),
                        style: .init(backgroundColor: .blue)) {
                            print("Move")
                        }
                ], trailingActions: [
                    SwipeAction(
                        .text("Remove"),
                        style: .init(backgroundColor: .red)) {
                            print("Remove")
                        }
                ])
        }
    }
}
