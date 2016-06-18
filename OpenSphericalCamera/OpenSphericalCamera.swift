//
//  OpenSphericalCamera.swift
//  ThetaCameraSample
//
//  Created by Tatsuhiko Arai on 5/29/16.
//  Copyright © 2016 Tatsuhiko Arai. All rights reserved.
//

import Foundation

public protocol OSCBase: class {
    var task: NSURLSessionDataTask? { get set }
    var taskState: NSURLSessionTaskState? { get }
    var urlSession: NSURLSession? { get set }
    var ipAddress: String! { get set }
    var httpPort: Int! { get set }
    var httpUpdatesPort: Int! { get }
    var info: OSCInfo! { get }

    func cancel()
}

public protocol OSCProtocol: class, OSCBase {
    func info(completionHandler completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func state(completionHandler completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func checkForUpdates(stateFingerprint stateFingerprint: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func execute(name: String, parameters: [String: AnyObject]?, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)?)
    func execute(name: String, parameters: [String: AnyObject]?, delegate: NSURLSessionDelegate)
    func getWaitDoneHandler(completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)?) -> (NSData?, NSURLResponse?, NSError?) -> Void
    func status(id id: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
}

public protocol OSCCameraCommand: class, OSCProtocol {
    func startSession(completionHandler completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func updateSession(sessionId sessionId: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func closeSession(sessionId sessionId: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)?)
    func takePicture(sessionId sessionId: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)?)
    func listImages(entryCount entryCount: Int, maxSize: Int?, continuationToken: String?, includeThumb: Bool?, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func delete(fileUri fileUri: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)?)
    func getImage(fileUri fileUri: String, maxSize: Int?, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func getMetadata(fileUri fileUri: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func getOptions(sessionId sessionId: String, optionNames: [String], completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
    func setOptions(sessionId sessionId: String, options: [String: AnyObject], completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void))
}

public struct OSCEndpoints {
    var httpPort: Int = 0
    var httpUpdatesPort: Int = 0
}

public struct OSCInfo {
    var manufacturer: String = ""
    var model: String = ""
    var serialNumber: String = ""
    var firmwareVersion: String = ""
    var supportUrl: String = ""
    var endpoints: OSCEndpoints = OSCEndpoints()
    var gps: Bool = false
    var gyro: Bool = false
    var uptime: Int = 0
    var api: [String] = []
}

public enum OSCCommandState: String {
    case InProgress = "inProgress"
    case Done = "done"
    case Error = "error"
}

public enum OSCErrorCode {
    case unknownCommand	// 400 Invalid command is issued
    case disabledCommand	// 403 Command cannot be executed due to the camera status
    case missingParameter	// 400 Insufficient required parameters to issue the command
    case invalidParameterName	// 400 Parameter name or option name is invalid
    case invalidSessionId	// 403 sessionID when command was issued is invalid
    case invalidParameterValue	// 400 Parameter value when command was issued is invalid
    case corruptedFile	// 403 Process request for corrupted file
    case cameraInExclusiveUse	// 400 Session start not possible when camera is in exclusive use
    case powerOffSequenceRunning	// 403 Process request when power supply is off
    case invalidFileFormat	// 403 Invalid file format specified
    case serviceUnavailable	// 503 Processing requests cannot be received temporarily
    case canceledShooting	// 403 Shooting request cancellation of the self-timer. Returned in Commands/Status of camera.takePicture (Firmware version 01.42 or above)
    case unexpected	// 503 Other errors
}

public class OpenSphericalCamera: OSCCameraCommand {
    public var task: NSURLSessionDataTask?
    public var taskState: NSURLSessionTaskState? {
        if let task = self.task {
            return task.state
        }
        return nil
    }
    public var urlSession: NSURLSession? = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())

    public var ipAddress: String!
    public var httpPort: Int!
    public lazy var httpUpdatesPort: Int! = {
        return self.info.endpoints.httpUpdatesPort
    }()

    lazy public var info: OSCInfo! = {
        var info = OSCInfo()

        let semaphore = dispatch_semaphore_create(0)

        self.info { (data, response, error) in
            if let data = data where error == nil {
                if let jsonDic = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary {
                    info.manufacturer = (jsonDic["manufacturer"] as? String) ?? ""
                    info.model = (jsonDic["model"] as? String) ?? ""
                    info.serialNumber = (jsonDic["serialNumber"] as? String) ?? ""
                    info.firmwareVersion = (jsonDic["firmwareVersion"] as? String) ?? ""
                    info.supportUrl = (jsonDic["supportUrl"] as? String) ?? ""
                    if let endpoints = jsonDic["endpoints"] as? NSDictionary {
                        info.endpoints.httpPort = (endpoints["httpPort"] as? Int) ?? 0
                        info.endpoints.httpUpdatesPort = (endpoints["httpUpdatesPort"] as? Int) ?? 0
                    }
                    info.gps = (jsonDic["gps"] as? Bool) ?? false
                    info.gyro = (jsonDic["gyro"] as? Bool) ?? false
                    info.uptime = (jsonDic["uptime"] as? Int) ?? 0
                    info.api = (jsonDic["api"] as? [String]) ?? []
                }
            }

            dispatch_semaphore_signal(semaphore)
        }

        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)

        return info
    }()

    public init(ipAddress: String, httpPort: Int) {
        self.ipAddress = ipAddress
        self.httpPort  = httpPort
    }

    deinit {
        self.cancel()
    }

}

public extension OSCCameraCommand {

    // MARK: OSCBase Methods

    public func cancel() {
        if let task = self.task {
            switch task.state {
            case .Running:
                fallthrough
            case .Suspended:
                task.cancel()
            // case .Canceling:
            // case .Completed:
            default:
                break
            }
        }
    }

    // MARK: - OSCProtocol Methods

    public func info(completionHandler completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.cancel()

        let url = NSURL(string: "http://\(ipAddress):\(httpPort)/osc/info")!
        let request = NSURLRequest(URL: url)
        self.task = self.urlSession!.dataTaskWithRequest(request) { (data, response, error) in
            completionHandler(data, response, error)
        }
        self.task!.resume()
    }

    public func state(completionHandler completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.cancel()

        let url = NSURL(string: "http://\(ipAddress):\(httpPort)/osc/state")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        self.task = self.urlSession!.dataTaskWithRequest(request) { (data, response, error) in
            completionHandler(data, response, error)
        }
        self.task!.resume()
    }

    public func checkForUpdates(stateFingerprint stateFingerprint: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.cancel()

        let url = NSURL(string: "http://\(ipAddress):\(httpUpdatesPort)/osc/checkForUpdates")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("application/json; charaset=utf-8", forHTTPHeaderField: "Content-Type")
        let object: [String: AnyObject] = ["stateFingerprint": stateFingerprint]
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(object, options: .PrettyPrinted)
        } catch let error as NSError {
            assertionFailure(error.localizedDescription)
        }

        self.task = self.urlSession!.dataTaskWithRequest(request) { (data, response, error) in
            completionHandler(data, response, error)
        }
        self.task!.resume()
    }

    private func getRequestForExecute(name: String, parameters: [String: AnyObject]? = nil) -> NSMutableURLRequest {
        let url = NSURL(string: "http://\(ipAddress):\(httpPort)/osc/commands/execute")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("application/json; charaset=utf-8", forHTTPHeaderField: "Content-Type")
        var object: [String: AnyObject] = ["name": name]
        if let parameters = parameters {
            object["parameters"] = parameters
        }
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(object, options: .PrettyPrinted)
        } catch let error as NSError {
            assertionFailure(error.localizedDescription)
        }

        return request
    }

