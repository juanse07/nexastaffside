import { Router } from 'express';
import { ObjectId } from 'mongodb';
import { getMongoClient } from '../../db/mongoClient.js';
import { requireAuth } from '../auth/middleware.js';

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

// Staff accept/decline response endpoint
router.post('/:id/respond', requireAuth, async (req, res) => {
  try {
    const eventId = req.params.id ?? '';
    const { response, role } = req.body ?? {};
    if (!ObjectId.isValid(eventId)) {
      return res.status(400).json({ message: 'Invalid event id' });
    }
    if (response !== 'accept' && response !== 'decline') {
      return res.status(400).json({ message: "response must be 'accept' or 'decline'" });
    }

    const client = await getMongoClient();
    const db = client.db();
    const events = db.collection('events');
    const users = db.collection('users');

    const staffField = response === 'accept' ? 'accepted_staff' : 'declined_staff';
    const otherField = response === 'accept' ? 'declined_staff' : 'accepted_staff';
    if (!req.user?.provider || !req.user?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    const userKey = `${req.user.provider}:${req.user.sub}`;
    // Debug log for tracing
    console.log('[events/respond]', { eventId, response, role, userKey });

    // Fetch latest user profile details
    const userDoc = await users.findOne({ provider: req.user.provider, subject: req.user.sub });
    const name: string | undefined = (userDoc?.name as string | undefined) ?? req.user.name;
    const email: string | undefined = (userDoc?.email as string | undefined) ?? req.user.email;
    const picture: string | undefined = (userDoc?.picture as string | undefined) ?? req.user.picture;
    const firstName = name ? name.trim().split(/\s+/).slice(0, -1).join(' ') || undefined : undefined;
    const lastName = name ? name.trim().split(/\s+/).slice(-1)[0] || undefined : undefined;

    const staffDoc = {
      userKey,
      provider: req.user.provider,
      subject: req.user.sub,
      email,
      name,
      first_name: firstName,
      last_name: lastName,
      picture,
      response,
      // Optional role context so we know which role was accepted/declined (e.g., bartender)
      role: typeof role === 'string' && role.trim() ? String(role).trim() : undefined,
      respondedAt: new Date(),
    } as const;

    // Remove any previous entries (supporting legacy string entries and new object entries)
    await events.updateOne(
      { _id: new ObjectId(eventId) },
      {
        $pull: {
          accepted_staff: userKey,
          declined_staff: userKey,
        },
      },
    );
    await events.updateOne(
      { _id: new ObjectId(eventId) },
      {
        $pull: {
          accepted_staff: { userKey },
          declined_staff: { userKey },
        },
      },
    );

    // Push the current response object and set updatedAt
    const result = await events.updateOne(
      { _id: new ObjectId(eventId) },
      {
        $push: { [staffField]: staffDoc } as any,
        $set: { updatedAt: new Date() },
      },
      { upsert: false },
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ message: 'Event not found' });
    }

    // Recompute role_stats (capacity/taken/remaining) and persist
    const updated = await events.findOne({ _id: new ObjectId(eventId) });
    if (updated) {
      try {
        const roles: any[] = Array.isArray(updated.roles) ? updated.roles : [];
        const accepted: any[] = Array.isArray(updated.accepted_staff)
          ? updated.accepted_staff
          : [];
        const roleStats = roles.map((r: any) => {
          const roleName = (r?.role ?? '').toString();
          const capacity = Number.parseInt((r?.count ?? 0).toString());
          // Count taken only from object-style entries having a role match
          const taken = accepted.reduce((acc: number, a: any) => {
            if (a && typeof a === 'object' && (a.role ?? '').toString() === roleName) {
              return acc + 1;
            }
            return acc;
          }, 0);
          const remaining = Math.max(0, capacity - taken);
          return { role: roleName, capacity, taken, remaining };
        });
        await events.updateOne(
          { _id: new ObjectId(eventId) },
          { $set: { role_stats: roleStats, updatedAt: new Date() } },
        );
        (updated as any).role_stats = roleStats;
      } catch (e) {
        console.warn('[events/respond] role_stats recompute failed', e);
      }
    }
    return res.json(mapEvent(updated));
  } catch (err) {
    return res.status(500).json({ message: 'Failed to update response' });
  }
});

export default router;


