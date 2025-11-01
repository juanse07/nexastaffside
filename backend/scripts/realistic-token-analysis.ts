// Realistic token analysis for small staff counts (1-5 staff)

interface StaffResponse {
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
}

interface Event {
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
  roles: any[];
  accepted_staff: StaffResponse[];
  declined_staff: StaffResponse[];
  audience_user_keys: string[];
  audience_team_ids: string[];
  role_stats: any[];
  createdAt: string;
  updatedAt: string;
  __v: number;
}

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

function createStaffResponse(index: number, response: 'accept' | 'decline'): StaffResponse {
  return {
    userKey: `google:${100000000000000000000 + index}`,
    provider: "google",
    subject: `${100000000000000000000 + index}`,
    email: `staff${index}@example.com`,
    name: `Staff Member ${index}`,
    first_name: "Staff",
    last_name: `Member${index}`,
    picture: "https://lh3.googleusercontent.com/a/default-user",
    response: response,
    role: "server",
    respondedAt: new Date().toISOString()
  };
}

function createEvent(staffCount: number): Event {
  const acceptedCount = Math.ceil(staffCount * 0.7); // 70% accepted
  const declinedCount = staffCount - acceptedCount; // 30% declined

  return {
    _id: "507f1f77bcf86cd799439011",
    id: "507f1f77bcf86cd799439011",
    event_name: "Evening Shift Event",
    client_name: "ABC Restaurant",
    date: "2025-11-15T00:00:00.000Z",
    start_time: "18:00",
    end_time: "23:00",
    venue_name: "Downtown Location",
    venue_address: "123 Main Street",
    city: "New York",
    state: "NY",
    country: "USA",
    contact_name: "John Manager",
    contact_phone: "+1-555-0100",
    contact_email: "john@example.com",
    setup_time: "17:30",
    uniform: "Black shirt, black pants",
    notes: "Please arrive 30 minutes early for briefing",
    headcount_total: 10,
    roles: [
      { role: "server", count: 6, visibleForAll: true },
      { role: "bartender", count: 2, visibleForAll: true },
      { role: "host", count: 2, visibleForAll: true }
    ],
    accepted_staff: Array.from({ length: acceptedCount }, (_, i) =>
      createStaffResponse(i, 'accept')
    ),
    declined_staff: Array.from({ length: declinedCount }, (_, i) =>
      createStaffResponse(acceptedCount + i, 'decline')
    ),
    audience_user_keys: ["google:user1", "google:user2"],
    audience_team_ids: ["team_001"],
    role_stats: [
      { role: "server", capacity: 6, taken: acceptedCount, remaining: 6 - acceptedCount },
      { role: "bartender", capacity: 2, taken: 0, remaining: 2 },
      { role: "host", capacity: 2, taken: 0, remaining: 2 }
    ],
    createdAt: "2025-11-01T10:00:00.000Z",
    updatedAt: "2025-11-01T10:00:00.000Z",
    __v: 1
  };
}

console.log('=' .repeat(100));
console.log('REALISTIC TOKEN ANALYSIS - Small Staff Counts (1-10 Staff Responses)');
console.log('=' .repeat(100));
console.log();

console.log('🔍 This analysis shows token counts for typical event sizes you might have.');
console.log('   Most events probably have 1-5 staff responses (accepted + declined).');
console.log();
console.log('=' .repeat(100));
console.log();

// Analyze events with 0 to 10 staff
const staffCounts = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
const results: any[] = [];

console.log('📊 TOKEN COUNT BY NUMBER OF STAFF RESPONSES:');
console.log('─'.repeat(100));
console.log();
console.log('Staff    | Claude  | ChatGPT | Character | Notes');
console.log('Responses| Tokens  | Tokens  | Count     |');
console.log('─'.repeat(100));

for (const count of staffCounts) {
  const event = createEvent(count);
  const eventJson = JSON.stringify(event, null, 2);
  const tokens = estimateTokens(eventJson);

  results.push({ count, tokens, chars: eventJson.length });

  const note = count === 0 ? 'No responses yet' :
               count === 1 ? '1 person responded' :
               count <= 3 ? 'Small event ✓' :
               count <= 5 ? 'Medium event' :
               count <= 8 ? 'Large event' :
               'Very large event';

  console.log(
    `${count.toString().padStart(2)}       | ` +
    `${tokens.claude.toString().padStart(6)} | ` +
    `${tokens.chatgpt.toString().padStart(7)} | ` +
    `${eventJson.length.toString().padStart(9)} | ` +
    note
  );
}

console.log();
console.log('=' .repeat(100));
console.log();

// Calculate token cost per staff member
const baseEvent = results[0]; // 0 staff
const oneStaffEvent = results[1]; // 1 staff

const tokensPerStaff = {
  claude: results[1].tokens.claude - results[0].tokens.claude,
  chatgpt: results[1].tokens.chatgpt - results[0].tokens.chatgpt
};

