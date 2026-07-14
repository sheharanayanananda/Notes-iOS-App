//
//  SlateModel.swift
//  Slate
//
//  Created by Thineth Shehara on 2026-02-08.
//

import Foundation
import SwiftData

@Model
final class SlateModel: Identifiable {
    @Attribute(.unique) var id: String
    var title: String
    var desc: String
    var created_at: Date

    init(id: String = UUID().uuidString, title: String, desc: String, created_at: Date = .now) {
        self.id = id
        self.title = title
        self.desc = desc
        self.created_at = created_at
    }
}
