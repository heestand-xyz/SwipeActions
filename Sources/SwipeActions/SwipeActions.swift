import SwiftUI
import MultiViews

struct SwipeActions<Content: View>: View {

    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    let content: () -> Content

    var body: some View {
        ZStack {
            content()
        }
        .clipped()
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
                    .swipeActions(trailing: [
                        SwipeAction(text: "Remove", style: .init(backgroundColor: .red)) {}
                    ])
            }
        }
    }
}
