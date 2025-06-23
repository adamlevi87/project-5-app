require('dotenv').config();
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

AWS.config.update({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION,
  endpoint: process.env.AWS_ENDPOINT
});

const sqs = new AWS.SQS();
const s3 = new AWS.S3();

async function pollQueue() {
  console.log("Polling for messages...");
  const params = {
    QueueUrl: process.env.SQS_QUEUE_URL,
    MaxNumberOfMessages: 1,
    WaitTimeSeconds: 3
  };

  try {
    const data = await sqs.receiveMessage(params).promise();
    if (!data.Messages || data.Messages.length === 0) {
      return;
    }

    const message = data.Messages[0];
    const body = message.Body;

    const s3Params = {
      Bucket: process.env.S3_BUCKET_NAME,
      Key: `messages/${uuidv4()}.json`,
      Body: body,
      ContentType: 'application/json'
    };

    await s3.putObject(s3Params).promise();
    console.log('Saved message to S3.');

    await sqs.deleteMessage({
      QueueUrl: process.env.SQS_QUEUE_URL,
      ReceiptHandle: message.ReceiptHandle
    }).promise();
    console.log('Deleted message from queue.');
  } catch (err) {
    console.error('Error:', err);
  }
}

setInterval(pollQueue, 5000);