//    flo

import Foundation
import Combine

class RadiosViewModel: ObservableObject {
  @Published var radios: [Radio] = []
  
  @Published var isLoading = false
  @Published var error: Error?
  
  func fetchAllRadios() {
    RadioService.shared.getAllRadios { result in
      self.isLoading = true
      
      DispatchQueue.main.async {
        self.isLoading = false
        
        switch result {
        case .success(let radios):
          self.radios = radios
          
        case .failure(let error):
          self.error = error
        }
      }
    }
  }
}