    public func execute(name: String, parameters: [String: AnyObject]? = nil, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)? = nil) {
        self.cancel()

        let request = getRequestForExecute(name, parameters: parameters)
        self.task = completionHandler == nil ?
            self.urlSession!.dataTaskWithRequest(request) :
            self.urlSession!.dataTaskWithRequest(request) { (data, response, error) in
                completionHandler!(data, response, error)
            }
        self.task!.resume()
    }

    public func execute(name: String, parameters: [String: AnyObject]? = nil, delegate: NSURLSessionDelegate) {
        self.cancel()

        let urlSession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(),
                                      delegate: delegate, delegateQueue: NSOperationQueue.mainQueue())
        let request = getRequestForExecute(name, parameters: parameters)
        self.task = urlSession.dataTaskWithRequest(request)
        self.task!.resume()
    }

    public func status(id id: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.cancel()

        let url = NSURL(string: "http://\(ipAddress):\(httpPort)/osc/commands/status")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("application/json; charaset=utf-8", forHTTPHeaderField: "Content-Type")
        let object: [String: AnyObject] = ["id": id]
        do {
            request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(object, options: .PrettyPrinted)
        } catch let error as NSError {
            assertionFailure(error.localizedDescription)
        }
        self.task = self.urlSession!.dataTaskWithRequest(request) { (data, response, error) in
            completionHandler(data, response, error)
        }
        self.task!.resume()
    }

    public func getWaitDoneHandler(completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)? = nil) -> (NSData?, NSURLResponse?, NSError?) -> Void {
        var waitDoneHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)!
        waitDoneHandler = { (data, response, error) in
            guard let d = data where error == nil else {
                completionHandler?(data, response, error)
                return
            }

            let jsonDic = try? NSJSONSerialization.JSONObjectWithData(d, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
            guard let dic = jsonDic, rawState = dic["state"] as? String, state = OSCCommandState(rawValue: rawState) else {
                completionHandler?(data, response, error)
                return
            }

            switch state {
            case .InProgress:
                if let id = dic["id"] as? String {
                    sleep(1)
                    self.status(id: id, completionHandler: waitDoneHandler)
                }
            case .Done:
                fallthrough
            case .Error:
                fallthrough
            default:
                completionHandler?(data, response, error)
            }
        }

        return waitDoneHandler
    }

    // MARK: - OSCCameraCommand Methods

    public func startSession(completionHandler completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.execute("camera.startSession", parameters: nil, completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func updateSession(sessionId sessionId: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.execute("camera.updateSession", parameters: ["sessionId": sessionId], completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func closeSession(sessionId sessionId: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)? = nil) {
        self.execute("camera.closeSession", parameters: ["sessionId": sessionId], completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func takePicture(sessionId sessionId: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)? = nil) {
        self.execute("camera.takePicture", parameters: ["sessionId": sessionId], completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func listImages(entryCount entryCount: Int, maxSize: Int? = nil, continuationToken: String? = nil, includeThumb: Bool? = nil, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        var parameters: [String: AnyObject] = ["entryCount": entryCount]
        if let maxSize = maxSize {
            parameters["maxSize"] = maxSize
        }
        if let continuationToken = continuationToken {
            parameters["continuationToken"] = continuationToken
        }
        if let includeThumb = includeThumb {
            parameters["includeThumb"] = includeThumb
        }
        self.execute("camera.listImages", parameters: parameters, completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func delete(fileUri fileUri: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)? = nil) {
        let parameters: [String: AnyObject] = ["fileUri": fileUri]
        self.execute("camera.delete", parameters: parameters, completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func getImage(fileUri fileUri: String, maxSize: Int? = nil, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        var parameters: [String: AnyObject] = ["fileUri": fileUri]
        if let maxSize = maxSize {
            parameters["maxSize"] = maxSize
        }
        self.execute("camera.getImage", parameters: parameters, completionHandler: completionHandler)
    }

    public func getMetadata(fileUri fileUri: String, completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        let parameters: [String: AnyObject] = ["fileUri": fileUri]
        self.execute("camera.getMetadata", parameters: parameters, completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func getOptions(sessionId sessionId: String, optionNames: [String], completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.execute("camera.getOptions", parameters: ["sessionId": sessionId, "optionNames": optionNames], completionHandler: self.getWaitDoneHandler(completionHandler))
    }

    public func setOptions(sessionId sessionId: String, options: [String: AnyObject], completionHandler: ((NSData?, NSURLResponse?, NSError?) -> Void)) {
        self.execute("camera.setOptions", parameters: ["sessionId": sessionId, "options": options], completionHandler: self.getWaitDoneHandler(completionHandler))
    }

}
