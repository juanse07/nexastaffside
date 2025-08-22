import { Router } from 'express';
import { getMongoClient } from '../../db/mongoClient.js';

const router = Router();

function mapEvent(doc: any) {
  const { _id, ...rest } = doc ?? {};
  return { id: String(_id), ...rest };
}

router.get('/', async (_req, res) => {
  try {
    const client = await getMongoClient();
    const items = await client.db().collection('events').find({}).toArray();
    res.json(items.map(mapEvent));
  } catch (err) {
    res.status(500).json({ message: 'Failed to fetch events' });
  }
});

export default router;


