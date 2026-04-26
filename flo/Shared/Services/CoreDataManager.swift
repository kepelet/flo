//
//  CoreDataManager.swift
//  flo
//
//  Created by rizaldy on 29/06/24.
//

@preconcurrency import CoreData
import Foundation

class CoreDataManager: ObservableObject {
  static let shared = CoreDataManager()

  private init() {}

  private static func inMemoryContainer() -> NSPersistentContainer {
    let container = NSPersistentContainer(name: "flo")
    let description = NSPersistentStoreDescription()

    description.type = NSInMemoryStoreType
    description.shouldAddStoreAsynchronously = false

    container.persistentStoreDescriptions = [description]
    container.loadPersistentStores { _, error in
      if let error {
        print("Failed to create in-memory store: \(error.localizedDescription)")
      }
    }

    container.viewContext.automaticallyMergesChangesFromParent = true

    return container
  }

  lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "flo")  //FIXME: constants?
    container.persistentStoreDescriptions.forEach { $0.shouldAddStoreAsynchronously = false }

    var loadError: Error?

    container.loadPersistentStores { _, error in
      if let error {
        loadError = error
      }
    }

    if let loadError {
      print("failed to load persistent stores: \(loadError.localizedDescription)")

      return Self.inMemoryContainer()
    }

    container.viewContext.automaticallyMergesChangesFromParent = true

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

    let context = self.viewContext

    return await withCheckedContinuation { continuation in
      context.perform {
        do {
          let results = try context.fetch(request)

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

    guard let keyPathString = key._kvcKeyPathString else {
      return []
    }

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
    guard let keyPathString = key._kvcKeyPathString else {
      return
    }

    let predicate: NSPredicate

    if let identifier = value as? CVarArg {
      predicate = NSPredicate(format: "%K == %@", keyPathString, identifier)
    } else {
      predicate = NSPredicate(format: "%K == NULL", keyPathString)
    }

    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: T.self))
    fetchRequest.predicate = predicate

    let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

    do {
      try self.viewContext.execute(deleteRequest)
      try self.viewContext.save()
    } catch {
      print("Failed to delete records: \(error.localizedDescription)")
    }
  }

  func clearEverything() {
    let entities = ["QueueEntity", "SongEntity", "PlaylistEntity", "CacheEntity"]

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
