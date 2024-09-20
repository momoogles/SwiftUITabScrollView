//
//  TabScrollView.swift
//  TabScrollView
//
//  Created by mog on 2024/09/20.
//

import SwiftUI

typealias TabType = Sendable & CaseIterable & Identifiable & Hashable

private extension EnvironmentValues {
  @Entry var tabNamespace: Namespace.ID? = nil
}

@Observable
class ScrollViewState<T: TabType>: Identifiable {
  internal init(id: T) {
    self.id = id
  }
  let id: T
  var isScrolling = false
  var scrollPosition = ScrollPosition(idType: T.self)
}

struct TabScrollView<T: TabType, Header: View, Label: View, Panel: View>: View where T.AllCases == Array<T> {
  internal init(
    tabType: T.Type,
    header: @escaping () -> Header,
    tabButton: @escaping (T, T, @escaping (T) -> Void) -> Label,
    tabPanel: @escaping (T) -> Panel,
    refreshable: (@Sendable (T) async -> Void)? = nil
  ) {
    self.tabType = tabType
    self.header = header
    self.tabButton = tabButton
    self.tabPanel = tabPanel
    self.refreshable = refreshable
    self.tabPanelStates = tabType.allCases.map { ScrollViewState(id: $0) }
  }
  let tabType: T.Type
  @ViewBuilder let header: () -> Header
  @ViewBuilder let tabButton: (_ id: T, _ selected: T, _ switchTabPanel: @escaping (T) -> Void) -> Label
  @ViewBuilder let tabPanel: (_ id: T) -> Panel
  @MainActor let refreshable: (@Sendable (_ id: T) async -> Void)?

  @State private var tabPanelStates: [ScrollViewState<T>]

  @State private var headerSize: CGSize = .zero
  @State private var offset: CGFloat = 0
  @State private var tabSize: CGSize = .zero
  @State private var tabScrollPosition = ScrollPosition(idType: T.self)
  @State private var minHeight: CGFloat = 0
  private var selected: T { tabScrollPosition.viewID(type: T.self) ?? T.allCases.first! }

  @Namespace private var tabNamespace

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach(tabPanelStates) { state in
          @Bindable var state = state
          ScrollView(.vertical) {
            VStack(spacing: 0) {
              tabPanel(state.id)
            }
            .maxContentHeightPreference()
            .frame(minHeight: minHeight, alignment: .top)
          }
          .containerRelativeFrame(.horizontal)
          .refreshable { await Task { await refreshable?(state.id) }.value }
          .onScrollPhaseChange { state.isScrolling = $1.isScrolling }
          .scrollHeightPreference(state.id)
          .scrollPosition($state.scrollPosition)
        }
      }
      .scrollTargetLayout()
      .safeAreaPadding(.top, tabSize.height + headerSize.height)
      .scrollHeightPreferenceValue(tabType) { v in
        let items = tabPanelStates.map { s in (state: s, scrollHeight: min(v[s.id]!, headerSize.height)) }

        let scrolling = items.first { (s, _) in s.isScrolling }
        guard let scrolling else { return }

        offset = -scrolling.scrollHeight
        let stoppings = items.filter { (s, _) in !s.isScrolling }
        for (state, _) in stoppings {
          state.scrollPosition.scrollTo(y: scrolling.scrollHeight)
        }
      }
      .maxContentHeightPreferenceValue {
        minHeight = $0
      }
    }
    .scrollTargetBehavior(.viewAligned)
    .scrollPosition($tabScrollPosition)
    .overlay {
      VStack(spacing: 0) {
        Group {
          header().measureSize($headerSize)
          Grid(horizontalSpacing: 0) {
            GridRow {
              ForEach(tabType.allCases) { id in
                tabButton(id, selected, switchTabPanel)
              }
            }
          }
          .measureSize($tabSize)
          .environment(\.tabNamespace, tabNamespace)
        }
        .offset(y: offset)
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .animation(.interactiveSpring, value: selected)
  }

  func switchTabPanel(_ id: T) {
    tabScrollPosition.scrollTo(id: id)
  }
}

