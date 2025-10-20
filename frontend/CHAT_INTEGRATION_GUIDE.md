# Staff-Side Chat Integration Guide

This guide explains how to integrate the chat feature into your staff-side app.

## 📁 Files Created

- `lib/models/chat_message.dart` - Chat message entity
- `lib/models/conversation.dart` - Conversation entity
- `lib/services/chat_service.dart` - Chat API service
- `lib/pages/conversations_page.dart` - Conversations list
- `lib/pages/chat_page.dart` - Chat screen

## 🚀 Integration Steps

### Step 1: Add Dependencies (if not already present)

Check your `pubspec.yaml` and ensure these packages are included:

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  flutter_dotenv: ^5.1.0
  timeago: ^3.5.0
  intl: ^0.18.1
```

Run:
```bash
flutter pub get
```

### Step 2: Add Navigation to Chat

You need to add a way for users to access the chat. Here are the recommended locations:

#### Option A: Add to Bottom Navigation (if you have one)

In your `root_page.dart` or wherever you have bottom navigation, add a chat icon:

```dart
BottomNavigationBarItem(
  icon: Icon(Icons.chat_bubble_outline),
  activeIcon: Icon(Icons.chat_bubble),
  label: 'Messages',
),
```

Then in your page builder, add:

```dart
import 'pages/conversations_page.dart';

// In your indexed stack or page view:
case 3: // Or whatever index you chose
  return const ConversationsPage();
```

#### Option B: Add to App Drawer/Menu

If you have a drawer menu, add this item:

```dart
import 'pages/conversations_page.dart';

ListTile(
  leading: const Icon(Icons.chat),
  title: const Text('Messages'),
  onTap: () {
    Navigator.pop(context); // Close drawer
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConversationsPage(),
      ),
    );
  },
),
```

#### Option C: Add Floating Action Button

Add a FAB to your main screen:

```dart
import 'pages/conversations_page.dart';

floatingActionButton: FloatingActionButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConversationsPage(),
      ),
    );
  },
  child: const Icon(Icons.chat),
  tooltip: 'Messages',
),
```

### Step 3: Configure Socket.IO for Real-time Messages

Your `data_service.dart` already has Socket.IO configured. We need to add a listener for chat messages.

In `lib/services/data_service.dart`, find where you set up socket listeners (around line 100-200) and add:

```dart
_socket?.on('chat:message', (data) {
  debugPrint('📨 Received chat message');
  try {
    if (data is Map<String, dynamic>) {
      ChatService().handleIncomingMessage(data);
    }
  } catch (e) {
    debugPrint('Error handling chat message: $e');
  }
});
```

Don't forget to import ChatService at the top:

```dart
import 'chat_service.dart';
```

### Step 4: Test the Integration

1. **Build and run the app:**
   ```bash
   flutter run
   ```

2. **Test the flow:**
   - Navigate to the Messages/Chat section using the navigation you added
   - You should see the conversations list
   - If you don't have any conversations yet, it will show an empty state
   - When your manager sends you a message, it should appear in real-time

### Step 5: Optional - Add Unread Badge

To show an unread count badge on your navigation icon, you can use the `ChatService`:

```dart
import '../services/chat_service.dart';

// In your widget state:
int _unreadCount = 0;
late StreamSubscription<ChatMessage> _chatSubscription;

@override
void initState() {
  super.initState();
  _loadUnreadCount();

  // Listen for new messages
  _chatSubscription = ChatService().messageStream.listen((_) {
    _loadUnreadCount();
  });
}

Future<void> _loadUnreadCount() async {
  try {
    final conversations = await ChatService().fetchConversations();
    final totalUnread = conversations.fold<int>(
      0,
      (sum, conv) => sum + conv.unreadCount,
    );
    setState(() => _unreadCount = totalUnread);
  } catch (e) {
    // Handle error
  }
}

@override
void dispose() {
  _chatSubscription.cancel();
  super.dispose();
}

