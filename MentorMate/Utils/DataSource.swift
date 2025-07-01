import Foundation
import Firebase
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

class DataSource{
    
    private static var firstAttempt = true
    
    private static let parameters: [String: Any] = [
        "platform" : "iOS",
    ]
    
    public static func callAPI(url: String, params: [String: Any], onComplete: @escaping(Data?, Int?, Error?)->()){
        print(url)
        let date = Date()
        if true || Network.reachability.isReachable{
                getJWTToken(authToken: {(token, error) in
                    print(token);
                    guard let token = token, error == nil else {
                        if Defaults.getUserId() != nil{
                            Defaults.resetValues()
                        }
                        DispatchQueue.main.async {
                            (UIApplication.shared.delegate as! AppDelegate).loadLogin()
                        }
                        print("firebase jwt auth error: \(error?.localizedDescription ?? "nil")")
                        return
                    }
                    let parameters = params.merging(self.parameters, uniquingKeysWith: { (current, _) in current })

                    let url = URL(string: url)!
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                    request.setValue("default-src 'none'; frame-ancestors 'none'", forHTTPHeaderField: "Content-Security-Policy")
                    request.setValue("1", forHTTPHeaderField: "X-XSS-Protection")
                    request.setValue("block", forHTTPHeaderField: "mode")
                    request.setValue("nosniff", forHTTPHeaderField: "X-Content-Type-Options")
                    request.setValue("max-age:900", forHTTPHeaderField: "Strict-Transport-Security")
                    request.setValue(token, forHTTPHeaderField: "Authorization")
                    request.httpBody = parameters.percentEscaped().data(using: .utf8)
                    
                    let sessionConfig = URLSessionConfiguration.default
                    sessionConfig.timeoutIntervalForRequest = 900
                    sessionConfig.timeoutIntervalForResource = 900 //TimeInterval.init(900)
                    sessionConfig.networkServiceType = .responsiveData
                    sessionConfig.waitsForConnectivity = true
                    sessionConfig.requestCachePolicy = .reloadRevalidatingCacheData
                    sessionConfig.allowsConstrainedNetworkAccess = true
                    sessionConfig.networkServiceType = .responsiveData
                    sessionConfig.tlsMaximumSupportedProtocolVersion = tls_protocol_version_t.TLSv13
                    sessionConfig.tlsMinimumSupportedProtocolVersion = tls_protocol_version_t.DTLSv12
                    
                    let session = URLSession(configuration: sessionConfig)
                    
                    let task = session.dataTask(with: request){ data, response, error in
                        print("response status code: \(response?.getStatusCode()) error: \(error)")
                        print("req response time: \(Date().seconds(from: date)) \(url.lastPathComponent)")
                        onComplete(data, response?.getStatusCode(), error)
                    }
                    task.resume()
                })
        }else{
            onComplete(nil, nil, nil)
        }
    }
    
    public static func getJWTToken(authToken:@escaping (String?, Error?)->()){
        print("current user null: \(Auth.auth().currentUser == nil)")
        if let user = Auth.auth().currentUser{
            user.getIDToken(completion: {(token, error) in
                if let _token = token, error == nil{
    //                print("jwt: \(_token)")
                    authToken(_token, nil)
                }else if self.firstAttempt{
                    self.firstAttempt = false
                    getJWTToken(authToken: {token, error in
                        authToken(token,error)
                    })
                }else{
                    authToken(nil, error)
                }
            })
        }else{
            authToken(nil, nil)
        }
        
    }
}

