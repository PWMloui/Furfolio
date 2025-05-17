//
//  SectionHeaderView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import SwiftUI
// TODO: Allow configurable padding and background color via parameters or environment.

@MainActor
/// A reusable view for section headers, applying consistent styling across the app.
struct SectionHeaderView: View {
  /// The text displayed as the section header.
  let title: String
  let padding: EdgeInsets
  let backgroundColor: Color

  init(title: String,
       padding: EdgeInsets = EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16),
       backgroundColor: Color = Color(.systemBackground)) {
    self.title = title
    self.padding = padding
    self.backgroundColor = backgroundColor
  }

  /// The view body that renders the title text with the section header style.
  var body: some View {
    Text(title)
      .sectionHeaderStyle()
      .padding(padding)
      .background(backgroundColor)
  }
}

#if DEBUG
struct SectionHeaderView_Previews: PreviewProvider {
  static var previews: some View {
    SectionHeaderView(title: "Example Section Header",
                      padding: EdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20),
                      backgroundColor: Color(.secondarySystemBackground))
      .padding()
      .previewLayout(.sizeThatFits)
  }
}
#endif
