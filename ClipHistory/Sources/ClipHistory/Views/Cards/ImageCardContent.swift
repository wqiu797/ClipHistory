import SwiftUI

struct ImageCardContent: View {
    let thumbnailFileName: String?

    var body: some View {
        Group {
            if let fileName = thumbnailFileName,
               let nsImage = ImageStore.shared.loadThumbnail(fileName: fileName)
            {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 60, maxHeight: 60)
                    .cornerRadius(4)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .frame(width: 60, height: 60)
            }
        }
    }
}
