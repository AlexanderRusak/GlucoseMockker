//
//  DateFormatter.swift
//  GlucoseMocker
//
//  Created by Александр Русак on 02/02/2025.
//

import Foundation

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    return formatter
}()
