//
//  TabSelectionClampingTests.swift
//  floTests
//

import XCTest

@testable import flo

final class TabSelectionClampingTests: XCTestCase {

  // MARK: - normalizedTab

  func testNormalizedTab_keepingValidSelection() {
    let available: Set<AppTab> = [.home, .preferences, .library]
    XCTAssertEqual(normalizedTab(.library, available: available), .library)
    XCTAssertEqual(normalizedTab(.home, available: available), .home)
  }

  func testNormalizedTab_invalidFallsBackToHome() {
    let available: Set<AppTab> = [.home, .preferences]
    XCTAssertEqual(normalizedTab(.search, available: available), .home)
    XCTAssertEqual(normalizedTab(.debug, available: available), .home)
    XCTAssertEqual(normalizedTab(.downloads, available: available), .home)
  }

  func testNormalizedTab_invalidWithCustomFallback() {
    let available: Set<AppTab> = [.home, .preferences, .library]
    XCTAssertEqual(normalizedTab(.search, available: available, fallback: .preferences), .preferences)
  }

  func testNormalizedTab_fallbackNotAvailable_returnsAnyAvailable() {
    let available: Set<AppTab> = [.preferences, .library]
    // .home not in available, should return any (first) available — not crash
    let result = normalizedTab(.search, available: available, fallback: .home)
    XCTAssertTrue(available.contains(result))
  }

  func testNormalizedTab_emptyAvailable_returnsFallback() {
    let available: Set<AppTab> = []
    XCTAssertEqual(normalizedTab(.search, available: available), .home)
  }

  // MARK: - LibraryRouter clampSelection

  func testClampSelection_validNoOp() {
    let router = LibraryRouter()
    router.selectedTab = .home
    let available: Set<AppTab> = [.home, .preferences]
    router.clampSelection(to: available)
    XCTAssertEqual(router.selectedTab, .home)
  }

  func testClampSelection_invalidClampsToHome() {
    let router = LibraryRouter()
    router.selectedTab = .search
    let available: Set<AppTab> = [.home, .preferences]
    router.clampSelection(to: available)
    XCTAssertEqual(router.selectedTab, .home)
  }

  func testClampSelection_invalidClampsToFallbackWhenProvided() {
    let router = LibraryRouter()
    router.selectedTab = .debug
    let available: Set<AppTab> = [.home, .preferences, .library]
    router.clampSelection(to: available, fallback: .preferences)
    XCTAssertEqual(router.selectedTab, .preferences)
  }

  // MARK: - availableTabs: base variant

