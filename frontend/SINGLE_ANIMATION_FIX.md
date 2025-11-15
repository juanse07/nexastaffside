# Single Animation Per Message

## Problem
Message bubbles were re-animating every time they were rebuilt or scrolled back into view. This was annoying and not how real chat apps work.

## Solution
Track which messages have already been animated using a `Set<int>` of message timestamps.

## Implementation

### 1. Add Animation Tracking (line 41)
```dart
// Track which messages have already been animated (by timestamp)
final Set<int> _animatedMessages = {};
```

### 2. Check Before Animating (line 539-548)
```dart
// Check if this is the latest assistant message AND hasn't been animated yet
final messageId = message.timestamp.millisecondsSinceEpoch;
final isLatestAiMessage = message.role == 'assistant' &&
    messageIndex == _chatService.conversationHistory.length - 1;
final shouldAnimate = isLatestAiMessage && !_animatedMessages.contains(messageId);

// Mark as animated if it's being shown with animation
if (shouldAnimate) {
  _animatedMessages.add(messageId);
}
```

### 3. Use Correct Widget (line 551-558)
```dart
return RepaintBoundary(
  key: ValueKey('message_$messageId'),
  child: shouldAnimate
    ? AnimatedAiMessageWidget(message: message, showAnimation: true)
    : ChatMessageWidget(message: message, ...),
);
```

### 4. Clear Tracking on Conversation Clear (line 259)
```dart
_chatService.clearConversation();
_animatedMessages.clear(); // Clear animation tracking
```

## How It Works

### First Time Message Appears
1. Message arrives → `messageId` generated from timestamp
2. Check: `!_animatedMessages.contains(messageId)` → **true**
3. Set `shouldAnimate = true`
4. Add to set: `_animatedMessages.add(messageId)`
5. Render `AnimatedAiMessageWidget` with animation

### On Rebuild/Scroll
1. Same message rendered again
2. Check: `!_animatedMessages.contains(messageId)` → **false** (already in set)
3. Set `shouldAnimate = false`
4. Render static `ChatMessageWidget` (no animation)

## Benefits

✅ **Better UX**: Each message animates only once (like WhatsApp, iMessage)
✅ **Performance**: No unnecessary animations on scroll/rebuild
✅ **Memory Efficient**: Set only stores integers (8 bytes each)
✅ **Simple**: Just 3 lines of logic

## Edge Cases Handled

### Conversation Cleared
- `_animatedMessages.clear()` resets tracking
- New conversation starts fresh

### Same Timestamp (Unlikely)
- Timestamps are milliseconds since epoch
- Collision chance: virtually zero
- Worst case: One message doesn't animate (graceful degradation)

### Memory
- Set grows with conversation length
- Each entry: ~8 bytes (int64)
- 1000 messages ≈ 8KB (negligible)
- Cleared on conversation clear

## Result

Messages now behave like professional chat apps:
- **First appearance**: Smooth typewriter animation ✨
- **Scroll away and back**: Static (instant) ✅
- **Rebuild/setState**: Static (instant) ✅

No re-animations. Clean UX. 🎯
