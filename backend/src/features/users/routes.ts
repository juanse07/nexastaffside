import { Router, type Request, type Response } from 'express';
import { z } from 'zod';
import { requireAuth } from '../auth/middleware.js';
import { getMongoClient } from '../../db/mongoClient.js';

const router = Router();

// US phone number validation schema
// Accepts: (XXX) XXX-XXXX, XXX-XXX-XXXX, or XXXXXXXXXX (10 digits)
const phoneSchema = z
  .string()
  .regex(
    /^(\(\d{3}\)\s?\d{3}-\d{4}|\d{3}-\d{3}-\d{4}|\d{10})$/,
    'Phone number must be in US format: (XXX) XXX-XXXX, XXX-XXX-XXXX, or XXXXXXXXXX'
  )
  .optional();

const updateProfileSchema = z.object({
  firstName: z.string().min(1).max(100).optional(),
  lastName: z.string().min(1).max(100).optional(),
  phoneNumber: phoneSchema,
  appId: z.string().max(100).optional(),
  picture: z.string().url().optional(),
});

// GET /users/me - Fetch current user profile
router.get('/me', requireAuth, async (req: Request, res: Response) => {
  try {
    const authUser = req.user!;
    const client = await getMongoClient();
    const users = client.db().collection('users');

    const user = await users.findOne({
      provider: authUser.provider,
      subject: authUser.sub,
    });

    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Return user profile
    res.json({
      id: user._id.toString(),
      email: user.email,
      firstName: user.first_name,
      lastName: user.last_name,
      name: user.name,
      picture: user.picture,
      appId: user.app_id,
      phoneNumber: user.phone_number,
    });
  } catch (error) {
    console.error('Error fetching user profile:', error);
    res.status(500).json({ error: 'Failed to fetch user profile' });
  }
});

// PATCH /users/me - Update current user profile
router.patch('/me', requireAuth, async (req: Request, res: Response) => {
  try {
    const authUser = req.user!;

    // Validate request body
    const validation = updateProfileSchema.safeParse(req.body);
    if (!validation.success) {
      return res.status(400).json({
        error: 'Validation failed',
        details: validation.error.issues,
      });
    }

    const { firstName, lastName, phoneNumber, appId, picture } = validation.data;

    // Build update object
    const updateFields: any = {
      updatedAt: new Date(),
    };

    if (firstName !== undefined) updateFields.first_name = firstName;
    if (lastName !== undefined) updateFields.last_name = lastName;
    if (phoneNumber !== undefined) updateFields.phone_number = phoneNumber;
    if (appId !== undefined) updateFields.app_id = appId;
    if (picture !== undefined) updateFields.picture = picture;

    const client = await getMongoClient();
    const users = client.db().collection('users');

    const result = await users.findOneAndUpdate(
      {
        provider: authUser.provider,
        subject: authUser.sub,
      },
      { $set: updateFields },
      { returnDocument: 'after' }
    );

    if (!result) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Return updated user profile
    res.json({
      id: result._id.toString(),
      email: result.email,
      firstName: result.first_name,
      lastName: result.last_name,
      name: result.name,
      picture: result.picture,
      appId: result.app_id,
      phoneNumber: result.phone_number,
    });
  } catch (error) {
    console.error('Error updating user profile:', error);
    res.status(500).json({ error: 'Failed to update user profile' });
  }
});

export default router;
