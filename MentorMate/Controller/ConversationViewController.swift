import UIKit
import AVKit

class ConversationViewController: UIViewController {
    
    @IBOutlet weak var recordBtn: UIButton!
    @IBOutlet weak var sendBtn: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var containerView: UIView!
    
    var conversation: [[String:String]]!
    var url: URL!
    
    var avPlayer: AVPlayer!
    var playerVC: AVPlayerViewController!
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
    }
    
    @IBAction func record(_ sender: Any){
        activityIndicator.startAnimating()
        recordBtn.isHidden = true
        sendBtn.isHidden = false
    }

    @IBAction func send(_ sender: Any){
        activityIndicator.startAnimating()
        recordBtn.isHidden = false
        sendBtn.isHidden = true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "playerSegue", let vc = segue.destination as? AVPlayerViewController{
            playerVC = vc
            avPlayer = AVPlayer(url: url)
            playerVC.player = avPlayer
            playerVC.player?.play()
        }
    }
}
