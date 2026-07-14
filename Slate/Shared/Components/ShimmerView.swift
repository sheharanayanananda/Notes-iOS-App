//
//  ShimmerView.swift
//  Slate
//
//  Created by Antigravity on 2026-07-14.
//

import SwiftUI

struct ShimmerView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        TimelineView(.animation) { timelineContext in
            let date = timelineContext.date
            let timeInterval = date.timeIntervalSinceReferenceDate
            let phase = CGFloat((timeInterval).truncatingRemainder(dividingBy: 1.8) / 1.8)
            
            content
                .mask(
                    GeometryReader { geo in
                        let size = geo.size
                        ZStack(alignment: .leading) {
                            Color.black.opacity(0.35)
                            
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .clear,
                                    .black,
                                    .clear
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: size.width / 1.2)
                            .offset(x: -size.width + (size.width * 2) * phase)
                        }
                    }
                )
        }
    }
}

struct SkeletonLine: View {
    let width: CGFloat
    let delay: Double
    @State private var entranceOpacity: Double = 0.0
    
    var body: some View {
        ShimmerView {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.06))
                .frame(width: width, height: 16)
        }
        .opacity(entranceOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(delay)) {
                entranceOpacity = 1.0
            }
        }
    }
}

struct SkeletonView: View {
    let typedLinesCount: Int
    @State private var appearanceOpacity: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let widths: [CGFloat] = [
                140, 300, 260, 280, 120, 240, 270, 180, 290, 250, 270, 190, 150
            ]
            
            ForEach(0..<widths.count, id: \.self) { index in
                if index >= typedLinesCount {
                    SkeletonLine(width: widths[index], delay: Double(index) * 0.035)
                        .transition(.opacity)
                } else {
                    Color.clear
                        .frame(height: 16)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .opacity(appearanceOpacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4)) {
                appearanceOpacity = 1.0
            }
        }
    }
}
