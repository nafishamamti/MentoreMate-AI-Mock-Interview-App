import Foundation

class Defaults{
    static let defaults = UserDefaults.init(suiteName: "MentorMate") ?? UserDefaults.init()
    static let USER_ID = "user_id"
    static let EMAIL = "email"
    static let PROFILE_IMAGE = "profileImage"
    static let INTERVIEW_ID = "interviewId"
    static let CONVERSATION_COUNT = "conversationCount"
    static let USER_NAME = "userName"
    
    static func resetValues(){
        defaults.removeObject(forKey: USER_ID)
        defaults.removeObject(forKey: EMAIL)
        defaults.removeObject(forKey: PROFILE_IMAGE)
        defaults.removeObject(forKey: INTERVIEW_ID)
        defaults.removeObject(forKey: CONVERSATION_COUNT)
    }
    
    static func setUserId(value: String){
        defaults.set(value, forKey: USER_ID)
        defaults.synchronize()
    }
    
    static func getUserId()->String?{
        return defaults.string(forKey: USER_ID)
    }
    
    static func setUserName(value: String){
        defaults.set(value, forKey: USER_NAME)
        defaults.synchronize()
    }
    
    static func getUserName()->String?{
        return defaults.string(forKey: USER_NAME)
    }
    
    static func setUserEmail(value: String){
        defaults.set(value, forKey: EMAIL)
        defaults.synchronize()
    }
    
    static func getUserEmail()->String?{
        return defaults.string(forKey: EMAIL)
    }
    
    static func setUserImage(value: URL){
        defaults.set(value, forKey: PROFILE_IMAGE)
        defaults.synchronize()
    }
    
    static func getUserImage()->URL?{
        return defaults.url(forKey: PROFILE_IMAGE)
    }
    
    static func setInterviewId(value: String){
        defaults.set(value, forKey: INTERVIEW_ID)
        defaults.synchronize()
    }
    
    static func getInterviewId()->String?{
        return defaults.string(forKey: INTERVIEW_ID)
    }
    
    static func setConversationCount(value: Int){
        defaults.set(value, forKey: CONVERSATION_COUNT)
        defaults.synchronize()
    }
    
    static func getConversationCount()->Int{
        return defaults.integer(forKey: CONVERSATION_COUNT)
    }
}

