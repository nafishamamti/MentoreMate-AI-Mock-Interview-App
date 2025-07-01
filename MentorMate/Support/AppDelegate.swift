import UIKit
import FirebaseCore
import GoogleSignIn
import AWSS3
import AWSCore
import AWSCognitoIdentityProviderASF

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        FirebaseApp.configure()
        if Defaults.getUserId() != nil{
            loadHome()
        }else{
            loadLogin()
        }
        
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func loadLogin(){
        DispatchQueue.main.async {
            self.window = UIWindow(frame: UIScreen.main.bounds)
            let storyboard = UIStoryboard(name: "Login", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "loginScreen")
            self.window?.rootViewController = controller
            self.window?.makeKeyAndVisible()
        }
    }
    
    func loadHome(){
        DispatchQueue.main.async {
            self.window = UIWindow(frame: UIScreen.main.bounds)
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let controller = storyboard.instantiateViewController(withIdentifier: "homeScreen")
            self.window?.rootViewController = controller
            self.window?.makeKeyAndVisible()
        }
    }
    
    public func configureS3(){
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
    
    class CustomIdentityProvider: NSObject, AWSIdentityProviderManager{
        var tokens : [NSString : NSString]!
        init(tokens: [NSString : NSString]) {
            self.tokens = tokens
        }
        @objc func logins() -> AWSTask<NSDictionary> {
            return AWSTask(result: tokens as NSDictionary?) as! AWSTask<NSDictionary>
        }
    }

}

