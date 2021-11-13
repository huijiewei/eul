//
//  PreferenceGeneralView.swift
//  eul
//
//  Created by Gao Sun on 2020/9/12.
//  Copyright © 2020 Gao Sun. All rights reserved.
//

import LaunchAtLogin
import SharedLibrary
import SwiftUI
import SwiftyJSON

extension Preference {
    struct GeneralView: View {
        @ObservedObject var launchAtLogin = LaunchAtLogin.observable
        @EnvironmentObject var preference: PreferenceStore

        var body: some View {
            VStack(alignment: .leading) {
                HStack(spacing: 12) {
                    if let version = preference.version {
                        Text("eul \("ui.version".localized()) \(version)")
                            .inlineSection()
                            .fixedSize()
                    }
                    if let url = preference.repoURL {
                        Button(action: {
                            NSWorkspace.shared.open(url)
                        }) {
                            Text("GitHub")
                        }
                        .focusable(false)
                    }
                }
                Toggle(isOn: $launchAtLogin.isEnabled) {
                    Text("ui.launch_at_login".localized())
                        .inlineSection()
                }
                Toggle(isOn: $preference.checkStatusItemVisibility) {
                    Text("ui.check_status_item_visibility".localized())
                        .inlineSection()
                }
            }
            .padding(.vertical, 8)
        }
    }
}
