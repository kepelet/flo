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

  func getRecordsByEntity<T: NSManagedObject>(entity: T.Type) -> [T] {
    let request: NSFetchRequest<T> = NSFetchRequest<T>(entityName: String(describing: T.self))

    do {
      return try self.viewContext.fetch(request)
    } catch {
      return []
    }
  }

  func getRecordByKey<T: NSManagedObject, V>(
    entity: T.Type,
    key: KeyPath<T, V>,
    value: V?,
    limit: Int = 0
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
}
