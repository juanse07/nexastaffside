import { MongoClient } from 'mongodb';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Token counting functions for different models
// For Claude: Approximate token count (1 token ≈ 4 characters)
function estimateClaudeTokens(text: string): number {
  // Claude uses a similar tokenizer to GPT, roughly 4 chars per token
  // For more accuracy, you'd use @anthropic-ai/tokenizer
  return Math.ceil(text.length / 4);
}

// For ChatGPT: Approximate token count (1 token ≈ 4 characters for English)
function estimateChatGPTTokens(text: string): number {
  // GPT-3.5/GPT-4 use cl100k_base encoding
  // Rough approximation: 1 token ≈ 4 characters
  // For exact counts, you'd use tiktoken library
  return Math.ceil(text.length / 4);
}

// More accurate estimation based on actual tokenizer patterns
function accurateTokenEstimate(text: string): {
  claude: number;
  chatgpt: number;
} {
  // This is a more sophisticated approximation based on:
  // - Word boundaries
  // - Punctuation
  // - Numbers
  // - Special characters

  // Split by words and count
  const words = text.split(/\s+/).filter(w => w.length > 0);
  const chars = text.length;

  // Average token count:
  // - Short words (1-4 chars): 1 token
  // - Medium words (5-8 chars): 1-2 tokens
  // - Long words (9+ chars): 2-3 tokens

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

  // Add tokens for punctuation and special chars
  const specialChars = (text.match(/[.,!?;:()\[\]{}"'`]/g) || []).length;
  tokenCount += specialChars * 0.5;

  return {
    claude: Math.ceil(tokenCount),
    chatgpt: Math.ceil(tokenCount * 1.1), // ChatGPT tends to use slightly more tokens
  };
}

async function analyzeEventTokens() {
  const mongoUri = process.env.MONGODB_URI;

  if (!mongoUri) {
    console.error('❌ MONGODB_URI not found in environment variables');
    console.log('\n💡 Please set MONGODB_URI in your .env file');
    process.exit(1);
  }

  const client = new MongoClient(mongoUri);

  try {
    console.log('🔌 Connecting to MongoDB...\n');
    await client.connect();

    const db = client.db();
    const eventsCollection = db.collection('events');

    // Get total count
    const totalEvents = await eventsCollection.countDocuments();
    console.log(`📊 Total events in database: ${totalEvents}\n`);

    if (totalEvents === 0) {
      console.log('⚠️  No events found in database');
      return;
    }

    // Fetch all events
    const events = await eventsCollection.find({}).toArray();

    console.log('=' .repeat(80));
    console.log('TOKEN ANALYSIS FOR EVENT DOCUMENTS');
    console.log('=' .repeat(80));
    console.log();

    // Analyze each event
    let totalClaudeTokens = 0;
    let totalChatGPTTokens = 0;
    let minClaudeTokens = Infinity;
    let maxClaudeTokens = 0;
    let minChatGPTTokens = Infinity;
    let maxChatGPTTokens = 0;

    const eventAnalysis = events.map((event, index) => {
      // Convert event to JSON string
      const eventJson = JSON.stringify(event, null, 2);

      // Calculate tokens
      const simpleEstimate = {
        claude: estimateClaudeTokens(eventJson),
        chatgpt: estimateChatGPTTokens(eventJson),
      };

      const accurateEstimate = accurateTokenEstimate(eventJson);

      // Use accurate estimate for statistics
      totalClaudeTokens += accurateEstimate.claude;
      totalChatGPTTokens += accurateEstimate.chatgpt;

      minClaudeTokens = Math.min(minClaudeTokens, accurateEstimate.claude);
      maxClaudeTokens = Math.max(maxClaudeTokens, accurateEstimate.claude);
      minChatGPTTokens = Math.min(minChatGPTTokens, accurateEstimate.chatgpt);
      maxChatGPTTokens = Math.max(maxChatGPTTokens, accurateEstimate.chatgpt);

      return {
        index: index + 1,
        id: event._id.toString(),
        event_name: event.event_name,
        client_name: event.client_name,
        date: event.date,
        characterCount: eventJson.length,
        simpleEstimate,
        accurateEstimate,
      };
    });

    // Print summary statistics
    console.log('📈 SUMMARY STATISTICS');
    console.log('─'.repeat(80));
    console.log(`Total Events: ${totalEvents}`);
    console.log();
    console.log('CLAUDE (Anthropic):');
    console.log(`  Total Tokens (all events):     ${totalClaudeTokens.toLocaleString()}`);
    console.log(`  Average Tokens per Event:      ${Math.round(totalClaudeTokens / totalEvents).toLocaleString()}`);
    console.log(`  Min Tokens (single event):     ${minClaudeTokens.toLocaleString()}`);
    console.log(`  Max Tokens (single event):     ${maxClaudeTokens.toLocaleString()}`);
    console.log();
    console.log('CHATGPT (OpenAI):');
    console.log(`  Total Tokens (all events):     ${totalChatGPTTokens.toLocaleString()}`);
    console.log(`  Average Tokens per Event:      ${Math.round(totalChatGPTTokens / totalEvents).toLocaleString()}`);
    console.log(`  Min Tokens (single event):     ${minChatGPTTokens.toLocaleString()}`);
    console.log(`  Max Tokens (single event):     ${maxChatGPTTokens.toLocaleString()}`);
    console.log();
    console.log('=' .repeat(80));
    console.log();

    // Print detailed breakdown for first 5 events
    const displayCount = Math.min(5, events.length);
    console.log(`📋 DETAILED BREAKDOWN (First ${displayCount} events):`);
    console.log('─'.repeat(80));

    for (let i = 0; i < displayCount; i++) {
      const analysis = eventAnalysis[i];
      console.log();
      console.log(`Event #${analysis.index}:`);
      console.log(`  ID:           ${analysis.id}`);
      console.log(`  Name:         ${analysis.event_name}`);
      console.log(`  Client:       ${analysis.client_name}`);
      console.log(`  Date:         ${analysis.date}`);
      console.log(`  Characters:   ${analysis.characterCount.toLocaleString()}`);
      console.log(`  Claude:       ~${analysis.accurateEstimate.claude.toLocaleString()} tokens`);
      console.log(`  ChatGPT:      ~${analysis.accurateEstimate.chatgpt.toLocaleString()} tokens`);
    }

    if (events.length > displayCount) {
      console.log();
      console.log(`... and ${events.length - displayCount} more events`);
    }

    console.log();
    console.log('=' .repeat(80));
    console.log();

    // Cost estimations (approximate)
    console.log('💰 COST ESTIMATIONS (for all events):');
    console.log('─'.repeat(80));
    console.log();
    console.log('Claude 3.5 Sonnet:');
    console.log(`  Input:  ${totalClaudeTokens.toLocaleString()} tokens × $3.00/1M  = $${((totalClaudeTokens / 1_000_000) * 3).toFixed(4)}`);
    console.log(`  Output: (varies by usage)`);
    console.log();
    console.log('Claude 3 Haiku:');
    console.log(`  Input:  ${totalClaudeTokens.toLocaleString()} tokens × $0.25/1M  = $${((totalClaudeTokens / 1_000_000) * 0.25).toFixed(4)}`);
    console.log(`  Output: (varies by usage)`);
    console.log();
    console.log('ChatGPT-4 Turbo:');
    console.log(`  Input:  ${totalChatGPTTokens.toLocaleString()} tokens × $10.00/1M = $${((totalChatGPTTokens / 1_000_000) * 10).toFixed(4)}`);
    console.log(`  Output: (varies by usage)`);
    console.log();
    console.log('ChatGPT-3.5 Turbo:');
    console.log(`  Input:  ${totalChatGPTTokens.toLocaleString()} tokens × $0.50/1M  = $${((totalChatGPTTokens / 1_000_000) * 0.5).toFixed(4)}`);
    console.log(`  Output: (varies by usage)`);
    console.log();
    console.log('=' .repeat(80));
    console.log();

    // Context window analysis
    console.log('📏 CONTEXT WINDOW ANALYSIS:');
    console.log('─'.repeat(80));
    console.log();

    const claudeContextLimit = 200_000;
    const chatgptContextLimit = 128_000; // GPT-4 Turbo

    const eventsInClaudeContext = Math.floor(claudeContextLimit / (totalClaudeTokens / totalEvents));
    const eventsInChatGPTContext = Math.floor(chatgptContextLimit / (totalChatGPTTokens / totalEvents));

    console.log(`Claude 3.5 Sonnet (200K context):`);
    console.log(`  Can fit ~${eventsInClaudeContext} events in single context`);
    console.log(`  Your ${totalEvents} events would need ${Math.ceil(totalEvents / eventsInClaudeContext)} context windows`);
    console.log();
    console.log(`ChatGPT-4 Turbo (128K context):`);
    console.log(`  Can fit ~${eventsInChatGPTContext} events in single context`);
    console.log(`  Your ${totalEvents} events would need ${Math.ceil(totalEvents / eventsInChatGPTContext)} context windows`);
    console.log();
    console.log('=' .repeat(80));
    console.log();

    console.log('✅ Analysis complete!');
    console.log();
    console.log('📝 NOTES:');
    console.log('  • Token counts are estimates based on character/word analysis');
    console.log('  • For exact counts, use official tokenizers:');
    console.log('    - Claude: @anthropic-ai/tokenizer');
    console.log('    - ChatGPT: tiktoken or gpt-tokenizer');
    console.log('  • Costs are based on current API pricing (as of 2024)');
    console.log('  • Actual costs depend on input + output tokens used');
    console.log();

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    await client.close();
    console.log('🔌 Disconnected from MongoDB');
  }
}

// Run the analysis
analyzeEventTokens();
