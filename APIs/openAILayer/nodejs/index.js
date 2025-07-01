"use strict";
const OpenAI = require("openai");
const fs = require("fs");
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const stream = require('stream');
const bucket = "picaggo-app";
const OPENAIAccount = require("open-ai-key.json");

const OPENAI_API_KEY = OPENAIAccount.key;

const AI = new OpenAI({
    apiKey: OPENAI_API_KEY,
});

module.exports.conductInterview = async function (conversation){
    console.log("conductInterview: ", {conversation});
    try {
        const completion = await AI.chat.completions.create({
            messages: conversation ,
            model: "gpt-4o-mini",
            user:"mm_1",
          });
        return new Promise((resolve) => {
            resolve (completion);
        });
    } catch (error) {
        console.log("conductInterview error: ",{ error });
        return new Promise((reject) => {
            reject(error);
        });
    }
}

module.exports.createSpeech = async function (message, outputKey) {
    console.log("createSpeech: ", {outputKey}, {message});
    let error;
    try {
        const mp3 = await AI.audio.speech.create({
            model: "tts-1",
            voice: "alloy",
            input: message,
        });
        const buffer = Buffer.from(await mp3.arrayBuffer());
        let destparams = {
            Bucket: bucket,
            Key: outputKey,
            Body: buffer,
            ContentType: "audio/mp3"
          };
        let putResult = await s3.putObject(destparams).promise();
        console.log({ putResult });
        console.log("done");
    } catch (err) {
        console.log("createSpeech error: ",{ err });
        error = err;
    }
    return new Promise((resolve, reject) => {
        if (error) reject(error);
        else resolve ("success");
    });
} 

module.exports.translateSpeech = async function (inputKey) {
    console.log("translateSpeech: ", {inputKey});
    try {
        var params = { Bucket: bucket, Key: inputKey };
        const translation = await AI.audio.translations.create({
            file: s3.getObject(params).createReadStream(),
            model: "whisper-1",
        });
        return new Promise((resolve) => {
            resolve (translation);
        });
    } catch (error) {
        console.log("translateSpeech error: ",{ error });
        return new Promise((reject) => {
            reject(error);
        });
    }
}

