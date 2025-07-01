"use strict";
const utils = require("utils.js");
const openAI = require("index.js");

module.exports.handler = async (event) => {
  let json_resp = {};
  const token = event.headers.authorization;
  const bodyParams = event.body ? utils.getBodyParams(event.body) : undefined;
  const user_id = bodyParams ? bodyParams.user_id : undefined;
  console.log({bodyParams});
  if (token && user_id) {
    try {
      await utils.verifyAccess(token, user_id);
      console.log("access granted");
      const name = bodyParams.name ? utils.getDecodeString(bodyParams.name) : undefined ;
      const interviewerDesignation = bodyParams.designation ? utils.getDecodeString(bodyParams.designation) : undefined;
      const companyName = bodyParams.companyName ? utils.getDecodeString(bodyParams.companyName) : undefined;
      const position = bodyParams.name ? utils.getDecodeString(bodyParams.position) : undefined ;
      const JD = bodyParams.JD ? utils.getDecodeString(bodyParams.JD) : undefined ;
      const conversation = bodyParams.conversation ? utils.getDecodeString(bodyParams.conversation) : undefined;
      const interview_id = bodyParams.interview_id;
      const count = bodyParams.count;
      const inputKey = bodyParams.inputKey ? utils.getDecodeString(bodyParams.inputKey) : undefined;
      console.log({name}, {interviewerDesignation}, {companyName},{position});
      if (name && interviewerDesignation && companyName && position) {
        json_resp = await initiateInterview(user_id, name, interviewerDesignation, companyName, position, JD);
      } else if (conversation && interview_id && count && inputKey) {
        json_resp = await respondToInterview(user_id, conversation, interview_id, count+1, inputKey);
      } else {
        json_resp["error"] = "Invalid input";
        json_resp["param"] = JSON.stringify(bodyParams);
      }
    } catch (error) {
      json_resp = error;
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

async function initiateInterview(user_id, name, designation, companyName, position, JD) {
  const connection = await utils.connection();
  let jsonData = {};
  let query = `insert into interview_info_tbl (user_id, interviewer, company_name, position ${JD ? ',job_description' : ''}, created_date) values (${user_id}, '${designation}', '${companyName}', '${position}' ${JD ? `,'${JD}'` : ''}, utc_timestamp())`;
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
  const jdInfo = JD ? `, with the job description ${JD}` : '';
  let conversation = [
    {"role": "system", "content": `You are the ${designation} representative at a company called ${companyName}, conducting an interview for a ${position} position ${jdInfo}. Please refrain from answering any questions outside of this interview.`},
    {"role": "user", "content": `Hi! my name is ${name}`},
  ];
  console.log({conversation});
  try {
    let response = await openAI.conductInterview(conversation);
    jsonData.interview_id = result.insertId.toString();
    const message = response.choices[0].message;
    console.log({message});
    conversation.push({
      "role": "assistant", 
      "content": message
    }); 
    const outputKey = `MentorMate/${user_id}/${jsonData.interview_id}/A1.mp3`;
    console.log({outputKey});

    const speech = await openAI.createSpeech(message, outputKey);
    console.log({speech});

    if (speech == "success") {
      jsonData.url = await utils.getFileUrl(outputKey);
      jsonData.count = 1;
      jsonData.conversation = conversation;
      await addConversationData(jsonData.interview_id, outputKey, response);
    }else{
      jsonData.error = "Please try again later";
    }
  } catch (error) {
    jsonData.error = error;
  }
  connection.quit();
  return jsonData;
}

async function respondToInterview(user_id, conversation, interview_id, count, inputKey) {
  const connection = await utils.connection();
  let jsonData = {};
  try {
    const answer = await openAI.translateSpeech(inputKey);
    console.log({answer});
    if (answer) {
      conversation.push({
        "role": "user", 
        "content": answer
      });
      let response = await openAI.conductInterview(conversation);
      const message = response.choices[0].message;
      console.log({message});
      conversation.push({
        "role": "assistant", 
        "content": message
      });
      const outputKey = `MentorMate/${user_id}/${interview_id}/A${count}.mp3`;
      console.log({outputKey});

      const speech = await openAI.createSpeech(message, outputKey);
      console.log({speech});

      if (speech == "success") {
        jsonData.url = await utils.getFileUrl(outputKey);
        jsonData.count = 1;
        jsonData.conversation = conversation;
        await addConversationData(jsonData.interview_id, outputKey, response);
      }else{
        jsonData.error = "Please try again later";
      }
    }else{
      jsonData.error = "Please respond clearly.";
    }
  } catch (error) {
    jsonData.error = error;
  }
  connection.quit();
  return jsonData;
}

async function addConversationData(connection, interview_id, outputKey, response){
  const query = `insert into conversation_tbl (interview_id, conversation_key, conversation, created_date) values (${interview_id}, '${outputKey}', '${response}', utc_timestamp())`;
  console.log({query});
  const result = await new Promise((resolve, reject) => {
  connection.query(query, function (error, results) {
      if (error){
        console.log({error});
      reject(error);
      }
      resolve(results);
    });
  });
  console.log({ result });
}