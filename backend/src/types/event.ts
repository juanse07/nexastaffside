import { z } from 'zod';

// Event data structure (types only). Values are not used for logic.
export const EventSchema = z.object({
  id: z.string(), // ObjectId hex string
  event_name: z.string(),
  client_name: z.string(),
  date: z.string(), // ISO date string
  start_time: z.string().nullable(),
  end_time: z.string().nullable(),
  venue_name: z.string(),
  venue_address: z.string(),
  city: z.string(),
  state: z.string(),
  country: z.string(),
  contact_name: z.string(),
  contact_phone: z.string(),
  contact_email: z.string().nullable(),
  setup_time: z.string().nullable(),
  uniform: z.string().nullable(),
  notes: z.string().nullable(),
  headcount_total: z.number().int(),
  roles: z.array(z.unknown()).optional(),
  pay_rate_info: z.unknown().nullable().optional(),
  createdAt: z.string().optional(),
  updatedAt: z.string().optional(),
  __v: z.number().optional(),
});

export type Event = z.infer<typeof EventSchema>;


