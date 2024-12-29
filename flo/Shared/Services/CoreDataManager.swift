//
//  CoreDataManager.swift
//  flo
//
//  Created by rizaldy on 29/06/24.
//

import CoreData
import Foundation

class CoreDataManager: ObservableObject {
  static let shared = CoreDataManager()

  private init() {}

  lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "flo")  //FIXME: constants?

    container.loadPersistentStores { _, error in
      if let error {
        fatalError("Failed to load persistent stores: \(error.localizedDescription)")
      }
    }

    return container
  }()

  var viewContext: NSManagedObjectContext {
    return self.persistentContainer.viewContext
  }

  func getRecordsByEntity<T: NSManagedObject>(
    entity: T.Type, sortDescriptors: [NSSortDescriptor]? = nil
  ) -> [T] {
    let request: NSFetchRequest<T> = NSFetchRequest<T>(entityName: String(describing: T.self))

    request.sortDescriptors = sortDescriptors

    do {
      return try self.viewContext.fetch(request)
    } catch {
      return []
    }
  }

  func getRecordsByEntityBatched<T: NSManagedObject>(
    entity: T.Type, sortDescriptors: [NSSortDescriptor]? = nil,
    batchSize: Int = 100
  ) async -> [T] {
    let request: NSFetchRequest<T> = NSFetchRequest<T>(entityName: String(describing: T.self))

    request.sortDescriptors = sortDescriptors
    request.fetchBatchSize = batchSize

    return await withCheckedContinuation { continuation in
      viewContext.perform {
        do {
          let results = try self.viewContext.fetch(request)

          continuation.resume(returning: results)
        } catch {
          print("Fetch error: \(error)")

          continuation.resume(returning: [])
        }
      }
    }
  }

  func getRecordByKey<T: NSManagedObject, V>(
    entity: T.Type,
    key: KeyPath<T, V>,
    value: V?,
    limit: Int = 0,
    sortDescriptors: [NSSortDescriptor]? = nil
  ) -> [T] {
    let request: NSFetchRequest<T> = NSFetchRequest<T>(entityName: String(describing: T.self))
    let keyPathString = key._kvcKeyPathString!

    let predicate: NSPredicate

    if let identifier = value as? CVarArg {
      predicate = NSPredicate(format: "%K == %@", keyPathString, identifier)
    } else {
      predicate = NSPredicate(format: "%K == NULL", keyPathString)
    }

    request.predicate = predicate
    request.fetchLimit = limit > 0 ? limit : 0
    request.sortDescriptors = sortDescriptors

    do {
      return try self.viewContext.fetch(request)
    } catch let error {
      print(error.localizedDescription)

      return []
    }
  }

  func countRecords<T: NSManagedObject>(entity: T.Type) -> Int {
    let request: NSFetchRequest<T> = NSFetchRequest<T>(entityName: String(describing: T.self))

    request.resultType = .countResultType

    do {
      let count = try self.viewContext.count(for: request)
      return count
    } catch {
      print(error.localizedDescription)

      return 0
    }
  }

  func saveRecord() {
    do {
      try self.viewContext.save()
    } catch {
      self.viewContext.rollback()

      print(error.localizedDescription)
    }
  }

  func deleteRecords<T: NSManagedObject>(entity: T.Type) {
    let request: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest<NSFetchRequestResult>(
      entityName: String(describing: T.self))
    let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

    do {
      try self.viewContext.execute(deleteRequest)
      try self.viewContext.save()
    } catch {
      print("Failed to delete records: \(error.localizedDescription)")
    }
  }

  func deleteRecordByKey<T: NSManagedObject, V>(
    entity: T.Type,
    key: KeyPath<T, V>,
    value: V?
  ) {
    let request: NSFetchRequest<T> = NSFetchRequest<T>(entityName: String(describing: T.self))
    let keyPathString = key._kvcKeyPathString!

    let predicate: NSPredicate

    if let identifier = value as? CVarArg {
      predicate = NSPredicate(format: "%K == %@", keyPathString, identifier)
    } else {
      predicate = NSPredicate(format: "%K == NULL", keyPathString)
    }

    request.predicate = predicate

    let deleteRequest = NSBatchDeleteRequest(
      fetchRequest: request as! NSFetchRequest<NSFetchRequestResult>)

    do {
      try self.viewContext.execute(deleteRequest)
      try self.viewContext.save()
    } catch {
      print("Failed to delete records: \(error.localizedDescription)")
    }
  }

  func clearEverything() {
    let entities = ["QueueEntity", "SongEntity", "PlaylistEntity"]

    for entity in entities {
      let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
      let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

      do {
        try self.viewContext.execute(batchDeleteRequest)

        print("Successfully deleted all records for \(entity).")
      } catch {
        print("Failed to delete records for \(entity): \(error.localizedDescription)")
      }
    }

    do {
      try self.viewContext.save()
    } catch {
      print("Failed to save context: \(error.localizedDescription)")
    }
  }
}
