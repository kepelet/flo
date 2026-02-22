//    flo

import Foundation
import Alamofire

class RadioService {
  static let shared = RadioService()
  
  func getStreamUrl(radio: Radio) -> String {
    radio.streamUrl
  }

  func getAllRadios(completion: @escaping (Result<[Radio], Error>) -> Void) {

    APIManager.shared.SubsonicEndpointRequest(endpoint: API.SubsonicEndpoint.radios, parameters: nil) {
      (response: DataResponse<RadioListResponse, AFError>) in
      switch response.result {
      case .success(let radios):
        completion(.success(radios.radioStations))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  func getSimilarSongs(id: String, count: Int = 100, completion: @escaping (Result<[Song], Error>) -> Void) {
    let params: [String: Any] = ["id": id, "count": count]

    APIManager.shared.SubsonicEndpointRequest(endpoint: API.SubsonicEndpoint.similarSongs, parameters: params) {
      (response: DataResponse<SimilarSongsResponse, AFError>) in
      switch response.result {
      case .success(let result):
        completion(.success(result.songs))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
  
  func getTopSongs(artistName: String, count: Int = 20, completion: @escaping (Result<[Song], Error>) -> Void) {
    let params: [String: Any] = ["artist": artistName, "count": count]
    
    APIManager.shared.SubsonicEndpointRequest(endpoint: API.SubsonicEndpoint.topSongs, parameters: params) {
      (response: DataResponse<TopSongsResponse, AFError>) in
      switch response.result {
      case .success(let result):
        completion(.success(result.songs))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
}
