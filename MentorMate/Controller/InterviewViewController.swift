
import UIKit
import SDWebImageWebPCoder

class InterviewViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameLable: UILabel!
    @IBOutlet weak var emailLable: UILabel!
    
    @IBOutlet weak var companyNameTF: UITextField!
    @IBOutlet weak var interviewerTF: UITextField!
    @IBOutlet weak var positionTF: UITextField!
    @IBOutlet weak var JDTV: UITextView!
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var url: URL!
    var conversation: [[String: String]]!


    override func viewDidLoad() {
        super.viewDidLoad()
        if let image = Defaults.getUserImage(){
            imageView.sd_setImage(with: image)
        }
        nameLable.text = Defaults.getUserName()
        emailLable.text = Defaults.getUserEmail()
        imageView.layer.cornerRadius = 50
        imageView.layer.masksToBounds = true
        
//        NotificationCenter.default.addObserver(self, selector: #selector(updateTextView(notification:)), name: UIApplication.keyboardWillChangeFrameNotification, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(updateTextView(notification:)), name: UIApplication.keyboardWillHideNotification, object: nil)
        
        companyNameTF.addDoneButtonOnKeyboard()
        interviewerTF.addDoneButtonOnKeyboard()
        positionTF.addDoneButtonOnKeyboard()
        addDoneButtonOnKeyboard()
        closeKeyboardTouchAnywhere()
    }
    
    @IBAction func beginInterview(_ sender: Any){
        var begin = true
        var params = [
            "name": Defaults.getUserName()!,
            "user_id": Defaults.getUserId()!,
        ]
        
        if let companyName = companyNameTF.text{
            if companyName.isEmpty{
                begin = false
                showToast("Please enter company name")
            }else{
                params["companyName"] = companyName
            }
            
        }
        if let interviewer = interviewerTF.text{
            if interviewer.isEmpty{
                begin = false
                showToast("Please enter the interviewer")
            }else{
                params["designation"] = interviewer
            }
        }
        if let position = positionTF.text{
            if position.isEmpty{
                begin = false
                showToast("Please enter the job position")
            }else{
                params["position"] = position
            }
        }
        
        if begin{
            if let jd = JDTV.text, !jd.isEmpty{
                params["JD"] = jd
            }
            submitInformation(param: params as [String : Any])
        }
    }

    fileprivate func submitInformation(param: [String: Any]){
        print(param)
        activityIndicator.startAnimating()
        DataSource.callAPI(url: API.ConductInterview, params: param, onComplete: {data, statusCode, error in
            guard let data = data, error == nil else{
                print("submitInformation error")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            print("submitInformation response: \(responseJSON)")
            if let json = responseJSON as? [String: Any]{
                if !json.keys.contains("url"){
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                        self.showToast("Unable to proceed, please try again later.")
                    }
                }else{
                    DispatchQueue.main.async { [self] in
                        self.activityIndicator.stopAnimating()
                        if json.keys.contains("url"){
                            self.url = URL.init(string: json["url"] as! String)
                            self.conversation = json["conversation"] as? [[String: String]]
                            print("url: \(url)")
                            print("convo: \(conversation)")
                            performSegue(withIdentifier: "interviewSegue", sender: self)
                        }
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
    
    func addDoneButtonOnKeyboard(){
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.doneButtonAction))
        
        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.sizeToFit()
        
        JDTV.inputAccessoryView = doneToolbar
    }
    
    @objc func doneButtonAction(){
        JDTV.resignFirstResponder()
    }
    
    func closeKeyboardTouchAnywhere(){
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func updateTextView(notification: Notification){
        if let userInfo = notification.userInfo{
            let keyboardFrameScreenCoordinates = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
            
            let keyboardFrame = self.view.convert(keyboardFrameScreenCoordinates, to: view.window)
            
            if notification.name == UIApplication.keyboardWillHideNotification{
                view.frame.origin.y = 250
            }
            else{
                view.frame.origin.y = -keyboardFrame.height
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "interviewSegue", let vc = segue.destination as? ConversationViewController{
            vc.url = url
            vc.conversation = conversation
        }
    }
}
