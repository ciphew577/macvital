// MacVital/Views/Anatomy/Variants/AnatomyBentoSchematic.swift

import SwiftUI

struct AnatomyBentoSchematic: View {

    @Bindable var viewModel: AnatomyViewModel

    var body: some View {
        AnatomyHero(viewModel: viewModel)
    }
}

#if DEBUG
#Preview("Bento Schematic") {
    AnatomyBentoSchematic(viewModel: AnatomyViewModel())
        .frame(width: 1_200, height: 600)
        .background(MV.bg)
}
#endif