  func testAvailableTabs_baseV2On_containsLibrarySearchNoDownloadsCollections() {
    // base, loggedOut, v2 on, debug off
    let tabs = availableTabs(isPadSidebar: false, isLoggedIn: false, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertEqual(tabs, [.home, .library, .search, .preferences])
  }

  func testAvailableTabs_baseV2On_loggedIn_debugOn() {
    let tabs = availableTabs(isPadSidebar: false, isLoggedIn: true, libraryViewV2Enabled: true, isDebugEnabled: true)
    XCTAssertTrue(tabs.contains(.home))
    XCTAssertTrue(tabs.contains(.library))
    XCTAssertTrue(tabs.contains(.search))
    XCTAssertTrue(tabs.contains(.preferences))
    XCTAssertTrue(tabs.contains(.debug))
    XCTAssertFalse(tabs.contains(.downloads))
    XCTAssertFalse(tabs.contains(.libraryAlbums))
  }

  func testAvailableTabs_baseV2Off_loggedOut_containsHomeDownloadsPreferencesOnly() {
    let tabs = availableTabs(isPadSidebar: false, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertEqual(tabs, [.home, .downloads, .preferences])
  }

  func testAvailableTabs_baseV2Off_loggedIn_containsLibrary() {
    let tabs = availableTabs(isPadSidebar: false, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertTrue(tabs.contains(.library))
    XCTAssertTrue(tabs.contains(.downloads))
    XCTAssertFalse(tabs.contains(.search))
    XCTAssertFalse(tabs.contains(.libraryAlbums))
  }

  func testAvailableTabs_baseV2Off_debugOn() {
    let tabs = availableTabs(isPadSidebar: false, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: true)
    XCTAssertTrue(tabs.contains(.debug))
    XCTAssertFalse(tabs.contains(.library))
  }

  // MARK: - availableTabs: sidebar variant

  func testAvailableTabs_sidebarV2Off_loggedOut_noCollectionsNoLibraryNoSearch() {
    let tabs = availableTabs(isPadSidebar: true, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertTrue(tabs.contains(.home))
    XCTAssertTrue(tabs.contains(.preferences))
    XCTAssertTrue(tabs.contains(.downloads))
    XCTAssertFalse(tabs.contains(.library))
    XCTAssertFalse(tabs.contains(.search))
    XCTAssertFalse(tabs.contains(.libraryAlbums))
    XCTAssertFalse(tabs.contains(.libraryArtists))
    XCTAssertFalse(tabs.contains(.debug))
  }

  func testAvailableTabs_sidebarV2Off_loggedIn_hasCollectionsAndDownloadsNoSearch() {
    let tabs = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertTrue(tabs.contains(.downloads))
    XCTAssertFalse(tabs.contains(.library))
    XCTAssertFalse(tabs.contains(.search))
    XCTAssertTrue(tabs.contains(.libraryAlbums))
    XCTAssertTrue(tabs.contains(.libraryArtists))
    XCTAssertTrue(tabs.contains(.likedSongs))
    XCTAssertTrue(tabs.contains(.playlists))
    XCTAssertTrue(tabs.contains(.songs))
    XCTAssertTrue(tabs.contains(.radios))
  }

  func testAvailableTabs_sidebarV2On_loggedOut_hasLibrarySearchAndCollectionsNoDownloads() {
    let tabs = availableTabs(isPadSidebar: true, isLoggedIn: false, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertTrue(tabs.contains(.library))
    XCTAssertTrue(tabs.contains(.search))
    XCTAssertFalse(tabs.contains(.downloads))
    XCTAssertTrue(tabs.contains(.libraryAlbums))
    XCTAssertTrue(tabs.contains(.libraryArtists))
    XCTAssertTrue(tabs.contains(.likedSongs))
    XCTAssertTrue(tabs.contains(.playlists))
    XCTAssertTrue(tabs.contains(.songs))
    XCTAssertTrue(tabs.contains(.radios))
  }

  func testAvailableTabs_sidebarV2On_loggedIn_hasAllExceptDownloads() {
    let tabs = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertTrue(tabs.contains(.library))
    XCTAssertTrue(tabs.contains(.search))
    XCTAssertFalse(tabs.contains(.downloads))
    XCTAssertTrue(tabs.contains(.libraryAlbums))
    XCTAssertTrue(tabs.contains(.songs))
  }

  func testAvailableTabs_sidebar_debugOn() {
    let tabs = availableTabs(isPadSidebar: true, isLoggedIn: false, libraryViewV2Enabled: true, isDebugEnabled: true)
    XCTAssertTrue(tabs.contains(.debug))
  }

  func testAvailableTabs_sidebar_debugOff_noDebug() {
    let tabs = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertFalse(tabs.contains(.debug))
  }

  // MARK: - FLO-36 scenario matrix

  func testScenario_searchShortcut_v2Off_sidebarClampsToHome() {
    let available = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertFalse(available.contains(.search))
    XCTAssertEqual(normalizedTab(.search, available: available), .home)
  }

  func testScenario_searchShortcut_v2Off_baseClampsToHome() {
    let available = availableTabs(isPadSidebar: false, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertFalse(available.contains(.search))
    XCTAssertEqual(normalizedTab(.search, available: available), .home)
  }

  func testScenario_searchShortcut_v2On_searchIsValid() {
    let available = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertTrue(available.contains(.search))
    XCTAssertEqual(normalizedTab(.search, available: available), .search)
  }

  func testScenario_logoutWhileOnLibrary_baseV2Off_clampsToHome() {
    let before = availableTabs(isPadSidebar: false, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertTrue(before.contains(.library))
    let after = availableTabs(isPadSidebar: false, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertFalse(after.contains(.library))
    XCTAssertEqual(normalizedTab(.library, available: after), .home)
  }

  func testScenario_logoutWhileOnCollections_sidebarV2Off_clampsToHome() {
    // v2 off, logged in -> collections present, after logout -> gone
    let after = availableTabs(isPadSidebar: true, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    for tab in [AppTab.libraryAlbums, .libraryArtists, .likedSongs, .playlists, .songs, .radios] {
      XCTAssertFalse(after.contains(tab), "\(tab) should not be available after logout v2 off")
      XCTAssertEqual(normalizedTab(tab, available: after), .home)
    }
  }

  func testScenario_logoutWhileOnCollections_sidebarV2On_stillValid() {
    // With v2 ON, collections remain even after logout (isLoggedIn || v2)
    let after = availableTabs(isPadSidebar: true, isLoggedIn: false, libraryViewV2Enabled: true, isDebugEnabled: false)
    for tab in [AppTab.libraryAlbums, .libraryArtists, .likedSongs, .playlists, .songs, .radios] {
      XCTAssertTrue(after.contains(tab), "\(tab) should remain available with v2 on even after logout")
      XCTAssertEqual(normalizedTab(tab, available: after), tab)
    }
  }

  func testScenario_toggleV2OffWhileOnSearch_clampsToHome() {
    let after = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertFalse(after.contains(.search))
    XCTAssertEqual(normalizedTab(.search, available: after), .home)
  }

  func testScenario_toggleV2OffWhileOnCollectionsWithLoggedOut_clamps() {
    // Start v2 on loggedOut -> collections present; toggle v2 off -> collections vanish (since loggedOut)
    let after = availableTabs(isPadSidebar: true, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertFalse(after.contains(.libraryAlbums))
    XCTAssertEqual(normalizedTab(.libraryAlbums, available: after), .home)
  }

  func testScenario_toggleV2OffWhileOnLibrary_sidebar_clamps() {
    let after = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertFalse(after.contains(.library))
    XCTAssertEqual(normalizedTab(.library, available: after), .home)
  }

  func testScenario_debugOffWhileOnDebug_clampsToHome() {
    let baseAfter = availableTabs(isPadSidebar: false, isLoggedIn: true, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertFalse(baseAfter.contains(.debug))
    XCTAssertEqual(normalizedTab(.debug, available: baseAfter), .home)

    let sidebarAfter = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertFalse(sidebarAfter.contains(.debug))
    XCTAssertEqual(normalizedTab(.debug, available: sidebarAfter), .home)
  }

  func testScenario_debugOffWhileOnHome_staysHome() {
    let after = availableTabs(isPadSidebar: false, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertEqual(normalizedTab(.home, available: after), .home)
  }

  func testScenario_downloadsInvalidWhenV2On_clamps() {
    let sidebarV2On = availableTabs(isPadSidebar: true, isLoggedIn: true, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertFalse(sidebarV2On.contains(.downloads))
    XCTAssertEqual(normalizedTab(.downloads, available: sidebarV2On), .home)

    let baseV2On = availableTabs(isPadSidebar: false, isLoggedIn: true, libraryViewV2Enabled: true, isDebugEnabled: false)
    XCTAssertFalse(baseV2On.contains(.downloads))
    XCTAssertEqual(normalizedTab(.downloads, available: baseV2On), .home)
  }

  func testScenario_downloadsValidWhenV2Off() {
    let sidebarV2Off = availableTabs(isPadSidebar: true, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertTrue(sidebarV2Off.contains(.downloads))
    XCTAssertEqual(normalizedTab(.downloads, available: sidebarV2Off), .downloads)

    let baseV2Off = availableTabs(isPadSidebar: false, isLoggedIn: false, libraryViewV2Enabled: false, isDebugEnabled: false)
    XCTAssertTrue(baseV2Off.contains(.downloads))
    XCTAssertEqual(normalizedTab(.downloads, available: baseV2Off), .downloads)
  }

  // MARK: - clampedSelectionValue (render-time binding getter)

  func testClampedSelectionValue_keepsValidSelection() {
    let available: Set<AppTab> = [.home, .preferences, .search]
    XCTAssertEqual(clampedSelectionValue(.home, available: available), .home)
    XCTAssertEqual(clampedSelectionValue(.search, available: available), .search)
  }

  func testClampedSelectionValue_invalidFallsBack() {
    let available: Set<AppTab> = [.home, .preferences]
    XCTAssertEqual(clampedSelectionValue(.search, available: available), .home)
    XCTAssertEqual(clampedSelectionValue(.debug, available: available), .home)
    XCTAssertEqual(clampedSelectionValue(.libraryAlbums, available: available), .home)
  }

  func testClampedSelectionValue_exhaustiveMatrixNeverDangles() {
    // Every tab × every flag combo: the binding getter must always return a
    // tab the active TabView variant actually renders (FLO-36 render-time clamp).
    let allTabs: [AppTab] = [
      .home, .library, .libraryAlbums, .libraryArtists, .likedSongs,
      .playlists, .songs, .radios, .downloads, .preferences, .debug, .search
    ]
    for isSidebar in [false, true] {
      for isLoggedIn in [false, true] {
        for v2 in [false, true] {
          for debug in [false, true] {
            let tabs = availableTabs(
              isPadSidebar: isSidebar, isLoggedIn: isLoggedIn,
              libraryViewV2Enabled: v2, isDebugEnabled: debug)
            for tab in allTabs {
              let result = clampedSelectionValue(tab, available: tabs)
              XCTAssertTrue(
                tabs.contains(result),
                "dangling binding value \(result) for selected=\(tab) " +
                "sidebar=\(isSidebar) loggedIn=\(isLoggedIn) v2=\(v2) debug=\(debug)")
            }
          }
        }
      }
    }
  }

  func testClampedSelectionValue_v2OffSearchNeverSurvives() {
    // Cmd+F / UITest hook must never surface .search when v2 is off, either variant.
    for isSidebar in [false, true] {
      let tabs = availableTabs(
        isPadSidebar: isSidebar, isLoggedIn: true,
        libraryViewV2Enabled: false, isDebugEnabled: false)
      XCTAssertFalse(tabs.contains(.search))
      XCTAssertEqual(clampedSelectionValue(.search, available: tabs), .home)
    }
  }

  func testClampedSelectionValue_loggedOutCollectionsNeverSurviveV2Off() {
    // Logout while on a Collections tab (v2 off, sidebar): binding must clamp.
    let tabs = availableTabs(
      isPadSidebar: true, isLoggedIn: false,
      libraryViewV2Enabled: false, isDebugEnabled: false)
    for tab in [AppTab.libraryAlbums, .libraryArtists, .likedSongs, .playlists, .songs, .radios] {
      XCTAssertFalse(tabs.contains(tab))
      XCTAssertEqual(clampedSelectionValue(tab, available: tabs), .home)
    }
  }

  // MARK: - exhaustive debug toggle matrix

  func testMatrix_v2TogglesCoverAllCollectionsAndSearch() {
    // Ensure every collection + search is only valid when expected
    for isSidebar in [true, false] {
      for isLoggedIn in [true, false] {
        for v2 in [true, false] {
          let tabs = availableTabs(isPadSidebar: isSidebar, isLoggedIn: isLoggedIn, libraryViewV2Enabled: v2, isDebugEnabled: false)
          let expectSearch = v2 // search only when v2 on in both variants
          XCTAssertEqual(tabs.contains(.search), expectSearch, "search isSidebar=\(isSidebar) loggedIn=\(isLoggedIn) v2=\(v2)")
          let expectCollections = isSidebar && (isLoggedIn || v2)
          for c in [AppTab.libraryAlbums, .libraryArtists, .likedSongs, .playlists, .songs, .radios] {
            XCTAssertEqual(tabs.contains(c), expectCollections, "\(c) isSidebar=\(isSidebar) loggedIn=\(isLoggedIn) v2=\(v2)")
          }
          let expectDownloads = !v2
          XCTAssertEqual(tabs.contains(.downloads), expectDownloads, "downloads isSidebar=\(isSidebar) v2=\(v2)")
          let expectLibrary: Bool
          if isSidebar {
            expectLibrary = v2
          } else {
            expectLibrary = v2 || isLoggedIn
          }
          XCTAssertEqual(tabs.contains(.library), expectLibrary, "library isSidebar=\(isSidebar) loggedIn=\(isLoggedIn) v2=\(v2)")
        }
      }
    }
  }
}
