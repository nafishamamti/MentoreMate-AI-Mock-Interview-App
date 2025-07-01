"use strict";
const utils = require("utils.js");
const s3Utility = require("s3ImageUtils.js");

module.exports.handler = async (event) => {
  let json_resp = {};
  const token = event.headers.authorization;
  const bodyParams = event.body ? utils.getBodyParams(event.body) : undefined;
  console.log({bodyParams});
  if (token) {
    const result = await utils.verifyToken(token);
    console.log({ result });
    if (result.error) {
        json_resp = {};
        json_resp.error = result.error.code;
        json_resp.auth = "auth";
      } else if (result.email && bodyParams) {
        // const provider = result.firebase.sign_in_provider.replace(".com","") ;
        const image = bodyParams ? bodyParams.image ? utils.getDecodeString(bodyParams.image) : undefined : undefined;
        const name = bodyParams ? bodyParams.name ? utils.getDecodeString(bodyParams.name) : undefined : undefined;
        const platform = bodyParams.platform;
        json_resp = await signIn(result.email, name, image, platform);
      } else {
        json_resp.error = "Invalid input";
      }
  }else{
      json_resp.error = "Invalid Access";
  }
  console.log({ json_resp });
  return new Promise((resolve) => {
    const response = {
      statusCode: 200,
      body: JSON.stringify(json_resp),
      headers: {
        "Strict-Transport-Security": "max-age=63072000; includeSubdomains; preload",
        "Content-Security-Policy": "default-src 'none'; img-src 'self'; script-src 'self'; style-src 'self'; object-src 'none'",
        "X-Content-Type-Options": 'nosniff',
        "X-Frame-Options": "DENY",
        "X-XSS-Protection": "1; mode=block",
        'Access-Control-Allow-Origin': '*, http://localhost:4200',
        'Access-Control-Allow-Methods': 'POST',
        'Access-Control-Allow-Headers': 'Authorization, *',
        "Referrer-Policy" : "same-origin"
      },
    };
    resolve(response);
  });
};

async function signIn(email, name, image, platform) {
  const connection = await utils.connection();
  let jsonData = {};
  let user_id;
  let query = `select id, name, image from user_tbl where email = '${email}'`;
  console.log({query});
  let result = await new Promise((resolve, reject) => {
      connection.query(query, function (error, results) {
        if (error){
          console.log({error});
          reject(error);
        }
        resolve(results);
      });
  });
  console.log({ result });
  if (result.length == 0) { //sign up 
    if (name == undefined || name.trim().length == 0) {
      name = email.split('@')[0];
    }
    console.log({name});
    const imageSet = image ? 1 : 0;
    query = `insert into user_tbl (name, email, image, login_date, created_date, platform) values ('${name}', '${email}', ${imageSet}, utc_timestamp(), utc_timestamp(), '${platform}')`;
    console.log({query});
    result = await new Promise((resolve, reject) => {
        connection.query(query, function (error, results) {
          if (error){
            console.log({error});
            reject(error);
          }
          resolve(results);
        });
    });
    console.log({ result });
    if (result.insertId > 0) {
      jsonData.result = "success";
      user_id = result.insertId;
      jsonData.user_id = user_id.toString();
      jsonData.name = name;
      if (imageSet) {
        //save in s3
        await s3Utility.saveProfilePic(`mm_${user_id}`, image, 100, 150);
        console.log("image saved");
        jsonData.imageUrl = utils.getUserUrl(user_id);
      }
  }else {
      jsonData.error = "unable to sign up";
  }
  }else{
    user_id = result[0].id;
    jsonData.user_id = user_id.toString();
    jsonData.name = result[0].name;
    if (result[0].image) {
      jsonData.imageUrl = utils.getUserUrl(user_id);
    }
    jsonData.result = "success";
    query = `update user_tbl set login_date = utc_timestamp() where id = ${user_id}`;
    console.log({query});
    result = await new Promise((resolve, reject) => {
      connection.query(query, function (error, results, fields) {
        if (error){
          console.log({error});
          reject(error);
        }
        resolve(results);
      });
    });
    console.log({ result });
  }
  connection.quit();
  return jsonData;
}

