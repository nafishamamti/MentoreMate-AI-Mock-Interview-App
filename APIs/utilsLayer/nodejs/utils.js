var cfsign = require('aws-cloudfront-sign');
const cloudfrontURL = 'https://somevalue.cloudfront.net/';
const cloudfrontUserURL = 'https://somevalue.cloudfront.net/';
const admin = require('firebase-admin');
const serviceAccount = require("credentials.json");
const fireBaseAuth = require('firebase-admin/auth');

const signingParams = {
   //***
};
  

const mysql = require('serverless-mysql')({
  config: {
    //***
  }
});

module.exports.connection = async function () {
    mysql.connect((err) => {
      if (err) throw err;
      console.log('Connected!');
    });
    console.log(mysql);
    return new Promise((resolve) => {
      resolve(mysql);
    });
};

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
});

module.exports.verifyToken = async function (token) {
    let _payload;
    try {
        _payload = await fireBaseAuth.getAuth().verifyIdToken(token);
        console.log({ _payload });
    }catch (e) {
        _payload = {};
        _payload["error"] = e;
    }
    return new Promise((resolve) => {
        resolve(_payload)
    });
}

module.exports.verifyAccess = async function (token, user_id){
    let jsonData = {}
    const result = await this.verifyToken(token);
    console.log({result});
    if (result.error) {
        jsonData["error"] = result.error.code;
        jsonData["auth"] = "auth";
    } else if (result.email) {
        if (result.email_verified == true) {
            const query = "select id from user_tbl where id = " + user_id + " and " + " email = '" + result.email + "'";
            const _result = await new Promise((resolve, reject) => {
                mysql.query(query, function (error, results) {
                    if (error)
                        return reject(error);
                    resolve(results);
                });
            });
            if(_result.length > 0){
                jsonData.user_id = user_id;
                jsonData.firebase_user_id = result.user_id;
            }else{
                jsonData.error = "Invalid access";
            }
            mysql.quit();
        } else {
            jsonData["error"] = "Email is not verified";
        }
    } else {
        jsonData["error"] = "Invalid access";
    }
    return new Promise((resolve, reject) => {
        if(jsonData.error){
            reject(jsonData);
        }else{
            resolve(jsonData);
        }
    });
}

module.exports.getUserUrl = function (user_id) {
    var usersigningParams = {
        //***
      };
      const path = "users/mm_" + user_id + ".webp";
      return cfsign.getSignedUrl(
        cloudfrontUserURL + path,
        usersigningParams
      );
};

module.exports.getFileUrl = function (path) {
    return cfsign.getSignedUrl(
      cloudfrontURL + path,
      signingParams
    );
};

module.exports.getBodyParams = function (body) {
    var bodyParams = {};
    let decodedBody = Buffer.from(body, 'base64').toString('ascii').split('&');
    for (var i = 0; i < decodedBody.length; i++) {
      var bits = decodedBody[i].split('=');
      bodyParams[bits[0]] = bits[1];
    }
    return bodyParams;
};

module.exports.getDecodeString = function (str) {
    return decodeURIComponent(str.replace(/\+/g, " "));
};