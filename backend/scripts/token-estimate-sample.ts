// Token estimation based on sample event document structure

interface SampleEvent {
  _id: string;
  id: string;
  event_name: string;
  client_name: string;
  date: string;
  start_time: string | null;
  end_time: string | null;
  venue_name: string;
  venue_address: string;
  city: string;
  state: string;
  country: string;
  contact_name: string;
  contact_phone: string;
  contact_email: string | null;
  setup_time: string | null;
  uniform: string | null;
  notes: string | null;
  headcount_total: number;
  roles: Array<{
    role: string;
    count: number;
    visibleForAll?: boolean;
    visibleTo?: string[];
  }>;
  accepted_staff: Array<{
    userKey: string;
    provider: string;
    subject: string;
    email: string;
    name: string;
    first_name: string;
    last_name: string;
    picture: string;
    response: string;
    role?: string;
    respondedAt: string;
  }>;
  declined_staff: Array<any>;
  audience_user_keys: string[];
  audience_team_ids: string[];
  role_stats: Array<{
    role: string;
    capacity: number;
    taken: number;
    remaining: number;
  }>;
  createdAt: string;
  updatedAt: string;
  __v: number;
}

// Token estimation functions
function estimateTokens(text: string): { claude: number; chatgpt: number } {
  const words = text.split(/\s+/).filter(w => w.length > 0);
  let tokenCount = 0;

  for (const word of words) {
    if (word.length <= 4) {
      tokenCount += 1;
    } else if (word.length <= 8) {
      tokenCount += Math.ceil(word.length / 4);
    } else {
      tokenCount += Math.ceil(word.length / 3.5);
    }
  }

  const specialChars = (text.match(/[.,!?;:()\[\]{}"'`]/g) || []).length;
  tokenCount += specialChars * 0.5;

  return {
    claude: Math.ceil(tokenCount),
    chatgpt: Math.ceil(tokenCount * 1.1),
  };
}

// Sample event documents of different sizes
const sampleEvents: SampleEvent[] = [
  // Minimal event (smallest case)
  {
    _id: "507f1f77bcf86cd799439011",
    id: "507f1f77bcf86cd799439011",
    event_name: "Staff Meeting",
    client_name: "ABC Corp",
    date: "2025-11-15T00:00:00.000Z",
    start_time: "09:00",
    end_time: "10:00",
    venue_name: "Main Office",
    venue_address: "123 Main St",
    city: "New York",
    state: "NY",
    country: "USA",
    contact_name: "John Doe",
    contact_phone: "+1-555-0100",
    contact_email: "john@example.com",
    setup_time: null,
    uniform: null,
    notes: null,
    headcount_total: 5,
    roles: [
      { role: "staff", count: 5, visibleForAll: true }
    ],
    accepted_staff: [],
    declined_staff: [],
    audience_user_keys: [],
    audience_team_ids: [],
    role_stats: [
      { role: "staff", capacity: 5, taken: 0, remaining: 5 }
    ],
    createdAt: "2025-11-01T10:00:00.000Z",
    updatedAt: "2025-11-01T10:00:00.000Z",
    __v: 0
  },

  // Medium event
  {
    _id: "507f1f77bcf86cd799439012",
    id: "507f1f77bcf86cd799439012",
    event_name: "Corporate Gala Dinner 2025",
    client_name: "TechCorp International LLC",
    date: "2025-12-20T00:00:00.000Z",
    start_time: "18:00",
    end_time: "23:00",
    venue_name: "Grand Ballroom at The Plaza",
    venue_address: "768 Fifth Avenue at Central Park South",
    city: "New York",
    state: "NY",
    country: "USA",
    contact_name: "Sarah Johnson",
    contact_phone: "+1-555-0123",
    contact_email: "sarah.johnson@techcorp.com",
    setup_time: "15:00",
    uniform: "Black tie, formal attire required",
    notes: "VIP event. All staff must arrive 30 minutes early for briefing. Parking validated in underground garage.",
    headcount_total: 25,
    roles: [
      { role: "bartender", count: 4, visibleForAll: true },
      { role: "server", count: 12, visibleForAll: true },
      { role: "host", count: 3, visibleForAll: true },
      { role: "manager", count: 2, visibleForAll: false, visibleTo: ["google:123456", "google:789012"] },
      { role: "security", count: 4, visibleForAll: true }
    ],
    accepted_staff: [
      {
        userKey: "google:118276598765432109876",
        provider: "google",
        subject: "118276598765432109876",
        email: "mike.smith@example.com",
        name: "Mike Smith",
        first_name: "Mike",
        last_name: "Smith",
        picture: "https://lh3.googleusercontent.com/a/default-user",
        response: "accept",
        role: "bartender",
        respondedAt: "2025-11-05T14:30:00.000Z"
      },
      {
        userKey: "google:223456789012345678901",
        provider: "google",
        subject: "223456789012345678901",
        email: "jane.doe@example.com",
        name: "Jane Doe",
        first_name: "Jane",
        last_name: "Doe",
        picture: "https://lh3.googleusercontent.com/a/default-user",
        response: "accept",
        role: "server",
        respondedAt: "2025-11-06T09:15:00.000Z"
      }
    ],
    declined_staff: [
      {
        userKey: "google:334567890123456789012",
        provider: "google",
        subject: "334567890123456789012",
        email: "bob.wilson@example.com",
        name: "Bob Wilson",
        first_name: "Bob",
        last_name: "Wilson",
        picture: "https://lh3.googleusercontent.com/a/default-user",
        response: "decline",
        respondedAt: "2025-11-04T16:45:00.000Z"
      }
    ],
    audience_user_keys: ["google:118276598765432109876", "google:223456789012345678901"],
    audience_team_ids: ["team_001", "team_002"],
    role_stats: [
      { role: "bartender", capacity: 4, taken: 1, remaining: 3 },
      { role: "server", capacity: 12, taken: 1, remaining: 11 },
      { role: "host", capacity: 3, taken: 0, remaining: 3 },
      { role: "manager", capacity: 2, taken: 0, remaining: 2 },
      { role: "security", capacity: 4, taken: 0, remaining: 4 }
    ],
    createdAt: "2025-11-01T10:00:00.000Z",
    updatedAt: "2025-11-06T09:15:00.000Z",
    __v: 3
  },

  // Large event with extensive details
  {
    _id: "507f1f77bcf86cd799439013",
    id: "507f1f77bcf86cd799439013",
    event_name: "Annual Tech Conference & Expo 2025 - Full Day Experience",
    client_name: "Global Technology Ventures & Innovation Summit LLC",
    date: "2026-03-15T00:00:00.000Z",
    start_time: "07:00",
    end_time: "22:00",
    venue_name: "Metropolitan Convention Center - Hall A, B, C and Exhibition Floor",
    venue_address: "1234 Convention Boulevard, Suite 500, Convention Center Complex",
    city: "San Francisco",
    state: "CA",
    country: "USA",
    contact_name: "Emily Rodriguez-Chen",
    contact_phone: "+1-555-0199",
    contact_email: "emily.rodriguez@globaltech.com",
    setup_time: "05:00",
    uniform: "Business casual with company-branded polo shirt (provided on-site). Comfortable shoes required for extended standing. Hair tied back, minimal jewelry.",
    notes: "Major conference with 2000+ attendees. Multiple sessions running concurrently. All staff must complete online safety training before event day. Meal breaks scheduled: breakfast 6:30-7:00, lunch 12:00-12:30, dinner 18:00-18:30. Emergency contacts: Security (555-0911), Medical (555-0912), Event Coordinator (555-0913). Parking in Lot D with staff permits. Check-in at Staff Command Center on arrival. Union rules apply for overtime after 8 hours.",
    headcount_total: 75,
    roles: [
      { role: "registration_desk", count: 12, visibleForAll: true },
      { role: "session_moderator", count: 8, visibleForAll: false, visibleTo: ["google:admin1", "google:admin2"] },
      { role: "av_technician", count: 10, visibleForAll: true },
      { role: "catering_staff", count: 20, visibleForAll: true },
      { role: "bartender", count: 6, visibleForAll: true },
      { role: "security", count: 8, visibleForAll: true },
      { role: "floor_manager", count: 4, visibleForAll: false, visibleTo: ["google:mgr1"] },
      { role: "exhibitor_support", count: 5, visibleForAll: true },
      { role: "vip_concierge", count: 2, visibleForAll: false, visibleTo: ["google:vip1", "google:vip2"] }
    ],
    accepted_staff: Array.from({ length: 30 }, (_, i) => ({
      userKey: `google:${100000000000000000000 + i}`,
      provider: "google",
      subject: `${100000000000000000000 + i}`,
      email: `staff${i + 1}@example.com`,
      name: `Staff Member ${i + 1}`,
      first_name: `Staff`,
      last_name: `Member${i + 1}`,
      picture: `https://lh3.googleusercontent.com/a/user-${i + 1}`,
      response: "accept",
      role: ["registration_desk", "av_technician", "catering_staff", "bartender", "security"][i % 5],
      respondedAt: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString()
    })),
    declined_staff: Array.from({ length: 5 }, (_, i) => ({
      userKey: `google:${200000000000000000000 + i}`,
      provider: "google",
      subject: `${200000000000000000000 + i}`,
      email: `declined${i + 1}@example.com`,
      name: `Declined Staff ${i + 1}`,
      first_name: `Declined`,
      last_name: `Staff${i + 1}`,
      picture: `https://lh3.googleusercontent.com/a/declined-${i + 1}`,
      response: "decline",
      respondedAt: new Date(Date.now() - Math.random() * 20 * 24 * 60 * 60 * 1000).toISOString()
    })),
    audience_user_keys: Array.from({ length: 50 }, (_, i) => `google:${300000000000000000000 + i}`),
    audience_team_ids: ["team_sf_events", "team_tech_crew", "team_catering", "team_security"],
    role_stats: [
      { role: "registration_desk", capacity: 12, taken: 8, remaining: 4 },
      { role: "session_moderator", capacity: 8, taken: 3, remaining: 5 },
      { role: "av_technician", capacity: 10, taken: 6, remaining: 4 },
      { role: "catering_staff", capacity: 20, taken: 10, remaining: 10 },
      { role: "bartender", capacity: 6, taken: 2, remaining: 4 },
      { role: "security", capacity: 8, taken: 1, remaining: 7 },
      { role: "floor_manager", capacity: 4, taken: 0, remaining: 4 },
      { role: "exhibitor_support", capacity: 5, taken: 0, remaining: 5 },
      { role: "vip_concierge", capacity: 2, taken: 0, remaining: 2 }
    ],
    createdAt: "2025-10-01T08:00:00.000Z",
    updatedAt: "2025-11-01T12:30:00.000Z",
    __v: 15
  }
];

console.log('=' .repeat(100));
console.log('TOKEN ANALYSIS FOR EVENT DOCUMENTS (Based on Sample Data)');
console.log('=' .repeat(100));
console.log();

console.log('📋 SAMPLE EVENT BREAKDOWN:');
console.log('─'.repeat(100));
console.log();

const analyses = sampleEvents.map((event, index) => {
  const eventJson = JSON.stringify(event, null, 2);
  const tokens = estimateTokens(eventJson);

  console.log(`Event #${index + 1}: ${event.event_name}`);
  console.log(`  Size Category:    ${index === 0 ? 'MINIMAL' : index === 1 ? 'MEDIUM' : 'LARGE'}`);
  console.log(`  Characters:       ${eventJson.length.toLocaleString()}`);
  console.log(`  Staff Count:      ${event.headcount_total}`);
  console.log(`  Accepted Staff:   ${event.accepted_staff.length}`);
  console.log(`  Roles:            ${event.roles.length}`);
  console.log(`  Claude Tokens:    ~${tokens.claude.toLocaleString()}`);
  console.log(`  ChatGPT Tokens:   ~${tokens.chatgpt.toLocaleString()}`);
  console.log();

  return { event, eventJson, tokens };
});

console.log('=' .repeat(100));
console.log();

// Calculate averages
const avgClaudeTokens = Math.round(analyses.reduce((sum, a) => sum + a.tokens.claude, 0) / analyses.length);
const avgChatGPTTokens = Math.round(analyses.reduce((sum, a) => sum + a.tokens.chatgpt, 0) / analyses.length);

console.log('📊 TOKEN ESTIMATES PER EVENT SIZE:');
console.log('─'.repeat(100));
console.log();
console.log('Minimal Event (5 staff, basic info):');
console.log(`  Claude:   ~${analyses[0].tokens.claude.toLocaleString()} tokens`);
console.log(`  ChatGPT:  ~${analyses[0].tokens.chatgpt.toLocaleString()} tokens`);
console.log();
console.log('Medium Event (25 staff, detailed info, some accepted/declined):');
console.log(`  Claude:   ~${analyses[1].tokens.claude.toLocaleString()} tokens`);
console.log(`  ChatGPT:  ~${analyses[1].tokens.chatgpt.toLocaleString()} tokens`);
console.log();
console.log('Large Event (75 staff, extensive details, many responses):');
console.log(`  Claude:   ~${analyses[2].tokens.claude.toLocaleString()} tokens`);
console.log(`  ChatGPT:  ~${analyses[2].tokens.chatgpt.toLocaleString()} tokens`);
console.log();
console.log('Average Across All Sizes:');
console.log(`  Claude:   ~${avgClaudeTokens.toLocaleString()} tokens per event`);
console.log(`  ChatGPT:  ~${avgChatGPTTokens.toLocaleString()} tokens per event`);
console.log();
console.log('=' .repeat(100));
console.log();

// Projections for different database sizes
const databaseSizes = [10, 50, 100, 500, 1000];

console.log('📈 TOKEN PROJECTIONS FOR YOUR DATABASE:');
console.log('─'.repeat(100));
console.log();
console.log('Assuming average event size, here are projections for different database sizes:');
console.log();

for (const size of databaseSizes) {
  const claudeTotal = avgClaudeTokens * size;
  const chatgptTotal = avgChatGPTTokens * size;

  console.log(`${size} events:`);
  console.log(`  Claude:   ${claudeTotal.toLocaleString()} tokens total`);
  console.log(`  ChatGPT:  ${chatgptTotal.toLocaleString()} tokens total`);
  console.log();
}

console.log('=' .repeat(100));
console.log();

console.log('💰 COST ESTIMATES (Input only, per 1000 events at average size):');
console.log('─'.repeat(100));
console.log();

const eventsCount = 1000;
const claudeTokens1000 = avgClaudeTokens * eventsCount;
const chatgptTokens1000 = avgChatGPTTokens * eventsCount;

console.log('Claude Models:');
console.log(`  Claude 3.5 Sonnet:  ${claudeTokens1000.toLocaleString()} tokens × $3.00/1M   = $${((claudeTokens1000 / 1_000_000) * 3).toFixed(2)}`);
console.log(`  Claude 3.5 Haiku:   ${claudeTokens1000.toLocaleString()} tokens × $0.25/1M   = $${((claudeTokens1000 / 1_000_000) * 0.25).toFixed(2)}`);
console.log();
console.log('ChatGPT Models:');
console.log(`  GPT-4 Turbo:        ${chatgptTokens1000.toLocaleString()} tokens × $10.00/1M  = $${((chatgptTokens1000 / 1_000_000) * 10).toFixed(2)}`);
console.log(`  GPT-3.5 Turbo:      ${chatgptTokens1000.toLocaleString()} tokens × $0.50/1M   = $${((chatgptTokens1000 / 1_000_000) * 0.5).toFixed(2)}`);
console.log();
console.log('Note: Output tokens cost extra and vary by usage');
console.log();
console.log('=' .repeat(100));
console.log();

console.log('📏 CONTEXT WINDOW CAPACITY:');
console.log('─'.repeat(100));
console.log();

const claudeContextLimit = 200_000;
const chatgptContextLimit = 128_000;

const eventsInClaudeContext = Math.floor(claudeContextLimit / avgClaudeTokens);
const eventsInChatGPTContext = Math.floor(chatgptContextLimit / avgChatGPTTokens);

console.log('Claude 3.5 Sonnet (200K context window):');
console.log(`  Can fit approximately ${eventsInClaudeContext} average events in one context`);
console.log();
console.log('ChatGPT-4 Turbo (128K context window):');
console.log(`  Can fit approximately ${eventsInChatGPTContext} average events in one context`);
console.log();
console.log('=' .repeat(100));
console.log();

console.log('🔍 KEY INSIGHTS:');
console.log('─'.repeat(100));
console.log();
console.log('1. Event size varies significantly based on:');
console.log('   • Number of staff (accepted + declined)');
console.log('   • Number of roles and role configurations');
console.log('   • Length of notes and special instructions');
console.log('   • Audience lists (user keys and team IDs)');
console.log();
console.log('2. Token usage scales with:');
console.log('   • Staff responses (each staff member adds ~50-80 tokens)');
console.log('   • Role complexity (visibility rules, allowed users)');
console.log('   • Metadata (timestamps, user details, pictures URLs)');
console.log();
console.log('3. For exact counts from YOUR database:');
console.log('   • Run: ./node_modules/.bin/tsx scripts/analyze-event-tokens.ts');
console.log('   • Requires: MONGODB_URI environment variable');
console.log('   • Will analyze all actual events in your database');
console.log();
console.log('4. Cost efficiency:');
console.log('   • Claude Haiku is most cost-effective for bulk processing');
console.log('   • Claude Sonnet offers best balance of cost/capability');
console.log('   • GPT-4 is more expensive but may suit specific use cases');
console.log();
console.log('=' .repeat(100));
console.log();

console.log('✅ Sample analysis complete!');
console.log();
console.log('💡 To analyze your actual database, set MONGODB_URI and run:');
console.log('   MONGODB_URI="mongodb://..." ./node_modules/.bin/tsx scripts/analyze-event-tokens.ts');
console.log();
