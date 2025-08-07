const express = require('express');
const { Pool } = require('pg');
const AWS = require('aws-sdk');
const cors = require('cors');

// Load env vars
require('dotenv').config();

const app = express();

app.use(express.json()); //

const origins = ['http://localhost'];

// Log what BACKEND_HOST_ADDRESS is (for debugging)
console.log('CORS BACKEND_HOST_ADDRESS:', process.env.BACKEND_HOST_ADDRESS);

if (process.env.BACKEND_HOST_ADDRESS) {
  origins.push(`http://${process.env.BACKEND_HOST_ADDRESS}`);
  origins.push(`https://${process.env.BACKEND_HOST_ADDRESS}`);
}

// Log what FRONTEND_HOST_ADDRESS is (for debugging)
console.log('CORS FRONTEND_HOST_ADDRESS:', process.env.FRONTEND_HOST_ADDRESS);

if (process.env.FRONTEND_HOST_ADDRESS) {
  origins.push(`http://${process.env.FRONTEND_HOST_ADDRESS}`);
  origins.push(`https://${process.env.FRONTEND_HOST_ADDRESS}`);
}

app.use(cors({ origin: origins }));

// PostgreSQL connection
const config  = {
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
};

const isProd = process.env.NODE_ENV === 'production';

const ssl = isProd
  ? { rejectUnauthorized: false }  // enables SSL (but skips cert verification — common in dev)
  : false;                         // disables SSL entirely for local

console.log("Connecting to DB at:", config.host, "with user:", config.user);
const db = new Pool({ ...config, ssl });


// AWS SQS setup
const sqs = new AWS.SQS({
  region: process.env.AWS_REGION,
  endpoint: !isProd
    ? process.env.SQS_QUEUE_URL.split("/000000000000")[0]
    : undefined,
  ...(isProd
    ? {}
    : {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
      }),
});


// POST /submit
const TABLE_NAME = process.env.POSTGRES_TABLE || 'messages';

const initDatabase = async () => {
  try {
    console.log(`Initializing database schema for table: ${TABLE_NAME}`);
    await db.query(`
      CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
        id SERIAL PRIMARY KEY,
        content TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);
    console.log(`Database schema initialized successfully for table: ${TABLE_NAME}`);
  } catch (error) {
    console.error('Failed to initialize database:', error);
    process.exit(1);
  }
};

// SQL Injection protection, value can only be text
if (!/^[a-zA-Z0-9_]+$/.test(TABLE_NAME)) {
  throw new Error('Invalid table name');
}

app.post('/submit', async (req, res) => {
  const { text } = req.body;
  if (!text) return res.status(400).send({ error: 'Missing text field' });

  try {
    // Save to DB
    await db.query(`INSERT INTO ${TABLE_NAME} (content) VALUES ($1)`, [text]);

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

// GET /health for readiness/liveness probes
app.get('/health', (req, res) => {
  res.sendStatus(200);
});

// Catch-all for unhandled routes
app.use((req, res) => {
  res.status(404).send({ error: 'Not Found' });
});

// Start server
initDatabase().then(() => {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => console.log(`Backend listening on port ${PORT}`));
}).catch(error => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