#Preview {
  struct Preview: View {
    enum CustomColor {
      static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(red: red / 255, green: green / 255, blue: blue / 255)
      }
      static let surface1 = rgb(19, 18, 19)
      static let surface2 = rgb(28, 27, 29)
      static let surface3 = rgb(33, 31, 33)
      static let onSurface1 = rgb(230, 244, 234)
      static let link1 = rgb(1559, 134, 255)
    }

    struct CustomHeader: View {
      @State private var offset: CGFloat = 0

      var body: some View {
        VStack(alignment: .leading) {
          Rectangle().fill(CustomColor.surface2)
            .ignoresSafeArea(edges: .top)
            .frame(height: 120 + offset).padding(.top, -offset)
            .onGeometryChange(for: CGFloat.self) { proxy in
              proxy.frame(in: .local).minY
            } action: { offset = max($0, 0) }
          Circle().fill(CustomColor.surface3)
            .overlay {
              Circle().strokeBorder(CustomColor.surface1, lineWidth: 4)
            }
            .frame(width: 80, height: 80).padding(.horizontal, 16).padding(.top, -42)
          VStack(alignment: .leading) {
            Capsule().fill(CustomColor.surface3).frame(width: 120, height: 24)
            Capsule().fill(CustomColor.surface3).frame(width: 144, height: 16)
          }
          .padding(.horizontal, 16)
         Rectangle().fill(.clear).frame(height: 32)
        }
        .background(CustomColor.surface1)
      }
    }

    struct CustomTabButton<Label: View>: View {
      let selected: Bool
      let action: () -> Void
      let label: (_ selected: Bool) -> Label

      @Environment(\.tabNamespace) private var tabNamespace

      var body: some View {
        Button {
          action()
        } label: {
          VStack(spacing: 8) {
            label(selected).frame(height: 40)
            Divider().overlay {
              if selected, let tabNamespace {
                CustomColor.link1.matchedGeometryEffect(id: "tab", in: tabNamespace).padding(.horizontal, 16)
              }
            }
          }
        }
        .background(CustomColor.surface1)
      }
    }

    struct CustomTabLabel: View {
      internal init(_ label: String, selected: Bool) {
        self.label = label
        self.selected = selected
      }
      let label: String
      let selected: Bool

      var body: some View {
        Text(label).foregroundStyle(selected ? CustomColor.link1 : CustomColor.onSurface1).fontWeight(.bold)
      }
    }

    struct CustomTabPanel: View {
      @Binding var count: Int

      var body: some View {
        Grid {
          ForEach(0...count, id: \.self) { _ in
            GridRow {
              ForEach(1...2, id: \.self) { _ in
                Rectangle().fill(CustomColor.surface3).aspectRatio(1, contentMode: .fit)
              }
            }
          }
        }
        .padding(16)
        Button("Load More") {
          withAnimation(.interactiveSpring) {
            count += 1
          }
        }
        .foregroundStyle(CustomColor.link1)
      }
    }

    @State private var helloCount: Int = 0
    @State private var worldCount: Int = 0
    @State private var hogeCount: Int = 0

    enum CustomTabType: TabType {
      var id: Self { return self }
      case hello, world, hoge
    }

    var body: some View {
      VStack {
        TabScrollView(tabType: CustomTabType.self) {
          CustomHeader()
        } tabButton: { id, selected, switchTabPanel in
          CustomTabButton(selected: selected == id) {
            switchTabPanel(id)
          } label: { selected in
            switch id {
            case .hello: CustomTabLabel("Hello", selected: selected)
            case .world: CustomTabLabel("World", selected: selected)
            case .hoge: CustomTabLabel("Hoge", selected: selected)
            }
          }
        } tabPanel: { id in
          switch id {
          case .hello: CustomTabPanel(count: $helloCount)
          case .world: CustomTabPanel(count: $worldCount)
          case .hoge: CustomTabPanel(count: $hogeCount)
          }
        } refreshable: { id in
          try? await Task.sleep(for: .seconds(2))
          await resetCount(id)
        }
        .background(CustomColor.surface1)
        .preferredColorScheme(.dark)
      }
    }

    @MainActor
    func resetCount(_ id: CustomTabType) {
      withAnimation(.interactiveSpring) {
        switch id {
        case .hello: helloCount = 0
        case .world: worldCount = 0
        case .hoge: hogeCount = 0
        }
      }
    }
  }

  return Preview()
}
