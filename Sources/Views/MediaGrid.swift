import SwiftUI

struct ViewerPayload: Identifiable {
    let id = UUID()
    let media: [MediaItem]
    let start: Int
}

struct MediaGrid: View {
    let media: [MediaItem]
    var onOpen: ((Int) -> Void)? = nil
    @EnvironmentObject var router: ServerRouter

    var body: some View {
        let items = Array(media.prefix(4))
        let n = items.count
        Group {
            if n == 1 {
                single(items[0])
            } else if n == 2 {
                HStack(spacing: 2) {
                    cell(items[0], index: 0)
                    cell(items[1], index: 1)
                }
                .frame(height: 190)
            } else if n == 3 {
                HStack(spacing: 2) {
                    cell(items[0], index: 0)
                    VStack(spacing: 2) {
                        cell(items[1], index: 1)
                        cell(items[2], index: 2)
                    }
                    .frame(width: 130)
                }
                .frame(height: 200)
            } else {
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        cell(items[0], index: 0)
                        cell(items[1], index: 1)
                    }
                    HStack(spacing: 2) {
                        cell(items[2], index: 2)
                        cell(items[3], index: 3)
                    }
                }
                .frame(height: 210)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.border, lineWidth: 0.5)
        )
    }

    private func single(_ m: MediaItem) -> some View {
        let ratio: CGFloat = (m.w > 0 && m.h > 0) ? CGFloat(m.w) / CGFloat(m.h) : 16.0 / 9.0
        return cell(m, index: 0)
            .aspectRatio(ratio, contentMode: .fit)
            .frame(maxHeight: 420)
    }

    private func cell(_ m: MediaItem, index: Int) -> some View {
        ZStack {
            Color(white: 0.07)
            RemoteImage(url: thumbURL(m), contentMode: .fill)
                .clipped()
            if m.isVideo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white.opacity(0.92))
                    .shadow(radius: 6)
                if let d = m.dur, d > 0 {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(Format.duration(d))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.75))
                                .cornerRadius(3)
                        }
                    }
                    .padding(6)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onOpen?(index) }
    }

    private func thumbURL(_ m: MediaItem) -> URL? {
        router.api?.thumbURL(m, width: 640)
    }
}
