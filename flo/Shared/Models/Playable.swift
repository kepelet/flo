//
//  Playable.swift
//  flo
//
//  Created by rizaldy on 16/11/24.
//

protocol Playable {
  var id: String { get }
  var name: String { get }
  var songs: [Song] { get set }
  var artist: String { get }
}
