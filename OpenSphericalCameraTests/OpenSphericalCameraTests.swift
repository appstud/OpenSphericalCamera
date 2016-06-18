//
//  OpenSphericalCameraTests.swift
//  OpenSphericalCameraTests
//
//  Created by Tatsuhiko Arai on 6/3/16.
//  Copyright © 2016 Tatsuhiko Arai. All rights reserved.
//

import XCTest
@testable import OpenSphericalCamera

class OpenSphericalCameraTests: XCTestCase {
    var osc: OpenSphericalCamera!

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.osc = OpenSphericalCamera.sharedCamera(ipAddress: "192.168.1.1", httpPort: 80)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func startSession() -> String {
        var sessionId: String?

        let semaphore = dispatch_semaphore_create(0)
        self.osc.startSession { (data, response, error) in
            XCTAssert(data != nil && data!.length > 0)
            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            XCTAssert(jsonDic != nil && jsonDic!.count > 0)

            let name = jsonDic!["name"] as? String
            XCTAssert(name != nil && name! == "camera.startSession")

            let state = jsonDic!["state"] as? String
            XCTAssert(state != nil && state! == "done")

            let results = jsonDic!["results"] as? NSDictionary
            XCTAssert(results != nil && results!.count > 0)

            sessionId = results!["sessionId"] as? String
            XCTAssert(sessionId != nil && !sessionId!.isEmpty)

            dispatch_semaphore_signal(semaphore)
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        return sessionId!
    }

    func closeSession(sessionId: String) {
        let semaphore = dispatch_semaphore_create(0)
        self.osc.closeSession(sessionId: sessionId) {
            (data, response, error) in
            XCTAssert(data != nil && data!.length > 0)
            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            XCTAssert(jsonDic != nil && jsonDic!.count > 0)

            let name = jsonDic!["name"] as? String
            XCTAssert(name != nil && name! == "camera.closeSession")

            let state = jsonDic!["state"] as? String
            XCTAssert(state != nil && state! == "done")

            dispatch_semaphore_signal(semaphore)
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    }

    func testInfo() {
        XCTAssert(osc.httpUpdatesPort != 0)

        XCTAssertFalse(osc.info.manufacturer.isEmpty)
        XCTAssertFalse(osc.info.model.isEmpty)
        XCTAssertFalse(osc.info.serialNumber.isEmpty)
        XCTAssertFalse(osc.info.firmwareVersion.isEmpty)
        XCTAssertFalse(osc.info.supportUrl.isEmpty)
        XCTAssert(osc.info.endpoints.httpPort != 0)
        XCTAssert(osc.info.endpoints.httpUpdatesPort != 0)
        XCTAssert(osc.info.uptime != 0)
        XCTAssertFalse(osc.info.api.isEmpty)
    }

    func testStateAndCheckForUpdates() {
        var fingerprint: String?

        // state
        var semaphore = dispatch_semaphore_create(0)
        self.osc.state { (data, response, error) in
            XCTAssert(data != nil && data!.length > 0)
            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            XCTAssert(jsonDic != nil && jsonDic!.count > 0)

            fingerprint = jsonDic!["fingerprint"] as? String
            XCTAssert(fingerprint != nil && !fingerprint!.isEmpty)

            let state = jsonDic!["state"] as? NSDictionary
            XCTAssert(state != nil && state!.count > 0)

            let sessionId = state!["sessionId"] as? String
            XCTAssert(sessionId != nil && !sessionId!.isEmpty)

            let batteryLevel = state!["batteryLevel"] as? Double
            XCTAssert(batteryLevel != nil && [0.0, 0.33, 0.67, 1.0].contains(batteryLevel!))

            let storageChanged = state!["storageChanged"] as? Bool
            XCTAssertNotNil(storageChanged)

            dispatch_semaphore_signal(semaphore)
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        // checkForUpdates
        semaphore = dispatch_semaphore_create(0)
        self.osc.checkForUpdates(stateFingerprint: fingerprint!) { (data, response, error) in
            XCTAssert(data != nil && data!.length > 0)
            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            XCTAssert(jsonDic != nil && jsonDic!.count > 0)

            let fingerprint = jsonDic!["stateFingerprint"] as? String
            XCTAssert(fingerprint != nil && !fingerprint!.isEmpty)

            dispatch_semaphore_signal(semaphore)
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
    }

    func testTakePictureAndGetImageAndDelete() {

        // startSession
        let sessionId = startSession()

        // takePicture (uses Execute and Status commands)
        let semaphore = dispatch_semaphore_create(0)
        var completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)!
        completionHandler = { (data, response, error) in
            XCTAssert(data != nil && data!.length > 0)
            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            XCTAssert(jsonDic != nil && jsonDic!.count > 0)

            let name = jsonDic!["name"] as? String
            XCTAssert(name != nil && name! == "camera.takePicture")

            let state = jsonDic!["state"] as? String
            XCTAssert(state != nil && state! == "done")

            let results = jsonDic!["results"] as? NSDictionary
            XCTAssert(results != nil && results!.count > 0)

            let fileUri = results!["fileUri"] as? String
            XCTAssert(fileUri != nil && !fileUri!.isEmpty)

            // getImage
            self.osc.getImage(fileUri: fileUri!) { (data, response, error) in
                XCTAssert(data != nil && data!.length > 0)
                XCTAssertNotNil(UIImage(data: data!))

                // delete
                self.osc.delete(fileUri: fileUri!) { (data, response, error) in
                    XCTAssert(data != nil && data!.length > 0)
                    let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
                    XCTAssert(jsonDic != nil && jsonDic!.count > 0)

                    let name = jsonDic!["name"] as? String
                    XCTAssert(name != nil && name! == "camera.delete")

                    let state = jsonDic!["state"] as? String
                    XCTAssert(state != nil && state! == "done")

                    dispatch_semaphore_signal(semaphore)
                }

            }
        }
        self.osc.takePicture(sessionId: sessionId, completionHandler: completionHandler)
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        // closeSession
        closeSession(sessionId)
    }

    func testListImagesAndGetMetadata() {

        // startSession
        let sessionId = startSession()

        // listImages
        let semaphore = dispatch_semaphore_create(0)
        var completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)!
        completionHandler = { (data, response, error) in
            XCTAssert(data != nil && data!.length > 0)
            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            XCTAssert(jsonDic != nil && jsonDic!.count > 0)

            let name = jsonDic!["name"] as? String
            XCTAssert(name != nil && name! == "camera.listImages")

            let state = jsonDic!["state"] as? String
            XCTAssert(state != nil && state! == "done")

            let results = jsonDic!["results"] as? NSDictionary
            XCTAssert(results != nil && results!.count > 0)

            let entries = results!["entries"] as? [NSDictionary]
            XCTAssert(entries != nil && entries!.count > 0)

            let uri = entries![0]["uri"] as? String
            XCTAssert(uri != nil && !uri!.isEmpty)

            let totalEntries = results!["totalEntries"] as? Int
            XCTAssert(totalEntries != nil)

            // getMetadata
            self.osc.getMetadata(fileUri: uri!) { (data, response, error) in
                XCTAssert(data != nil && data!.length > 0)
                let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
                XCTAssert(jsonDic != nil && jsonDic!.count > 0)

                let name = jsonDic!["name"] as? String
                XCTAssert(name != nil && name! == "camera.getMetadata")
                
                let state = jsonDic!["state"] as? String
                XCTAssert(state != nil && state! == "done")

                let results = jsonDic!["results"] as? NSDictionary
                XCTAssert(results != nil && results!.count > 0)

                let exif = results!["exif"] as? NSDictionary
                XCTAssert(exif != nil && exif!.count > 0)

                let ExifVersion = exif!["ExifVersion"] as? String
                XCTAssert(ExifVersion != nil && !ExifVersion!.isEmpty)

                let xmp = results!["xmp"] as? NSDictionary
                XCTAssert(xmp != nil && xmp!.count > 0)

                let ProjectionType = xmp!["ProjectionType"] as? String
                XCTAssert(ProjectionType != nil && ProjectionType == "equirectangular")

                dispatch_semaphore_signal(semaphore)
            }
        }
        self.osc.listImages(entryCount: 3, includeThumb: false, completionHandler: completionHandler)
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        // closeSession
        closeSession(sessionId)
    }

    func testGetAndSetOptions() {

        // startSession
        let sessionId = startSession()

        // getOptions
        let semaphore = dispatch_semaphore_create(0)
        self.osc.getOptions(sessionId: sessionId, optionNames: ["exposureProgram", "exposureProgramSupport"]) {
            (data, response, error) in
            XCTAssert(data != nil && data!.length > 0)
            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            XCTAssert(jsonDic != nil && jsonDic!.count > 0)

            let name = jsonDic!["name"] as? String
            XCTAssert(name != nil && name! == "camera.getOptions")

            let state = jsonDic!["state"] as? String
            XCTAssert(state != nil && state! == "done")

            let results = jsonDic!["results"] as? NSDictionary
            XCTAssert(results != nil && results!.count > 0)

            let options = results!["options"] as? NSDictionary
            XCTAssert(options != nil && options!.count == 2)

            let exposureProgram = options!["exposureProgram"] as? Int
            XCTAssert(exposureProgram != nil)

            let exposureProgramSupport = options!["exposureProgramSupport"] as? [Int]
            XCTAssert(exposureProgramSupport != nil && exposureProgramSupport!.contains(exposureProgram!))

            // setOptions
            self.osc.setOptions(sessionId: sessionId, options: ["exposureProgram": exposureProgram!]) { (data, response, error) in
                XCTAssert(data != nil && data!.length > 0)
                let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
                XCTAssert(jsonDic != nil && jsonDic!.count > 0)

                let name = jsonDic!["name"] as? String
                XCTAssert(name != nil && name! == "camera.setOptions")

                let state = jsonDic!["state"] as? String
                XCTAssert(state != nil && state! == "done")

                dispatch_semaphore_signal(semaphore)
            }
        }
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        // closeSession
        closeSession(sessionId)
    }
}
