import Foundation
import AWSS3
import AWSCore
import AWSCognito
import AWSCognitoIdentityProviderASF
import Photos
import SDWebImageWebPCoder

class AWSCustomService{
    
    static let instance = AWSCustomService()
    private init(){
        if !Defaults.getAWSConfigSet(){
            configure()
        }
    }
    
    public func configure(){
        DataSource.getJWTToken(authToken: {(token, error) in
            guard let token = token, error == nil else {
                Defaults.resetValues()
                self.loadLogin()
                print("firebase jwt auth error: \(error?.localizedDescription ?? "nil")")
                return
            }
            print("jwt: \(token)")
            let region = AWSRegionType.USWest1
            let logins = ["securetoken.google.com/project-978902837598" as NSString: token as NSString]
            let customProviderManager = CustomIdentityProvider(tokens: logins)
            let credentialsProvider = AWSCognitoCredentialsProvider(regionType:region, identityPoolId:"us-west-1:2e468d80-204f-4b20-a1d9-3533e78c70a4", identityProviderManager: customProviderManager)
            let configuration = AWSServiceConfiguration(region:region, credentialsProvider:credentialsProvider)
            if let serviceManager = AWSServiceManager.default(){
                serviceManager.defaultServiceConfiguration = configuration
                print("aws config set")
            }else{
                print("aws config could not set")
            }
        })
    }
    
    public func configure(success: @escaping(Bool) -> ()){
        DataSource.getJWTToken(authToken: {(token, error) in
            guard let token = token, error == nil else {
                Defaults.resetValues()
                (UIApplication.shared.delegate as! AppDelegate).loadLogin()
                print("firebase jwt auth error: \(error?.localizedDescription ?? "nil")")
                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "firebase jwt auth error: \(error?.localizedDescription ?? "nil")", type: .error, module: .upload)
                success(false)
                return
            }
            if json.keys.contains("region"){
                Defaults.setBucket(value: json["bucket"] as! String)
                let region = AWSRegionType.init(rawValue: json["region"] as! Int) ?? AWSRegionType.USWest1
                let logins = ["securetoken.google.com/picaggo-235807" as NSString: token as NSString]
                let customProviderManager = CustomIdentityProvider(tokens: logins)
                let credentialsProvider = AWSCognitoCredentialsProvider(regionType:region,
                                                                        identityPoolId:json["pool_id"] as! String, identityProviderManager: customProviderManager)
                let configuration = AWSServiceConfiguration(region:region, credentialsProvider:credentialsProvider)
                if let serviceManager = AWSServiceManager.default(){
                    serviceManager.defaultServiceConfiguration = configuration
                    print("aws config set")
                    CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws config set", type: .debug, module: .upload)
                    Defaults.setAWSConfigSet(status: true)
                    success(true)
                }else{
                    print("aws config could not set")
                    CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws config could not set", type: .error, module: .upload)
                    Defaults.setAWSConfigSet(status: false)
                    success(false)
                }
            }
        })
    }
    
    public func uploadLogFile(url: URL, key: String, result: @escaping(Bool, Error?, Bool) -> ()){
        let bucket = Defaults.getBucket()
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = {(task, progress) in
            print("aws Progess single: \(progress) val: \(Float(progress.fractionCompleted))")
        }
        let fileURL = URL.init(fileURLWithPath: url.path)
        let fileKey = key + "/" + url.lastPathComponent
        AWSS3TransferUtility.default().uploadFile(fileURL, bucket: bucket, key: fileKey, contentType: "text/plain", expression: expression, completionHandler: { (task, error) -> Void in
            DispatchQueue.main.async(execute: {
                if error == nil {
                    let awsurl = AWSS3.default().configuration.endpoint.url
                    let publicURL = awsurl?.appendingPathComponent(bucket).appendingPathComponent(url.lastPathComponent)
                    print("Uploaded to:\(String(describing: publicURL))")
                    do {
                        try FileManager.default.removeItem(at: url)
                        print("File deleted successfully. \(url)")
                    } catch {
                        print("Error deleting file: \(error)")
                    }
                    result(true, nil, false)
                } else {
                    print("aws image error: \(error)")
                    result(false, error, false)
                }
            })
        }).continueWith { (task) -> AnyObject? in
            if let error = task.error {
                print("aws single 2 Error: \(error)")
                result(false, error, true)
            }
            if let _ = task.result {
                print("aws single Upload Starting!")
            }
            return nil
        }
    }
    
    public func uploadFile(url: URL, subKey: String, mimeType: String, name: String, event_id: String, location_id: String, id: String, result: @escaping(Bool, Error?, Bool) -> ()){
        CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "uploadFile: \(name)", type: .debug, module: .upload)
