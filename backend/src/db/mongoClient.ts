import { MongoClient } from 'mongodb';

const mongoUri = process.env.MONGODB_URI || '';
if (!mongoUri) {
  console.warn('MONGODB_URI not set. Set it in .env for local dev.');
}

let cachedClient: MongoClient | null = null;

export async function getMongoClient(): Promise<MongoClient> {
  if (cachedClient) return cachedClient;
  const client = new MongoClient(mongoUri, {});
  await client.connect();
  cachedClient = client;
  return client;
}


