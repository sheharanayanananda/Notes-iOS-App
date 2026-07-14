//
//  MarkdownStaticPreview.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI

struct MarkdownStaticPreview: View {
    let block: MarkdownBlock
    
    var body: some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
        case .header(let level, let text):
            Text(text)
                .font(.system(size: headerSize(for: level), weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
        case .blockquote(let blocks):
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<blocks.count, id: \.self) { idx in
                        MarkdownStaticPreview(block: blocks[idx])
                    }
                }
            }
            .padding(.vertical, 4)
            
        case .list(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        if item.level > 0 {
                            Spacer()
                                .frame(width: CGFloat(item.level) * 16)
                        }
                        
                        if let checkbox = item.checkboxState {
                            Image(systemName: checkbox == .checked ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(checkbox == .checked ? Color.blue : Color.secondary.opacity(0.6))
                                .font(.system(size: 16))
                        } else {
                            switch item.type {
                            case .bullet:
                                Text("•")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.secondary)
                            case .numbered(let number):
                                Text("\(number).")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(item.text)
                            .font(.system(size: 16))
                            .strikethrough(item.checkboxState == .checked)
                            .foregroundColor(item.checkboxState == .checked ? .secondary : .primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
        case .code(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                if let lang = language, !lang.isEmpty {
                    Text(lang.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04))
                }
                
                Text(code)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            
        case .table(let headers, _, let rows):
            VStack(alignment: .leading, spacing: 0) {
                // Table header
                HStack(spacing: 8) {
                    ForEach(headers, id: \.self) { header in
                        Text(header)
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.05))
                
                Divider()
                
                // Table rows
                ForEach(0..<rows.count, id: \.self) { rIdx in
                    let row = rows[rIdx]
                    HStack(spacing: 8) {
                        ForEach(0..<row.count, id: \.self) { cIdx in
                            Text(row[cIdx])
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(rIdx % 2 == 0 ? Color.clear : Color.primary.opacity(0.02))
                    
                    if rIdx < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            
        case .thematicBreak:
            Divider()
                .padding(.vertical, 12)
            
        case .latex(let isDisplay, let equation):
            VStack {
                Text(equation)
                    .font(.system(size: 16, weight: .medium, design: .serif))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(isDisplay ? 16 : 4)
            }
            .frame(maxWidth: isDisplay ? .infinity : nil, alignment: .center)
            .background(isDisplay ? Color.primary.opacity(0.02) : Color.clear)
            .cornerRadius(8)
            
        case .alert(let type, let blocks):
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(type.color)
                
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<blocks.count, id: \.self) { idx in
                        MarkdownStaticPreview(block: blocks[idx])
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(type.color.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(type.color.opacity(0.2), lineWidth: 1)
            )
            
        case .image(let caption, let url):
            VStack(spacing: 8) {
                if let resolvedURL = URL(string: url) {
                    AsyncImage(url: resolvedURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        default:
                            ProgressView()
                        }
                    }
                    .frame(maxHeight: 250)
                    .cornerRadius(8)
                }
                
                if !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func headerSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return 24
        case 2: return 20
        case 3: return 18
        default: return 16
        }
    }
}