//        DispatchQueue.global(qos: .utility).async{
//            LocalPhotos().checkPhotoLibraryPermission(access: {allowed in
//                if allowed{
//
//                }
//            })
//        }
        DispatchQueue.global(qos: .utility).async{
            let key = "events/\(location_id)/\(subKey)/\(name)"
            let bucket = Defaults.getBucket()
            self.doesFileExists(key: key, onComplete: {(exists, error, size) in
                print("file: \(key) exists: \(exists) error: \(error)")
                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "doesFileExists: \(name) exists: \(exists)", type: .debug, module: .upload)
    //            let bucket = "picaggo-region-bucket"
    //                        let bucket = "test-picaggo"
    //                        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USWest1, identityPoolId:"us-west-1:2e468d80-204f-4b20-a1d9-3533e78c70a4", identityProviderManager: OIDCProvider())
                
    //                        let configuration = AWSServiceConfiguration(region:.USWest1, credentialsProvider:credentialsProvider)
    //
    //                        let config = AWSS3TransferUtilityConfiguration()
    //                        config.isAccelerateModeEnabled = true
                if exists{
                    if subKey == "compressed"{
                        Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: 0.0, subKey: subKey, mime: mimeType)
                    }
                    result(true, nil, false)
                }else{
                    CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "file size: \(name) size: \(url.fileSize)", type: .debug, module: .upload)
                    print("AWS url \(url) size: \(url.fileSize) mimeType: \(mimeType)")
                    if url.fileSize > 1000000000{
                        let expression = AWSS3TransferUtilityMultiPartUploadExpression()
                        expression.progressBlock = {(task, progress) in
                            print("aws Progess multi : \(progress) val: \(Float(progress.fractionCompleted))")
                            Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: progress.fractionCompleted, subKey: subKey, mime: mimeType)
                            CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws multi upload progress: \(name) progress: \(progress) val: \(Float(progress.fractionCompleted))", type: .debug, module: .upload)
        //                    if subKey == "originals"{
        //                        Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: progress.fractionCompleted)
        //                    }
                        }
                        let transferManager = AWSS3TransferUtility.default()
                        
                        print("aws config: \(transferManager.configuration)")
        //                            transferManager.configuration = config
                        let fileURL = URL.init(fileURLWithPath: url.path)
                        transferManager.uploadUsingMultiPart(fileURL: fileURL, bucket: bucket, key: key, contentType: mimeType, expression: expression, completionHandler: { (task, error) -> Void in
                            if ((error) != nil){
                                print("aws multi Failed with error")
                                print("aws multi 1 Error: \(error!)")
                                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws multi upload error: \(name) error: \(error)", type: .debug, module: .upload)
                                Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: 0.0, subKey: subKey, mime: mimeType)
                                result(false, error, false)
                            }else{
                                if subKey == "compressed"{
                                    Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: 0.0, subKey: subKey, mime: mimeType)
                                }
                                print("aws multi Success")
                                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws multi upload success: \(name)", type: .debug, module: .upload)
                                result(true, nil, false)
                            }
                        }).continueWith { (task) -> AnyObject? in
                            if let error = task.error {
                                print("aws multi Error: \(error)")
                                result(false, error, true)
                            }
                            if let _ = task.result {
                                print("aws multi Upload Starting!")
                                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws multi upload started: \(name) exists: \(exists)", type: .debug, module: .upload)
                            }
                            return nil;
                        }
                    }else if url.fileSize > 0{
                        let expression = AWSS3TransferUtilityUploadExpression()
                        expression.progressBlock = {(task, progress) in
                            print("aws Progess name: \(name) val: \(Float(progress.fractionCompleted))")
                            CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws upload progress: \(name) subKey:\(subKey) progress: \(progress) val: \(Float(progress.fractionCompleted))", type: .debug, module: .upload)
        //                    if subKey == "originals"{
        //                        Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: progress.fractionCompleted, subKey: subKey, mime: mimeType)
        //                    }
                            if subKey == "originals", progress.fractionCompleted == 1.0{
                                Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: progress.fractionCompleted, subKey: subKey, mime: mimeType)
                                Database.instance.setFileServerSync(id: id, locationId: location_id, eventId: event_id, onComplete: {success in
                                })
                                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws upload progress completed: \(name)", type: .debug, module: .upload)
                            }else{
                                Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: progress.fractionCompleted, subKey: subKey, mime: mimeType)
                            }
                            
                            
                        }
                        expression.setValue(event_id, forRequestParameter: "x-amz-meta-event_id")
                        expression.setValue(Defaults.getUserId(), forRequestParameter: "x-amz-meta-user_id")
                        let fileURL = URL.init(fileURLWithPath: url.path)
                        print("AWSS3TransferUtility file url: \(fileURL)")
        //                            AWSS3TransferUtility.register(with: configuration!, transferUtilityConfiguration: config, forKey: "USWest1S3TransferUtility")
                        
        //                            print("aws config: \(transferManager.configuration.)")
        //                            transferManager.configuration = config
                        
                        AWSS3TransferUtility.default().uploadFile(fileURL, bucket: bucket, key: key, contentType: mimeType, expression: expression, completionHandler: { (task, error) -> Void in
                            DispatchQueue.main.async(execute: {
                                if error == nil {
                                    let url = AWSS3.default().configuration.endpoint.url
                                    let publicURL = url?.appendingPathComponent(bucket).appendingPathComponent(name)
                                    print("Uploaded to:\(String(describing: publicURL))")
                                    if subKey == "compressed"{
                                        Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: 0.0, subKey: subKey, mime: mimeType)
                                    }
                                    CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws upload progress completed: \(name) subKey:\(subKey)", type: .debug, module: .upload)
                                    result(true, nil, false)
                                } else {
                                    Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: 0.0, subKey: subKey, mime: mimeType)
                                    print("aws image error: \(error)")
                                    CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws upload progress error: name: \(name) subKey:\(subKey) error: \(error)", type: .debug, module: .upload)
                                    result(false, error, false)
                                }
                            })
                        }).continueWith { (task) -> AnyObject? in
                            if let error = task.error {
                                print("aws single 2 Error: \(error)")
                                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws upload progress error: name: \(name) subKey:\(subKey) error: \(error)", type: .debug, module: .upload)
                                result(false, error, true)
                            }
                            if let _ = task.result {
                                print("aws single Upload Starting!")
                                CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws upload started name: \(name) subKey:\(subKey) error: \(error)", type: .debug, module: .upload)
                            }
                            return nil
                        }
                    }else{
                        print("file size is zero, compress again")
                        CustomLog.instance.addLog(tag: String(describing: type(of: self)), text: "aws upload file size if zero name: \(name) subKey:\(subKey)", type: .debug, module: .upload)
                        result(false, nil, false)
                    }
                }
            })
        }
    }
    
    public func uploadDataFile(url: URL, result: @escaping(Bool, Error?, Bool) -> ()){
        DispatchQueue.global(qos: .utility).async{
            let key = "local_data/\(Defaults.getUserId())/\(url.lastPathComponent)"
            let bucket = Defaults.getBucket()
            self.doesFileExists(key: key, onComplete: {(exists, error, size) in
                print("file: \(key) exists: \(exists) error: \(error)")
                if exists{
                    result(true, nil, false)
                }else{
                    let expression = AWSS3TransferUtilityUploadExpression()
                    expression.progressBlock = {(task, progress) in
                        print("aws json Progess single: \(progress) val: \(Float(progress.fractionCompleted))")
                    }
                    let fileURL = URL.init(fileURLWithPath: url.path)
                    AWSS3TransferUtility.default().uploadFile(fileURL, bucket: bucket, key: key, contentType: "application/json", expression: expression, completionHandler: { (task, error) -> Void in
                        DispatchQueue.main.async(execute: {
                            if error == nil {
                                let _url = AWSS3.default().configuration.endpoint.url
                                let publicURL = _url?.appendingPathComponent(bucket).appendingPathComponent(url.lastPathComponent)
                                print("Uploaded to:\(String(describing: publicURL))")
                                result(true, nil, false)
                            } else {
                                print("aws json error: \(error)")
                                result(false, error, false)
                            }
                        })
                    }).continueWith { (task) -> AnyObject? in
                        if let error = task.error {
                            print("aws single 2 Error: \(error)")
                            result(false, error, true)
                        }
                        if let _ = task.result {
                            print("aws single Upload Starting!")
                        }
                        return nil
                    }
                }
            })
        }
    }
    
    public func doesFileExists(key: String, onComplete: @escaping(Bool, Error?, Int) -> ()){
        if let headObjectsRequest = AWSS3HeadObjectRequest(){
            headObjectsRequest.bucket = Defaults.getBucket()
            headObjectsRequest.key = key
            print("Checking file exists in s3: \(key)")
            AWSS3.default().headObject(headObjectsRequest).continueWith(block: {(task) -> AnyObject?  in
                if let error = task.error {
                    print("Error to find file: \(error)")
                    onComplete(false,error, 0)
                } else {
                    print("fileExist: \(task.result?.contentLength)")
                    if let size = task.result?.contentLength{
                        onComplete(true, nil, Int(size))
                    }else{
                        onComplete(true, nil, 0)
                    }
                }
                return nil
            })
        }else{
            onComplete(false, nil, 0)
        }
    }

    //    public func uploadFiles(url: URL, mimeType: String, name: String, event_id: String, id: String){
