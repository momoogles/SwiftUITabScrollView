//
//  utils.swift
//  TabScrollView
//
//  Created by mog on 2024/09/20.
//

import SwiftUI

private struct MeasureSize: ViewModifier {
  @Binding var size: CGSize
  
  func body(content: Content) -> some View {
    content.onGeometryChange(for: CGSize.self) {
      $0.size
    } action: {
      size = $0
    }
  }
}

private struct MaxContentHeightPreferenceKey: PreferenceKey {
  typealias Value = CGFloat
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout Value, nextValue: () -> Value) { value = max(value, nextValue()) }
}

private struct MaxContentHeightPreference: ViewModifier {
  @State private var contentHeight: CGFloat = .zero

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGFloat.self) {
        $0.size.height
      } action: {
        contentHeight = $1
      }
      .preference(key: MaxContentHeightPreferenceKey.self, value: contentHeight)
  }
}

private struct ScrollHeightPreferenceKey<T: Hashable>: PreferenceKey {
  typealias Value = [T: CGFloat]
  static var defaultValue: Value { get { [:] } }
  static func reduce(value: inout Value, nextValue: () -> Value) { value.merge(nextValue()) { (_, new) in new } }
}

private struct ScrollHeightPreference<T: Hashable>: ViewModifier {
  let id: T
  @State private var scrollHeight: CGFloat = .zero

  func body(content: Content) -> some View {
    content
      .onScrollGeometryChange(for: CGFloat.self) {
        $0.contentInsets.top + $0.contentOffset.y
      } action: {
        scrollHeight = $1
      }
      .preference(key: ScrollHeightPreferenceKey<T>.self, value: [id: scrollHeight])
  }
}

extension View {
  func measureSize(_ size: Binding<CGSize>) -> some View {
    modifier(MeasureSize(size: size))
  }

  func scrollHeightPreference<T: TabType>(_ id: T) -> some View {
    modifier(ScrollHeightPreference(id: id))
  }

  func scrollHeightPreferenceValue<T: TabType>(_ idType: T.Type,  perform: @escaping ([T: CGFloat]) -> Void) -> some View {
    onPreferenceChange(ScrollHeightPreferenceKey<T>.self, perform: perform)
  }

  func maxContentHeightPreference() -> some View {
    modifier(MaxContentHeightPreference())
  }

  func maxContentHeightPreferenceValue(perform: @escaping (CGFloat) -> Void) -> some View {
    onPreferenceChange(MaxContentHeightPreferenceKey.self, perform: perform)
  }
}
