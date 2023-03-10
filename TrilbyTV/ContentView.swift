//
//  ContentView.swift
//  TrilbyTV
//
//  Created by Andres Felipe Alzate Restrepo on 10/3/23.
//

import UIKit
import SwiftUI
import Combine

// MARK: - VIEW
struct ContentView: View {
    @ObservedObject var trilbyViewModel = TrilbyViewModel()

    var body: some View {
        VStack {
            if let images  = trilbyViewModel.items?.images {
                List(images, id: \.name) { image in
                    VStack(alignment: .leading) {
                        Text(image.name)
                            .font(.headline)
                        ImageURL(
                            url: image.imageUrl,
                            placeHolder: UIImage(systemName: "person.fill")
                        )
                        .cornerRadius(16)
                        .padding(16)
                    }
                }
            } else {
                Text("Unfortunately the content is not able yet")
            }
        }
        .onAppear { trilbyViewModel.fetchImage() }
    }
}
// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
// MARK: - ViewModel
class TrilbyViewModel: ObservableObject {
    @Published var items: ImageList?
    private var repository = ContainerDI.shared.trilbyRepository
    private var cancellables: [AnyCancellable] = []

    func fetchImage() {
        repository.fetchImages()
            .compactMap {
                guard case let .success(value) = $0 else { return nil }
                return value
            }
            .sink { [weak self] in self?.items = $0 }
            .store(in: &cancellables)
    }
}
// MARK: - ContainerDI
class ContainerDI {
    static var shared: ContainerDI = .init()
    private init(){}
    lazy var trilbyRepository = TrilbyRepository(
        trilbyApiService: trilbyApiService
    )
    private lazy var trilbyApiService = TrilbyApiService()
}
// MARK: - Repository
class TrilbyRepository {
    private let trilbyApiService: TrilbyApiService
    init(trilbyApiService: TrilbyApiService) {
        self.trilbyApiService = trilbyApiService
    }
    func fetchImages() -> AnyPublisher<Result<ImageList, Error>, Never> {
        trilbyApiService.fetchImages()
            .compactMap(ImageList.init)
            .map(Result.success)
            .catch { Just(.failure($0)) }
            .eraseToAnyPublisher()
    }
}
// MARK: - Mapping responses
extension ImageList {
    init?(response: ImageListResponse) {
        guard let images = response.images?.compactMap(ImageItem.init)
        else { assertionFailure("Object decoding failure"); return nil }
        self.images = images
    }
}
extension ImageItem {
    init?(response: ImageItemResponse) {
        guard let name = response.name, let imageUrl = response.imageUrl
        else { assertionFailure("Object decoding failure"); return nil }
        self.init(
            name: name,
            imageUrl: imageUrl
        )
    }
}
// MARK: - ApiService
class TrilbyApiService {
    func fetchImages() -> AnyPublisher<ImageListResponse, Error> {
        Just(URL.harcodeInfo).compactMap { $0 }
            .flatMap(URLSession.shared.dataTaskPublisher)
            .map(\.data)
            .decode(type: ImageListResponse.self, decoder: JSONDecoder())
            .mapError { NSError(domain: $0.localizedDescription, code: -1) }
            .eraseToAnyPublisher()
    }
}
// MARK: - ImageLoader for SwiftUI
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var cancellable: AnyCancellable?

    func load(url: URL?, placeHolder: UIImage) {
        guard let imageURL = url else { return }
        cancellable = URLSession.shared.dataTaskPublisher(for: imageURL)
            .map(\.data)
            .compactMap(UIImage.init)
            .replaceError(with: placeHolder)
            .assign(to: \.image, on: self)
    }
}
struct ImageURL: View {
    @ObservedObject private var imageLoader = ImageLoader()
    private var placeHolder: UIImage
    @State private var opacity: Double = 0

    init(url: URL?, placeHolder: UIImage?) {
        self.placeHolder = placeHolder ?? .init()
        imageLoader.load(url: url, placeHolder: self.placeHolder)
    }

    var body: some View {
        Image(uiImage: imageLoader.image ?? placeHolder)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .opacity(opacity)
            .onAppear { withAnimation(.easeOut(duration: 2)) { opacity = 1 } }
    }
}
// MARK: - Entity
struct ImageList {
    let images: [ImageItem]
}
struct ImageItem {
    let name: String
    let imageUrl: URL
}
// MARK: - Response
struct ImageListResponse: Decodable {
    let images: [ImageItemResponse]?
}
struct ImageItemResponse: Decodable {
    let name: String?
    let imageUrl: URL?

    enum CodingKeys: String, CodingKey {
        case name
        case imageUrl = "imageurl"
    }
}
// MARK: - External information
extension URL {
    static var harcodeInfo: URL? { URL(string: "https://trilbytvcdn.blob.core.windows.net/jobs/2023-03-swift-developer/images.json") }
}
