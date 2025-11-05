# Event Document Token Analysis Guide

## Quick Summary

Based on sample event documents from your schema, here's what to expect:

### Token Count per Event

| Event Size | Claude Tokens | ChatGPT Tokens | Description |
|-----------|---------------|----------------|-------------|
| **Minimal** | ~341 | ~375 | Basic event, 5 staff, minimal details |
| **Medium** | ~1,097 | ~1,207 | 25 staff, detailed info, some responses |
| **Large** | ~6,599 | ~7,259 | 75 staff, extensive details, many responses |
| **Average** | ~2,679 | ~2,947 | Typical event across all sizes |

### Database Size Projections

| Number of Events | Claude Total | ChatGPT Total |
|-----------------|--------------|---------------|
| 10 events | 26,790 | 29,470 |
| 50 events | 133,950 | 147,350 |
| 100 events | 267,900 | 294,700 |
| 500 events | 1,339,500 | 1,473,500 |
| 1,000 events | 2,679,000 | 2,947,000 |

## Cost Estimates (Input only, per 1000 events)

### Claude Models
- **Claude 3.5 Sonnet**: 2,679,000 tokens × $3.00/1M = **$8.04**
- **Claude 3.5 Haiku**: 2,679,000 tokens × $0.25/1M = **$0.67**

### ChatGPT Models
- **GPT-4 Turbo**: 2,947,000 tokens × $10.00/1M = **$29.47**
- **GPT-3.5 Turbo**: 2,947,000 tokens × $0.50/1M = **$1.47**

*Note: Output tokens cost extra and vary by usage*

## Context Window Capacity

### Claude 3.5 Sonnet (200K context)
- Can fit approximately **74 average events** in one context

### ChatGPT-4 Turbo (128K context)
- Can fit approximately **43 average events** in one context

## Token Usage Factors

Event token count increases with:

1. **Staff Responses** - Each staff member (accepted/declined) adds ~50-80 tokens
2. **Role Complexity** - More roles with visibility rules increase tokens
3. **Notes & Details** - Longer notes, uniform requirements, setup instructions
4. **Audience Lists** - More user keys and team IDs
5. **Metadata** - Timestamps, user profiles, picture URLs

## Running Your Own Analysis

### Option 1: Sample Analysis (No Database Required)
```bash
cd backend
./node_modules/.bin/tsx scripts/token-estimate-sample.ts
```

### Option 2: Analyze Your Actual Database
```bash
cd backend

# Set your MongoDB URI
export MONGODB_URI="mongodb://your-connection-string"

# Run analysis
./node_modules/.bin/tsx scripts/analyze-event-tokens.ts
```

Or with .env file:
```bash
# Create .env file
echo "MONGODB_URI=mongodb://your-connection-string" > .env

# Run analysis
./node_modules/.bin/tsx scripts/analyze-event-tokens.ts
```

## Key Insights

### 1. Cost Efficiency
- **Claude Haiku** is most cost-effective for bulk processing (~$0.67 per 1000 events)
- **Claude Sonnet** offers best balance of cost and capability (~$8.04 per 1000 events)
- **GPT-3.5 Turbo** is middle ground (~$1.47 per 1000 events)
- **GPT-4 Turbo** is premium option (~$29.47 per 1000 events)

### 2. Token Efficiency
- Claude uses slightly fewer tokens than ChatGPT (~10% less on average)
- Both models use similar tokenization approaches
- JSON structure adds overhead (brackets, quotes, commas)

### 3. Best Practices
- For batch processing many events: Use **Claude Haiku**
- For quality analysis: Use **Claude Sonnet** or **GPT-4**
- For prototyping: Use **GPT-3.5 Turbo**
- Always account for output tokens in cost calculations

### 4. Context Window Strategy
- Claude's larger context (200K) fits ~74% more events than GPT-4
- For bulk operations, process in batches:
  - Claude: ~50-60 events per batch (safe margin)
  - ChatGPT: ~30-40 events per batch (safe margin)

## Pricing Reference (as of 2024)

### Claude (Anthropic)
| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| Claude 3.5 Sonnet | $3.00 | $15.00 |
| Claude 3.5 Haiku | $0.25 | $1.25 |
| Claude 3 Opus | $15.00 | $75.00 |

### ChatGPT (OpenAI)
| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|------------------------|
| GPT-4 Turbo | $10.00 | $30.00 |
| GPT-4 | $30.00 | $60.00 |
| GPT-3.5 Turbo | $0.50 | $1.50 |

## Example Use Cases

### Use Case 1: Daily Event Summary
- Process 50 events per day
- Use Claude Haiku
- Cost: ~$0.03 per day input + output tokens

### Use Case 2: Event Analysis & Recommendations
- Analyze 100 events for insights
- Use Claude Sonnet
- Cost: ~$0.80 input + variable output

### Use Case 3: Complete Database Processing
- Process all 1000 events monthly
- Use Claude Haiku for extraction, Sonnet for analysis
- Cost: ~$0.67 extraction + ~$8.04 analysis = ~$8.71/month input

## Notes

1. These are **estimates** based on sample data
2. Actual token counts may vary based on:
   - Your specific event data
   - Field lengths and content
   - Number of staff responses
   - Complexity of role configurations
3. For exact counts, use official tokenizers:
   - Claude: `@anthropic-ai/tokenizer`
   - ChatGPT: `tiktoken` or `gpt-tokenizer`
4. Pricing subject to change - check vendor websites for latest rates

## Scripts Available

1. **token-estimate-sample.ts** - Sample analysis with typical events
2. **analyze-event-tokens.ts** - Analyze your actual database
3. **TOKEN_ANALYSIS_GUIDE.md** - This guide

## Support

For questions or issues:
- Check script comments for implementation details
- Verify MongoDB connection string format
- Ensure all dependencies are installed (`npm install`)