// Then in your BottomNavigationBarItem:
BottomNavigationBarItem(
  icon: Badge(
    label: Text('$_unreadCount'),
    isLabelVisible: _unreadCount > 0,
    child: Icon(Icons.chat_bubble_outline),
  ),
  label: 'Messages',
),
```

## 🎨 Customization

### Change Theme Colors

The chat bubbles use your app's primary color. To change it:

```dart
MaterialApp(
  theme: ThemeData(
    primaryColor: Colors.blue, // Your brand color
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
  ),
);
```

### Customize Chat Bubbles

Edit `lib/pages/chat_page.dart` and find the `_MessageBubble` widget. You can modify:

- Border radius: `BorderRadius.circular(20)`
- Padding: `EdgeInsets.symmetric(horizontal: 16, vertical: 10)`
- Colors: `isMe ? theme.primaryColor : Colors.grey[200]`

### Customize Avatar Style

In both `conversations_page.dart` and `chat_page.dart`, find the `CircleAvatar` widgets and customize:

- Size: `radius: 28`
- Background color: `backgroundColor: theme.primaryColor.withOpacity(0.1)`
- Border: Add `decoration` with `border`

## 🔧 Troubleshooting

### Messages not appearing in real-time

**Check:**
1. Socket.IO is connected - check `data_service.dart` logs
2. The `chat:message` listener is added to socket events
3. Backend is running and socket server is initialized

**Debug:**
```dart
// Add logging in data_service.dart
_socket?.on('chat:message', (data) {
  print('DEBUG: Received chat message: $data');
  // ... rest of code
});
```

### "Not authenticated" error

**Check:**
1. JWT token is valid: `AuthService.getJwt()`
2. Token is not expired
3. API_BASE_URL in `.env` is correct

**Debug:**
```dart
final token = await AuthService.getJwt();
print('Token: $token');
```

### Conversations not loading

**Check:**
1. Backend API is reachable: `http://your-api/api/chat/conversations`
2. User is logged in
3. Network connectivity

**Debug:**
```dart
// In chat_service.dart, add logging:
print('Fetching conversations from: $url');
print('Response status: ${response.statusCode}');
print('Response body: ${response.body}');
```

### Images not loading in avatars

**Check:**
1. Image URLs are valid
2. Network permissions in `AndroidManifest.xml`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```

## 📱 Example Integration (Quick Start)

Here's a complete example of adding chat to your app:

### 1. Update `root_page.dart`:

```dart
import 'pages/conversations_page.dart';

// Add to your page list:
final List<Widget> _pages = [
  // ... existing pages
  const ConversationsPage(), // Add this
];

// Add to bottom navigation:
BottomNavigationBar(
  items: const <BottomNavigationBarItem>[
    // ... existing items
    BottomNavigationBarItem(
      icon: Icon(Icons.chat_bubble_outline),
      activeIcon: Icon(Icons.chat_bubble),
      label: 'Messages',
    ),
  ],
  currentIndex: _currentIndex,
  onTap: (index) => setState(() => _currentIndex = index),
),
```

### 2. Update `data_service.dart`:

```dart
import 'chat_service.dart';

// In _initSocket() method, after other socket.on listeners:
_socket?.on('chat:message', (data) {
  debugPrint('📨 Received chat message');
  try {
    if (data is Map<String, dynamic>) {
      ChatService().handleIncomingMessage(data);
    }
  } catch (e) {
    debugPrint('Error handling chat message: $e');
  }
});
```

### 3. Run the app:

```bash
flutter run
```

That's it! You now have a fully functional chat system integrated with your staff app.

## 🔄 Real-time Updates

The chat system automatically receives new messages via Socket.IO. When a manager sends a message:

1. Backend emits `chat:message` event to the user's socket room
2. `data_service.dart` receives the event
3. `ChatService` parses and streams the message
4. UI automatically updates via `StreamBuilder`/`listen()`

## 📊 Performance Tips

1. **Lazy Loading**: Messages are loaded 50 at a time (configurable in `chat_service.dart`)
2. **Caching**: Consider caching conversations locally for offline viewing
3. **Pagination**: Load older messages on scroll up (implement in `chat_page.dart`)

## 🎯 Next Steps

- Add push notifications for new messages
- Add typing indicators (requires socket.io typing events)
- Add message search functionality
- Add file/image attachments

## 📞 Support

For issues or questions, refer to the main documentation or check the backend implementation in the manager app.

---

**Version:** 1.0.0
**Last Updated:** January 17, 2025
**Status:** Production Ready ✅
