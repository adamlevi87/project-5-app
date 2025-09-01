// local/docker-compose/docker/lambda-mock/index.js
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';
import { randomUUID } from 'crypto';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Initialize AWS clients for LocalStack
const s3Client = new S3Client({
    endpoint: process.env.S3_ENDPOINT || 'http://localstack:4566',
    region: process.env.AWS_REGION || 'us-east-1',
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test'
    },
    forcePathStyle: true // Required for LocalStack
});

const sqsClient = new SQSClient({
    endpoint: process.env.SQS_ENDPOINT || 'http://localstack:4566',
    region: process.env.AWS_REGION || 'us-east-1',
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'test',
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'test'
    }
});

const QUEUE_URL = process.env.SQS_QUEUE_URL || 'http://localstack:4566/000000000000/messages-queue';
const S3_BUCKET = process.env.S3_BUCKET || 'app-data-bucket';
const POLL_INTERVAL = parseInt(process.env.POLL_INTERVAL || '5000');

console.log('🚀 Lambda Mock starting up...');
console.log(`📬 Polling SQS queue: ${QUEUE_URL}`);
console.log(`🪣 Writing to S3 bucket: ${S3_BUCKET}`);
console.log(`⏰ Poll interval: ${POLL_INTERVAL}ms`);

async function pollSQS() {
    try {
        const receiveCommand = new ReceiveMessageCommand({
            QueueUrl: QUEUE_URL,
            MaxNumberOfMessages: 10,
            WaitTimeSeconds: 20,  // Long polling
            MessageAttributeNames: ['All'],
            AttributeNames: ['All']
        });

        const result = await sqsClient.send(receiveCommand);
        
        if (result.Messages && result.Messages.length > 0) {
            console.log(`📨 Received ${result.Messages.length} message(s) from SQS`);
            
            // Process messages in parallel
            const processPromises = result.Messages.map(message => processMessage(message));
            const results = await Promise.allSettled(processPromises);
            
            // Log any failures
            const failures = results.filter(result => result.status === 'rejected');
            if (failures.length > 0) {
                console.error(`❌ Failed to process ${failures.length} messages:`, 
                    failures.map(f => f.reason?.message || f.reason));
            }
            
            const successCount = results.filter(result => result.status === 'fulfilled').length;
            console.log(`✅ Successfully processed ${successCount} message(s)`);
        }
    } catch (error) {
        console.error('❌ Error polling SQS:', error.message);
    }
}

async function processMessage(message) {
    const messageId = message.MessageId;
    console.log(`🔄 Processing message: ${messageId}`);
    
    try {
        // Parse message body
        const messageBody = JSON.parse(message.Body);
        console.log('📄 Message content:', messageBody);
        
        // Create S3 object key with timestamp and unique ID
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const key = `messages/${timestamp}-${randomUUID()}.json`;
        
        // Prepare S3 object data
        const objectData = {
            messageId: messageId,
            timestamp: new Date().toISOString(),
            originalMessage: messageBody,
            processedBy: 'lambda-mock-nodejs22',
            sqsAttributes: message.Attributes || {},
            messageAttributes: message.MessageAttributes || {}
        };
        
        // Create PutObject command
        const putCommand = new PutObjectCommand({
            Bucket: S3_BUCKET,
            Key: key,
            Body: JSON.stringify(objectData, null, 2),
            ContentType: 'application/json',
            Metadata: {
                'message-id': messageId,
                'processed-at': new Date().toISOString(),
                'processor': 'lambda-mock'
            }
        });
        
        // Save to S3
        console.log(`💾 Saving to S3: ${S3_BUCKET}/${key}`);
        await s3Client.send(putCommand);
        
        // Delete message from queue
        const deleteCommand = new DeleteMessageCommand({
            QueueUrl: QUEUE_URL,
            ReceiptHandle: message.ReceiptHandle
        });
        
        await sqsClient.send(deleteCommand);
        console.log(`🗑️  Deleted message ${messageId} from SQS`);
        
        return { messageId, status: 'success', s3Key: key };
        
    } catch (error) {
        console.error(`❌ Error processing message ${messageId}:`, error.message);
        throw error;
    }
}

// Start polling
console.log('🎯 Starting SQS polling...');
const pollLoop = async () => {
    while (true) {
        await pollSQS();
        await new Promise(resolve => setTimeout(resolve, POLL_INTERVAL));
    }
};

// Handle graceful shutdown
process.on('SIGINT', () => {
    console.log('🛑 Received SIGINT, shutting down gracefully...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    console.log('🛑 Received SIGTERM, shutting down gracefully...');
    process.exit(0);
});

// Start the polling loop
pollLoop().catch(error => {
    console.error('💥 Fatal error in poll loop:', error);
    process.exit(1);
});