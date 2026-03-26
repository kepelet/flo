//
//  AuthMode.swift
//  flo
//
//  Created by piekay on 08/03/26.
//

import Foundation

enum AuthMode: String, Codable {
  case standard
  case iap
}

struct IAPAuthInfo: Codable {
  let jwtAssertion: String
  let userEmail: String?
  let userId: String?
  
  init(jwtAssertion: String, userEmail: String? = nil, userId: String? = nil) {
    self.jwtAssertion = jwtAssertion
    self.userEmail = userEmail
    self.userId = userId
  }
}
