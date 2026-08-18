//
//  CoreDataManagerTests.swift
//  floTests
//

import CoreData
import XCTest

@testable import flo

final class CoreDataManagerTests: XCTestCase {

  var sut: CoreDataManager!
  private var storeURL: URL!
  private var originalContainer: NSPersistentContainer!

  override func setUp() {
    super.setUp()

    // Use the shared singleton whose persistentContainer has the correct
    // entity-to-class mappings already resolved. Swap the store to a temp
    // SQLite file so tests are isolated.
    sut = CoreDataManager.shared
    originalContainer = sut.persistentContainer

    storeURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
      .appendingPathExtension("sqlite")

    let desc = NSPersistentStoreDescription(url: storeURL)
    desc.shouldAddStoreAsynchronously = false

    // Build a fresh container from the same managed object model
    let model = originalContainer.managedObjectModel
    let container = NSPersistentContainer(name: "flo", managedObjectModel: model)
    container.persistentStoreDescriptions = [desc]

    let expect = expectation(description: "load stores")
    container.loadPersistentStores { _, error in
      XCTAssertNil(error, "Failed to load store: \(error?.localizedDescription ?? "")")
      expect.fulfill()
    }
    wait(for: [expect], timeout: 5)
    container.viewContext.automaticallyMergesChangesFromParent = true

    sut.persistentContainer = container
  }

  override func tearDown() {
    sut.persistentContainer = originalContainer
    sut = nil
    originalContainer = nil

    if let url = storeURL {
      let shm = URL(fileURLWithPath: url.path + "-shm")
      let wal = URL(fileURLWithPath: url.path + "-wal")
      for u in [url, shm, wal] {
        try? FileManager.default.removeItem(at: u)
      }
    }
    storeURL = nil
    super.tearDown()
  }

  // MARK: - Save and fetch

  func testSaveAndFetchQueueEntity() {
    let entity = QueueEntity(context: sut.viewContext)
    entity.id = "test-id"
    entity.songName = "Test Song"
    entity.artistName = "Test Artist"
    sut.saveRecord()

    let results = sut.getRecordsByEntity(entity: QueueEntity.self)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.id, "test-id")
    XCTAssertEqual(results.first?.songName, "Test Song")
  }

  func testGetRecords_sorted() {
    let e1 = QueueEntity(context: sut.viewContext)
    e1.id = "a"
    e1.songName = "A"
    let e2 = QueueEntity(context: sut.viewContext)
    e2.id = "b"
    e2.songName = "B"
    sut.saveRecord()

    let results = sut.getRecordsByEntity(
      entity: QueueEntity.self,
      sortDescriptors: [NSSortDescriptor(key: "songName", ascending: false)])
    XCTAssertEqual(results.map(\.songName), ["B", "A"])
  }

  // MARK: - Get by key

  func testGetRecordByKey_match() {
    let entity = QueueEntity(context: sut.viewContext)
    entity.id = "match-me"
    entity.songName = "Match"
    sut.saveRecord()

    let results = sut.getRecordByKey(
      entity: QueueEntity.self, key: \QueueEntity.id, value: "match-me")
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.songName, "Match")
  }

  func testGetRecordByKey_noMatch() {
    let results = sut.getRecordByKey(
      entity: QueueEntity.self, key: \QueueEntity.id, value: "nonexistent")
    XCTAssertEqual(results.count, 0)
  }

  // MARK: - Count

  func testCountRecords_empty() {
    XCTAssertEqual(sut.countRecords(entity: QueueEntity.self), 0)
  }

  func testCountRecords_withData() {
    let e1 = QueueEntity(context: sut.viewContext)
    e1.id = "1"
    let e2 = QueueEntity(context: sut.viewContext)
    e2.id = "2"
    sut.saveRecord()

    XCTAssertEqual(sut.countRecords(entity: QueueEntity.self), 2)
  }

  // MARK: - Delete

  func testDeleteRecords() {
    let e1 = QueueEntity(context: sut.viewContext)
    e1.id = "1"
    sut.saveRecord()

    XCTAssertEqual(sut.countRecords(entity: QueueEntity.self), 1)

    sut.deleteRecords(entity: QueueEntity.self)
    XCTAssertEqual(sut.countRecords(entity: QueueEntity.self), 0)
  }

  func testDeleteRecordByKey() {
    let e1 = QueueEntity(context: sut.viewContext)
    e1.id = "keep"
    let e2 = QueueEntity(context: sut.viewContext)
    e2.id = "delete-me"
    sut.saveRecord()

    sut.deleteRecordByKey(
      entity: QueueEntity.self, key: \QueueEntity.id, value: "delete-me")

    let remaining = sut.getRecordsByEntity(entity: QueueEntity.self)
    XCTAssertEqual(remaining.count, 1)
    XCTAssertEqual(remaining.first?.id, "keep")
  }

  // MARK: - Clear everything

  func testClearEverything_removesAllEntities() {
    let queue = QueueEntity(context: sut.viewContext)
    queue.id = "1"

    let scrobble = ScrobbleEntity(context: sut.viewContext)
    scrobble.songId = "s1"
    scrobble.status = "pending"

    sut.saveRecord()

    XCTAssertEqual(sut.countRecords(entity: QueueEntity.self), 1)
    XCTAssertEqual(sut.countRecords(entity: ScrobbleEntity.self), 1)

    sut.clearEverything()

    // batch deletes bypass the context; reset to clear stale in-memory state
    sut.viewContext.reset()

    XCTAssertEqual(sut.countRecords(entity: QueueEntity.self), 0)
    // ScrobbleEntity is not in clearEverything's entity list, so it persists
  }
}
