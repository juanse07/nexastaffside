

import cors from 'cors';
import 'dotenv/config';
import type { Request, Response } from 'express';
import express from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { getMongoClient } from './db/mongoClient.js';
import authRouter from './features/auth/routes.js';
import eventsRouter from './features/events/routes.js';
import usersRouter from './features/users/routes.js';

const app = express();
app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));

app.use('/events', eventsRouter);
app.use('/auth', authRouter);
app.use('/users', usersRouter);
// Also mount under /api/* to support deployments that prefix routes
app.use('/api/events', eventsRouter);
app.use('/api/auth', authRouter);
app.use('/api/users', usersRouter);

app.get('/health', (_req: Request, res: Response) => {
  res.json({ ok: true, service: 'backend', timestamp: new Date().toISOString() });
});
// Common healthz path used by orchestrators/proxies
app.get('/healthz', (_req: Request, res: Response) => {
  res.status(200).send('OK');
});

const port = process.env.PORT || 4000;

(async () => {
  try {
    const client = await getMongoClient();
    await client.db().admin().ping();
    console.log('Connected to MongoDB');

    app.listen(port, () => {
      console.log(`Server listening on port ${port}`);
    });
  } catch (error) {
    console.error('Failed to start server', error);
    process.exit(1);
  }
})();
