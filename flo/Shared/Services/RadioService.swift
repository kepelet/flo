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
}
