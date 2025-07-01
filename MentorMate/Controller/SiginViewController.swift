import UIKit
import Firebase
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

class SiginViewController: UIViewController {
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        do{
            try Auth.auth().signOut()
            print("signed out")
        }catch let signOutError as NSError {
            print("Sign out error: \(signOutError)")
        }
        
    }
    
    @IBAction func googleLogin(_ sender: Any){
        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [unowned self] result, error in
            guard error == nil else {
                print(error)
                return
            }
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString, let email = user.profile?.email
            else {
                return
            }
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                           accessToken: user.accessToken.tokenString)
            print("jwt: \(user.accessToken.tokenString)")
            self.firebaseLogin(credential: credential, email: email)
           
        }
    }
    
    fileprivate func firebaseLogin(credential: AuthCredential, email: String?){
        Auth.auth().signIn(with: credential) { authResult, error in
            if let user = authResult?.user{
                print("apple: verified email: \(user.isEmailVerified)")
                DispatchQueue.main.async {
                    self.activityIndicator.startAnimating()
                }
                var _email: String!
                if let email = email {
                    _email = email
                }else if let email = user.email{
                    _email = email
                }
                if _email != nil{
                    Defaults.setUserEmail(value: _email)
                    self.proccedSignUp(user: user, email: _email)
                }else{
                    DispatchQueue.main.async { [self] in
                        activityIndicator.stopAnimating()
                        self.showToast("Try again later")
                    }
                }
            }else{
                DispatchQueue.main.async { [self] in
                    activityIndicator.stopAnimating()
                    self.showToast("Try again later")
                }
            }
        }
    }
    
    fileprivate func proccedSignUp(user : User, email: String){
        print("Signed in: \(user.isEmailVerified)")
        var image: String!
        let name = user.displayName ?? " "
        if let profile_pic = user.photoURL{
            do{
                let data = try Data(contentsOf: profile_pic)
                image = data.base64EncodedString(options: .endLineWithLineFeed)
                
            }catch {
                print("in google VC Unable to load profile image: \(error)")
            }
        }
        var params = [
            "platform": "ios",
            "name": name,
        ]
        if let image = image{
            params["image"] = image
        }
        DataSource.callAPI(url: API.SignIn, params: params, onComplete: {data, statusCode, error in
            guard let data = data, error == nil else{
                print("signin error")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            print("signin response: \(responseJSON)")
            if let json = responseJSON as? [String: Any]{
                if json.keys.contains("error"){
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        self.showToast("Unable to login, please try again later.")
                    }
                }else{
                    Defaults.setUserId(value: json["user_id"] as! String)
                    Defaults.setUserName(value: json["name"] as! String)
                    if json.keys.contains("imageUrl"), let imageUrl = json["imageUrl"] as? String{
                        Defaults.setUserImage(value: URL.init(string: imageUrl)!)
                    }
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        (UIApplication.shared.delegate as! AppDelegate).configureS3()
                        (UIApplication.shared.delegate as! AppDelegate).loadHome()
                    }
                }
                
            }else{
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showToast("Unable to login, please try again later.")
                }
            }
        })
    }
}
