const express = require('express');
const { Pool } = require('pg');
const AWS = require('aws-sdk');

// Load env vars
require('dotenv').config();

const app = express();
app.use(express.json());

// PostgreSQL connection
const db = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

// AWS SQS setup
const sqs = new AWS.SQS({
  region: process.env.AWS_REGION,
  endpoint: process.env.SQS_QUEUE_URL.startsWith("http") ? process.env.SQS_QUEUE_URL.split("/000000000000")[0] : undefined,
  accessKeyId: "test",
  secretAccessKey: "test",
});

// POST /submit
app.post('/submit', async (req, res) => {
  const { text } = req.body;
  if (!text) return res.status(400).send({ error: 'Missing text field' });

  try {
    // Save to DB
    await db.query('INSERT INTO messages (content) VALUES ($1)', [text]);

    // Send to SQS
    await sqs.sendMessage({
      QueueUrl: process.env.SQS_QUEUE_URL,
      MessageBody: JSON.stringify({ text }),
    }).promise();

    res.status(200).send({ message: 'Text received and processed' });
  } catch (err) {
    console.error(err);
    res.status(500).send({ error: 'Internal server error' });
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Backend listening on port ${PORT}`));