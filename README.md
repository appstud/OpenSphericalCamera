# Open Spherical Camera Client in Swift
A Swift Open Spherical Camera API library with Ricoh Theta S extension

## Requirements

| branch | Swift(Xcode) | OSC API Level | THETA API Ver. | Release |
|--------|-------------:|--------------:|---------------:|--------:|
|master|3 (8.0+)|2 & 1|2.1 & 2.0|3.0.0|
|osc-v2-swift2.3|2.3 (8.0+)|2 & 1|2.1 & 2.0|2.1.0|
|osc-v2-swift2.2|2.2+ (7.3+)|2 & 1|2.1 & 2.0|2.0.0|
|osc-v1-swift2.2|2.2+ (7.3+)|1|2.0|1.0.1|

## Installation

### CocoaPods

[CocoaPods](http://cocoapods.org) is a dependency manager for Cocoa projects. You can install it with the following command:

```bash
$ gem install cocoapods
```

To integrate OpenSphericalCamera into your Xcode project using CocoaPods, specify it in your `Podfile`:

```ruby
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '9.0'
use_frameworks!

target '<Your Target Name>' do
  pod 'OpenSphericalCamera', '~> 3.0.0'
end
```

Then, run the following command:

```bash
$ pod install
```

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage with [Homebrew](http://brew.sh/) using the following command:

```bash
$ brew update
$ brew install carthage
```

To integrate OpenSphericalCamera into your Xcode project using Carthage, specify it in your `Cartfile`:

```ogdl
github "tatsu/OpenSphericalCamera" ~> 3.0.0
```

Run `carthage update` to build the framework and drag the built `OpenSphericalCamera.framework` into your Xcode project.

## Usage

### Protocols

|API|Method
|---|------
|GET /osc/info|info(completionHandler:)
|POST /osc/state|state(completionHandler:)
|POST /osc/checkForUpdates|checkForUpdates(stateFingerprint:completionHandler:)
|POST /osc/commands/execute|execute(_:parameters:completionHandler:)
||execute(_:parameters:delegate:)
|POST /osc/commands/status|status(id:completionHandler:)

### Generic Commands

|API|Level 1 (Theta v2.0) Method|Level 2 (Theta v2.1) Method|
|---|---------------------------|---------------------------|
|camera.startSession|startSession(progressNeeded:completionHandler:)|-|
|camera.updateSession|updateSession(sessionId:progressNeeded:completionHandler:)|-|
|camera.closeSession|closeSession(sessionId:progressNeeded:completionHandler:)|-|
|camera.takePicture|takePicture(sessionId:progressNeeded:completionHandler:)|takePicture(progressNeeded:completionHandler:)|
|camera.processPicture|-|processPicture(previewFileUrls:progressNeeded:completionHandler:)|
|camera.startCapture|-|startCapture(progressNeeded:completionHandler:)|
|camera.stopCapture|-|stopCapture(progressNeeded:completionHandler:)|
|camera.getLivePreview|-|getLivePreview(_:)|
|camera.listImages|listImages(entryCount:maxSize:continuationToken:includeThumb:progressNeeded:completionHandler:)|-|
|camera.listFiles|-|listFiles(fileType:startPosition:entryCount:maxThumbSize:progressNeeded:completionHandler:)|
|camera.delete|delete(fileUri:progressNeeded:completionHandler:)|delete(fileUrls:progressNeeded:completionHandler:)|
|camera.getImage|getImage(fileUri:maxSize:progressNeeded:completionHandler:)|-|
|camera.getMetadata|getMetadata(fileUri:progressNeeded:completionHandler:)|-|
|camera.setOptions|setOptions(sessionId:options:progressNeeded:completionHandler:)|setOptions(options:progressNeeded:completionHandler:)|
|camera.getOptions|getOptions(sessionId:optionNames:progressNeeded:completionHandler:)|getOptions(optionNames:progressNeeded:completionHandler:)|
|camera.reset|-|reset(progressNeeded:completionHandler:)|

### Theta Commands

|API|Level 1 (Theta v2.0) Method|Level 2 (Theta v2.1) Method|
|---|---------------------------|---------------------------|
|camera._finishWlan|_finishWlan(sessionId:progressNeeded:completionHandler:)|_finishWlan(progressNeeded:completionHandler:)|
|camera._startCapture|_startCapture(sessionId:progressNeeded:completionHandler:)|-|
|camera._stopCapture|_stopCapture(sessionId:progressNeeded:completionHandler:)|-|
|camera._listAll|_listAll(entryCount:continuationToken:detail:sort:progressNeeded:completionHandler:)|-|
|camera.listFiles|-|listFiles(fileType:startPosition:entryCount:maxThumbSize:_detail:_sort:progressNeeded:completionHandler:)|
|camera.getImage|getImage(fileUri:_type:progressNeeded:completionHandler:)|-|
|camera._getVideo|_getVideo(fileUri:_type:progressNeeded:completionHandler:)|-|
|camera._getLivePreview|_getLivePreview(sessionId:completionHandler:)|-|
|camera._stopSelfTimer|_stopSelfTimer(progressNeeded:completionHandler:)|(same as on the left)|

### Sample Code

```swift
import OpenSphericalCamera

// Construct OSC generic camera
let osc = OpenSphericalCamera(ipAddress: "192.168.1.1", httpPort: 80)
// Or, Ricoh THETA S camera
let osc = ThetaCamera()

// Set OSC API level 2 (for Ricoh THETA S)
self.osc.startSession { (data, response, error) in
    if let data = data , error == nil {
        if let jsonDic = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as! [String: Any], let results = jsonDic["results"] as? [String: Any], let sessionId = results["sessionId"] as? String {
            self.osc.setOptions(sessionId: sessionId, options: ["clientVersion": 2]) { (data, response, error) in
                self.osc.closeSession(sessionId: sessionId)
            }
        } else {
            // Assume clientVersion is equal or later than 2
        }
    }
}

// Take picture
self.osc.takePicture { (data, response, error) in
    if let data = data, error == nil {
        let jsonDic = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as! [String: Any]
        if let jsonDic = jsonDic, let rawState = jsonDic["state"] as? String, let state = OSCCommandState(rawValue: rawState) {
            switch state {
            case .InProgress:
                /*
                 * Set execute commands' progressNeeded parameter true explicitly,
                 * except for getLivePreview, if you want this handler to be
                 * called back "inProgress". In any case, they are waiting for
                 * "done" or "error" internally.
                 */
            case .Done:
                if let results = jsonDic["results"] as? [String: Any], let fileUrl = results["fileUrl"] as? String {
                    // Get file
                    self.osc.get(fileUrl) { (data, response, error) in
                        if let data = data , error == nil {
                            DispatchQueue.main.async {
                                self.previewView.image = UIImage(data: data)
                            }
                        }
                    }
                }
            case .Error:
                break // TODO
            }
        }
    }
}
```

## Sample App
* [OpenSphericalCameraSample](https://github.com/tatsu/OpenSphericalCameraSample)

## References
* [Open Spherical Camera API](https://developers.google.com/streetview/open-spherical-camera/)
* [Ricoh THETA API v2.1](https://developers.theta360.com/en/docs/v2.1/api_reference/)

## License

This library is licensed under MIT. Full license text is available in [LICENSE](LICENSE).