console.log('💡 KEY INSIGHTS:');
console.log('─'.repeat(100));
console.log();
console.log(`Base Event (no staff responses):`);
console.log(`  Claude:   ${baseEvent.tokens.claude} tokens`);
console.log(`  ChatGPT:  ${baseEvent.tokens.chatgpt} tokens`);
console.log();
console.log(`Each Additional Staff Member Adds:`);
console.log(`  Claude:   ~${tokensPerStaff.claude} tokens`);
console.log(`  ChatGPT:  ~${tokensPerStaff.chatgpt} tokens`);
console.log();
console.log('Formula:');
console.log(`  Claude Tokens   = ${baseEvent.tokens.claude} + (${tokensPerStaff.claude} × number_of_staff)`);
console.log(`  ChatGPT Tokens  = ${baseEvent.tokens.chatgpt} + (${tokensPerStaff.chatgpt} × number_of_staff)`);
console.log();
console.log('=' .repeat(100));
console.log();

// Most common scenarios
console.log('📋 MOST COMMON SCENARIOS:');
console.log('─'.repeat(100));
console.log();

const scenarios = [
  { staff: 2, desc: 'Small event, 2 responses (1-2 accepted, 0-1 declined)' },
  { staff: 3, desc: 'Small event, 3 responses (2 accepted, 1 declined)' },
  { staff: 4, desc: 'Medium event, 4 responses' },
  { staff: 5, desc: 'Medium event, 5 responses' }
];

for (const scenario of scenarios) {
  const result = results[scenario.staff];
  console.log(`${scenario.desc}`);
  console.log(`  Claude:   ${result.tokens.claude} tokens`);
  console.log(`  ChatGPT:  ${result.tokens.chatgpt} tokens`);
  console.log(`  Characters: ${result.chars.toLocaleString()}`);
  console.log();
}

console.log('=' .repeat(100));
console.log();

// Database projections
console.log('💰 COST PROJECTIONS FOR YOUR DATABASE:');
console.log('─'.repeat(100));
console.log();

const avgStaffPerEvent = 3; // Assuming average 3 staff responses
const avgTokens = results[avgStaffPerEvent].tokens;

console.log(`Assuming average of ${avgStaffPerEvent} staff responses per event:`);
console.log(`  Average tokens: ${avgTokens.claude} Claude / ${avgTokens.chatgpt} ChatGPT`);
console.log();

const dbSizes = [50, 100, 200, 500, 1000];

console.log('Database Size | Claude Total | ChatGPT Total | Claude Haiku Cost | Claude Sonnet Cost');
console.log('─'.repeat(100));

for (const size of dbSizes) {
  const claudeTotal = avgTokens.claude * size;
  const chatgptTotal = avgTokens.chatgpt * size;
  const haikuCost = (claudeTotal / 1_000_000) * 0.25;
  const sonnetCost = (claudeTotal / 1_000_000) * 3.00;

  console.log(
    `${size.toString().padStart(4)} events   | ` +
    `${claudeTotal.toLocaleString().padStart(12)} | ` +
    `${chatgptTotal.toLocaleString().padStart(13)} | ` +
    `$${haikuCost.toFixed(4).padStart(7)}        | ` +
    `$${sonnetCost.toFixed(4).padStart(7)}`
  );
}

console.log();
console.log('=' .repeat(100));
console.log();

console.log('🎯 RECOMMENDATIONS:');
console.log('─'.repeat(100));
console.log();
console.log('1. For events with 2-3 staff responses (most common):');
console.log(`   • Each event uses ~${results[2].tokens.claude}-${results[3].tokens.claude} Claude tokens`);
console.log(`   • Processing 100 events = ~${(results[2].tokens.claude * 100).toLocaleString()} tokens`);
console.log(`   • Cost with Claude Haiku = $${((results[2].tokens.claude * 100 / 1_000_000) * 0.25).toFixed(4)}`);
console.log();
console.log('2. Context window efficiency:');
console.log(`   • Claude (200K): Can fit ~${Math.floor(200000 / results[3].tokens.claude)} events with 3 staff`);
console.log(`   • ChatGPT (128K): Can fit ~${Math.floor(128000 / results[3].tokens.chatgpt)} events with 3 staff`);
console.log();
console.log('3. Cost-effective processing:');
console.log('   • Use Claude Haiku for bulk operations (cheapest)');
console.log('   • Use Claude Sonnet for analysis requiring reasoning');
console.log('   • Batch process multiple events in single API call');
console.log();
console.log('=' .repeat(100));
console.log();

console.log('✅ Realistic analysis complete!');
console.log();
console.log('💡 To analyze YOUR actual database with real staff counts:');
console.log('   MONGODB_URI="your_uri" ./node_modules/.bin/tsx scripts/analyze-event-tokens.ts');
console.log();