////        if !AWSCustomService.tokenSet{
////            self.configure()
////        }
//        print("aws upload called")
//        print("aws url: \(url)")
//        LocalPhotos().checkPhotoLibraryPermission(access: {allowed in
//            print("aws gallery permission: \(allowed)")
//            if allowed{
//                let transferUtility = AWSS3TransferUtility.default()
//                let key = "events/\(event_id)/originals/\(name)"
//                let bucket = "picaggo-app"
//                let expression = AWSS3TransferUtilityMultiPartUploadExpression()
//                expression.progressBlock = {(task, progress) in
//                    print("aws Progess: \(progress) val: \(Float(progress.fractionCompleted))")
//                    Database.instance.updateUploadProgress(eventId: event_id, id: id, progress: progress.fractionCompleted)
//                }
//                transferUtility.uploadUsingMultiPart(fileURL: url, bucket: bucket, key: key, contentType: mimeType, expression: expression, completionHandler: { (task, error) -> Void in
//                    if ((error) != nil){
//                        print("aws Failed with error")
//                        print("aws 1 Error: \(error!)");
//                    }else{
//                        print("aws Success")
//                        Database.instance.setFileServerSync(id: id, eventId: event_id)
//                        FilesUpload.instance.startUpload()
//                    }
//                }).continueWith { (task) -> AnyObject? in
//                    if let error = task.error {
//                        print("aws \(key) Error: \(error)")
//                       
//                    }
//                    if let _ = task.result {
//                        print("aws Upload Starting!")
//                    }
//                    return nil;
//                }
//            }
//        })
//    }
    
    public func getData(source_url: URL, mimeType: GalleryPhotos.mimeType, FileData: @escaping(Data?) -> ()){
//        let bucket = "picaggo-app"
//        let transferManager = AWSS3TransferUtility.default()
////        print("aws TM: \(transferManager.configuration.regionType)")
//        let expression = AWSS3TransferUtilityDownloadExpression()
//        transferManager.downloadData(fromBucket: bucket, key: key, expression: expression, completionHandler: { (task, URL, data, error) in
//            if let data = data{
//                FileData(data)
//            }else{
//                FileData(nil)
//            }
//        })
//        if let source_url = URL(string: ClfUrl + key) {
//            do {
//                let data = try Data.init(contentsOf: source_url)
//                FileData(data)
//            } catch {
//                print("download error: \(key) error: \(error)")
//                FileData(nil)
//            }
//        } else {
//            // the URL was bad!
//            print("download data url is not valid: \(ClfUrl + key)")
//            FileData(nil)
//        }
        if mimeType == .image{
            SDWebImageManager.shared.loadImage(with: source_url, options: [.highPriority], progress: nil, completed: {(image, data, error, cacheType, finished, imageURL) in
                if finished{
                    if let image = image{
                        let d = image.sd_imageData()
                        FileData(d)
                    }else{
                        FileData(nil)
                    }
                }
            })
        }else{
            do {
                let data = try Data.init(contentsOf: source_url)
                FileData(data)
            } catch {
                print("download error: \(source_url) error: \(error)")
                FileData(nil)
            }
        }
    }
    
    public func getVideoLink(key: String, url: @escaping(URL?, Error?) -> ()){
//        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USWest1, identityPoolId:"us-west-1:2e468d80-204f-4b20-a1d9-3533e78c70a4", identityProviderManager: OIDCProvider())
//
//        let configuration = AWSServiceConfiguration(region:.USWest1, credentialsProvider:credentialsProvider)
//
//        AWSS3PreSignedURLBuilder.register(with: configuration!, forKey: "USWest1S3Presigned")
        
//        let getPreSignedURLRequest = AWSS3GetPreSignedURLRequest()
//        getPreSignedURLRequest.bucket = "picaggo-app"
//        getPreSignedURLRequest.key = key
//        getPreSignedURLRequest.httpMethod = .GET
//        getPreSignedURLRequest.expires = Date(timeIntervalSinceNow: 3600)
//
//        AWSS3PreSignedURLBuilder.default().getPreSignedURL(getPreSignedURLRequest).continueWith { (task:AWSTask<NSURL>) -> Any? in
//            if let error = task.error {
//                print("Error: \(error)")
//                url(nil, error)
//            }
//
//            let presignedURL = task.result
//            print("Download presignedURL is: \(String(describing: presignedURL))")
//            url(presignedURL as URL?, nil)
//            return nil
//        }
        
//        url(URL.init(string: ClfUrl + key), nil)
//        url(URL.init(string: "https://d2ov4tlhquehzm.cloudfront.net/events/278/original/IMG_4366.mp4"), nil)
    }
    
    private func saveFile(path: String, mimeType: GalleryPhotos.mimeType, resultCollections: PHFetchResult<PHAssetCollection>){
        if resultCollections.count > 0{
            PHPhotoLibrary.shared().performChanges({
                var assetChangeRequest: PHAssetChangeRequest!
                if mimeType == .image{
                    assetChangeRequest  = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: path))
                }else{
                    assetChangeRequest  = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: path))
                }
                
                let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: resultCollections.firstObject!)
                let enumeration: NSArray = [assetPlaceHolder!]
                albumChangeRequest!.addAssets(enumeration)
            }) {
                success, error in
                if success {
                    print("image Succesfully Saved")
                } else {
                    print(error?.localizedDescription as Any)
                }
            }
        }
    }
    
    
    public func downloadFiles(downloadURL: URL, url: URL, mimeType: GalleryPhotos.mimeType, resultCollections: PHFetchResult<PHAssetCollection>){
        print("download url: \(downloadURL)")
        if mimeType == .image{
            SDWebImageManager.shared.loadImage(with: downloadURL, options: .continueInBackground, progress: { (progress, total, url) in
                print("SDWebImageManager progress: \(progress) total: \(total) url: \(url)")
            }, completed: {(image, data, error, cacheType, finished, imageURL) in
                print("\(url.lastPathComponent) finished: \(finished)")
                if finished, let image = image{
//                    UIImageWriteToSavedPhotosAlbum(image, self, nil, nil)
                    do {
                        let d = image.sd_imageData()
                        try d!.write(to: url, options: .atomic)
                        self.saveFile(path: url.path, mimeType: mimeType, resultCollections: resultCollections)
                    } catch {
                        print("download error: \(downloadURL) error: \(error)")
                    }
                }
            })
        }else{
            do {
                let data = try Data.init(contentsOf: downloadURL)
                try data.write(to: url)
                saveFile(path: url.path, mimeType: mimeType, resultCollections: resultCollections)
            } catch {
                print("download error: \(downloadURL) error: \(error)")
            }
        }

//        transferUtility.downloadData(fromBucket: bucket, key: key, expression: expression, completionHandler: {(task, location, data, error) in
//            guard let data = data, error == nil else{
//                print("downloading error: \(error)")
//                return
//            }
//            print("\(key) saved")
//            do{
//                try data.write(to: url, options: .atomic)
//                if resultCollections.count > 0{
//                    PHPhotoLibrary.shared().performChanges({
//                        var assetChangeRequest: PHAssetChangeRequest!
//                        if mimeType == .image{
//                            assetChangeRequest  = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: filePath))
//                        }else{
//                            assetChangeRequest  = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: filePath))
//                        }
//
//                        let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset
//                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: resultCollections.firstObject!)
//                        let enumeration: NSArray = [assetPlaceHolder!]
//                        albumChangeRequest!.addAssets(enumeration)
//                    }) {
//                        success, error in
//                        if success {
//                            print("image Succesfully Saved")
//                        } else {
//                            print(error?.localizedDescription as Any)
//                        }
//                    }
//                }
//            }
//            catch{
//                print("video data write error")
//            }
//        }).continueWith { (task) -> AnyObject? in
//            if let error = task.error {
//                print("aws download start Error: \(error)")
//            }
//            if let _ = task.result {
//                print("aws download Starting!")
//            }
//            return nil;
//        }
    }
    
    public func downloadFiles(key: String, filePath: String, mimeType: GalleryPhotos.mimeType, resultCollections: PHFetchResult<PHAssetCollection>, delete: Bool = true, completed:  @escaping(Bool) ->()){
        let bucket = "picaggo-app"
        let transferManager = AWSS3TransferUtility.default()
        let expression = AWSS3TransferUtilityDownloadExpression()
        let url = URL.init(fileURLWithPath: filePath)
        transferManager.downloadData(fromBucket: bucket, key: key, expression: expression, completionHandler: {(task, location, data, error) in
            guard let data = data, error == nil else{
                print("downloading error: \(error)")
                return
            }
            print("\(key) saved")
            do{
                try data.write(to: url, options: .atomic)
                if resultCollections.count > 0 && delete{
                    PHPhotoLibrary.shared().performChanges({
                        var assetChangeRequest: PHAssetChangeRequest!
                        if mimeType == .image{
                            assetChangeRequest  = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: URL(fileURLWithPath: filePath))
                        }else{
                            assetChangeRequest  = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: filePath))
                        }
                        
                        let assetPlaceHolder = assetChangeRequest?.placeholderForCreatedAsset
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: resultCollections.firstObject!)
                        let enumeration: NSArray = [assetPlaceHolder!]
                        albumChangeRequest!.addAssets(enumeration)
                    }) {
                        success, error in
                        if success {
                            if delete{
                                do {
                                    try FileManager.default.removeItem(atPath: filePath)
                                } catch {
                                    print("Could not delete file, probably read-only filesystem: \(error)")
                                }
                            }
                            print("file Succesfully Saved")
                            completed(true)
                        } else {
                            print(error?.localizedDescription as Any)
                            completed(false)
                        }
                    }
                }else{
                    completed(true)
                }
            }
            catch{
                print("video data write error")
                completed(false)
            }
        })
    }
    
    class CustomIdentityProvider: NSObject, AWSIdentityProviderManager{
        var tokens : [NSString : NSString]!
        init(tokens: [NSString : NSString]) {
            self.tokens = tokens
        }
        @objc func logins() -> AWSTask<NSDictionary> {
            return AWSTask(result: tokens as NSDictionary?) as! AWSTask<NSDictionary>
        }
    }
    
//    class OIDCProvider: NSObject, AWSIdentityProviderManager {
//        func logins() -> AWSTask<NSDictionary> {
//            let completion = AWSTaskCompletionSource<NSString>()
//            getToken(tokenCompletion: completion)
//            return completion.task.continueOnSuccessWith { (task) -> AWSTask<NSDictionary>? in
//                return AWSTask(result:["securetoken.google.com/picaggo-235807":task.result!])
//            } as! AWSTask<NSDictionary>
//        }
//        func getToken(tokenCompletion: AWSTaskCompletionSource<NSString>) -> Void {
//            Defaults.getJWTToken(authToken: {token in
//                tokenCompletion.set(result: token as NSString?)
//            })
//            print("aws getting token")
//        }
//    }
    
}



//class identityProvider: NSObject, AWSIdentityProviderManager{
//    var token = ""
//    func logins() -> AWSTask<NSDictionary> {
//        return AWSTask(result:["https://securetoken.google.com/picaggo-235807":token]) as! AWSTask<NSDictionary>
//    }
//
//}
