// Social Community Service - Node.js/NestJS
// Handles: Feeds, Posts, Comments, Challenges, Moderation, Anti-spam
// Database: Cassandra for social feeds, Elasticsearch for search

import express from 'express';
import { createServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import cors from 'cors';
import helmet from 'helmet';
import { v4 as uuidv4 } from 'uuid';

const app = express();
const server = createServer(app);
const wss = new WebSocketServer({ server });

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Types
interface User {
  id: string;
  username: string;
  displayName: string;
  avatarUrl: string;
  followerCount: number;
  followingCount: number;
}

interface Post {
  id: string;
  userId: string;
  type: 'workout' | 'achievement' | 'challenge' | 'text' | 'photo';
  content: string;
  mediaUrls: string[];
  workoutData?: {
    workoutId: string;
    exerciseName: string;
    duration: number;
    volume: number;
    personalRecord?: boolean;
  };
  likeCount: number;
  commentCount: number;
  createdAt: Date;
  updatedAt: Date;
}

interface Comment {
  id: string;
  postId: string;
  userId: string;
  content: string;
  likeCount: number;
  createdAt: Date;
}

interface Challenge {
  id: string;
  name: string;
  description: string;
  type: 'workout' | 'nutrition' | 'streak' | 'volume';
  startDate: Date;
  endDate: Date;
  targetValue: number;
  participantCount: number;
  prize?: string;
  imageUrl: string;
}

interface LeaderboardEntry {
  userId: string;
  username: string;
  avatarUrl: string;
  score: number;
  rank: number;
}

interface Notification {
  id: string;
  userId: string;
  type: 'like' | 'comment' | 'follow' | 'challenge' | 'achievement';
  fromUserId: string;
  referenceId: string;
  read: boolean;
  createdAt: Date;
}

// In-memory stores (replace with Cassandra in production)
const posts: Map<string, Post> = new Map();
const comments: Map<string, Comment[]> = new Map();
const users: Map<string, User> = new Map();
const challenges: Map<string, Challenge> = new Map();
const leaderboards: Map<string, LeaderboardEntry[]> = new Map();
const notifications: Map<string, Notification[]> = new Map();
const followers: Map<string, Set<string>> = new Map();

// WebSocket connections for real-time features
const wsClients: Map<string, WebSocket> = new Map();

wss.on('connection', (ws, req) => {
  const userId = req.headers['x-user-id'] as string;
  if (userId) {
    wsClients.set(userId, ws);
    console.log(`WebSocket connected for user: ${userId}`);
  }
  
  ws.on('close', () => {
    if (userId) {
      wsClients.delete(userId);
    }
  });
});

// Broadcast to WebSocket clients
function broadcastToUser(userId: string, data: any) {
  const ws = wsClients.get(userId);
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(data));
  }
}

function broadcastToFollowers(userId: string, data: any) {
  const userFollowers = followers.get(userId) || new Set();
  userFollowers.forEach(followerId => {
    broadcastToUser(followerId, data);
  });
}

// ============ FEED ENDPOINTS ============

// Get user's feed (posts from followed users + own posts)
app.get('/api/v1/social/feed', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const cursor = req.query.cursor as string;
  const limit = parseInt(req.query.limit as string) || 20;
  
  // Get user's following list
  const following = followers.get(userId) || new Set();
  following.add(userId); // Include own posts
  
  // Fetch posts from followed users
  const feedPosts = Array.from(posts.values())
    .filter(p => following.has(p.userId))
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
    .slice(0, limit);
  
  res.json({
    posts: feedPosts,
    nextCursor: feedPosts.length === limit ? feedPosts[feedPosts.length - 1]?.id : null,
  });
});

// Get trending posts
app.get('/api/v1/social/trending', async (req, res) => {
  const limit = parseInt(req.query.limit as string) || 20;
  
  const trending = Array.from(posts.values())
    .sort((a, b) => b.likeCount - a.likeCount)
    .slice(0, limit);
  
  res.json({ posts: trending });
});

// ============ POST ENDPOINTS ============

// Create a post
app.post('/api/v1/social/posts', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const { type, content, mediaUrls, workoutData } = req.body;
  
  const post: Post = {
    id: uuidv4(),
    userId,
    type,
    content,
    mediaUrls: mediaUrls || [],
    workoutData,
    likeCount: 0,
    commentCount: 0,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  
  posts.set(post.id, post);
  
  // Broadcast to followers
  broadcastToFollowers(userId, {
    type: 'new_post',
    post,
  });
  
  res.status(201).json(post);
});

// Get a specific post
app.get('/api/v1/social/posts/:postId', async (req, res) => {
  const post = posts.get(req.params.postId);
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }
  res.json(post);
});

// Delete a post
app.delete('/api/v1/social/posts/:postId', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const post = posts.get(req.params.postId);
  
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }
  
  if (post.userId !== userId) {
    return res.status(403).json({ error: 'Not authorized' });
  }
  
  posts.delete(req.params.postId);
  comments.delete(req.params.postId);
  
  res.status(204).send();
});

// ============ LIKE ENDPOINTS ============

// Like a post
app.post('/api/v1/social/posts/:postId/like', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const post = posts.get(req.params.postId);
  
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }
  
  post.likeCount++;
  posts.set(post.id, post);
  
  // Notify post owner
  if (post.userId !== userId) {
    broadcastToUser(post.userId, {
      type: 'notification',
      notification: {
        id: uuidv4(),
        userId: post.userId,
        type: 'like',
        fromUserId: userId,
        referenceId: post.id,
        read: false,
        createdAt: new Date(),
      },
    });
  }
  
  res.json({ likeCount: post.likeCount });
});

// Unlike a post
app.delete('/api/v1/social/posts/:postId/like', async (req, res) => {
  const post = posts.get(req.params.postId);
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }
  
  post.likeCount = Math.max(0, post.likeCount - 1);
  posts.set(post.id, post);
  
  res.json({ likeCount: post.likeCount });
});

// ============ COMMENT ENDPOINTS ============

// Get comments for a post
app.get('/api/v1/social/posts/:postId/comments', async (req, res) => {
  const postComments = comments.get(req.params.postId) || [];
  res.json({ comments: postComments });
});

// Add a comment
app.post('/api/v1/social/posts/:postId/comments', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const { content } = req.body;
  const post = posts.get(req.params.postId);
  
  if (!post) {
    return res.status(404).json({ error: 'Post not found' });
  }
  
  const comment: Comment = {
    id: uuidv4(),
    postId: post.id,
    userId,
    content,
    likeCount: 0,
    createdAt: new Date(),
  };
  
  const postComments = comments.get(post.id) || [];
  postComments.push(comment);
  comments.set(post.id, postComments);
  
  post.commentCount++;
  posts.set(post.id, post);
  
  // Notify post owner
  if (post.userId !== userId) {
    broadcastToUser(post.userId, {
      type: 'notification',
      notification: {
        id: uuidv4(),
        userId: post.userId,
        type: 'comment',
        fromUserId: userId,
        referenceId: post.id,
        read: false,
        createdAt: new Date(),
      },
    });
  }
  
  res.status(201).json(comment);
});

// ============ FOLLOW ENDPOINTS ============

// Follow a user
app.post('/api/v1/social/users/:targetUserId/follow', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const targetUserId = req.params.targetUserId;
  
  if (userId === targetUserId) {
    return res.status(400).json({ error: 'Cannot follow yourself' });
  }
  
  // Add to followers
  const targetFollowers = followers.get(targetUserId) || new Set();
  targetFollowers.add(userId);
  followers.set(targetUserId, targetFollowers);
  
  // Update follower counts
  const targetUser = users.get(targetUserId);
  if (targetUser) {
    targetUser.followerCount++;
    users.set(targetUserId, targetUser);
  }
  
  const currentUser = users.get(userId);
  if (currentUser) {
    currentUser.followingCount++;
    users.set(userId, currentUser);
  }
  
  // Notify target user
  broadcastToUser(targetUserId, {
    type: 'notification',
    notification: {
      id: uuidv4(),
      userId: targetUserId,
      type: 'follow',
      fromUserId: userId,
      referenceId: userId,
      read: false,
      createdAt: new Date(),
    },
  });
  
  res.json({ success: true });
});

// Unfollow a user
app.delete('/api/v1/social/users/:targetUserId/follow', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const targetUserId = req.params.targetUserId;
  
  const targetFollowers = followers.get(targetUserId);
  if (targetFollowers) {
    targetFollowers.delete(userId);
  }
  
  res.json({ success: true });
});

// Get user's followers
app.get('/api/v1/social/users/:userId/followers', async (req, res) => {
  const userFollowers = followers.get(req.params.userId) || new Set();
  const followerUsers = Array.from(userFollowers)
    .map(id => users.get(id))
    .filter(Boolean);
  
  res.json({ followers: followerUsers });
});

// Get user's following
app.get('/api/v1/social/users/:userId/following', async (req, res) => {
  const userId = req.params.userId;
  const following: User[] = [];
  
  followers.forEach((followersSet, targetId) => {
    if (followersSet.has(userId)) {
      const targetUser = users.get(targetId);
      if (targetUser) {
        following.push(targetUser);
      }
    }
  });
  
  res.json({ following });
});

// ============ CHALLENGE ENDPOINTS ============

// Get all challenges
app.get('/api/v1/social/challenges', async (req, res) => {
  const now = new Date();
  const activeChallenges = Array.from(challenges.values())
    .filter(c => c.startDate <= now && c.endDate >= now)
    .sort((a, b) => b.participantCount - a.participantCount);
  
  res.json({ challenges: activeChallenges });
});

// Create a challenge
app.post('/api/v1/social/challenges', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const { name, description, type, startDate, endDate, targetValue, prize, imageUrl } = req.body;
  
  const challenge: Challenge = {
    id: uuidv4(),
    name,
    description,
    type,
    startDate: new Date(startDate),
    endDate: new Date(endDate),
    targetValue,
    prize,
    imageUrl,
    participantCount: 0,
  };
  
  challenges.set(challenge.id, challenge);
  
  res.status(201).json(challenge);
});

// Join a challenge
app.post('/api/v1/social/challenges/:challengeId/join', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const challenge = challenges.get(req.params.challengeId);
  
  if (!challenge) {
    return res.status(404).json({ error: 'Challenge not found' });
  }
  
  challenge.participantCount++;
  challenges.set(challenge.id, challenge);
  
  // Initialize leaderboard entry
  const leaderboard = leaderboards.get(challenge.id) || [];
  leaderboard.push({
    userId,
    username: users.get(userId)?.username || 'Unknown',
    avatarUrl: users.get(userId)?.avatarUrl || '',
    score: 0,
    rank: leaderboard.length + 1,
  });
  leaderboards.set(challenge.id, leaderboard);
  
  res.json({ success: true });
});

// Get challenge leaderboard
app.get('/api/v1/social/challenges/:challengeId/leaderboard', async (req, res) => {
  const leaderboard = leaderboards.get(req.params.challengeId) || [];
  const sorted = leaderboard.sort((a, b) => b.score - a.score);
  
  res.json({ leaderboard: sorted });
});

// Update challenge progress (called by tracking service)
app.post('/api/v1/social/challenges/:challengeId/progress', async (req, res) => {
  const { userId, score } = req.body;
  const leaderboard = leaderboards.get(req.params.challengeId) || [];
  
  const entry = leaderboard.find(e => e.userId === userId);
  if (entry) {
    entry.score = score;
  }
  
  res.json({ success: true });
});

// ============ LEADERBOARD ENDPOINTS ============

// Get global leaderboard
app.get('/api/v1/social/leaderboard', async (req, res) => {
  const type = req.query.type as string || 'volume'; // volume, workouts, streak
  const limit = parseInt(req.query.limit as string) || 100;
  
  // In production, this would query Cassandra
  const leaderboard = Array.from(users.values())
    .map((user, index) => ({
      userId: user.id,
      username: user.username,
      avatarUrl: user.avatarUrl,
      score: Math.floor(Math.random() * 10000),
      rank: index + 1,
    }))
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);
  
  res.json({ leaderboard });
});

// ============ NOTIFICATION ENDPOINTS ============

// Get user notifications
app.get('/api/v1/social/notifications', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const userNotifications = notifications.get(userId) || [];
  
  res.json({ notifications: userNotifications });
});

// Mark notification as read
app.put('/api/v1/social/notifications/:notificationId/read', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const userNotifications = notifications.get(userId) || [];
  const notification = userNotifications.find(n => n.id === req.params.notificationId);
  
  if (notification) {
    notification.read = true;
  }
  
  res.json({ success: true });
});

// ============ SEARCH ENDPOINTS ============

// Search users and content
app.get('/api/v1/social/search', async (req, res) => {
  const query = req.query.q as string;
  const type = req.query.type as string || 'all';
  
  // In production, use Elasticsearch
  const matchedUsers = Array.from(users.values())
    .filter(u => u.username.toLowerCase().includes(query.toLowerCase()));
  
  const matchedPosts = Array.from(posts.values())
    .filter(p => p.content.toLowerCase().includes(query.toLowerCase()));
  
  res.json({
    users: type === 'all' || type === 'users' ? matchedUsers : [],
    posts: type === 'all' || type === 'posts' ? matchedPosts : [],
  });
});

// ============ MODERATION ENDPOINTS ============

// Report a post
app.post('/api/v1/social/posts/:postId/report', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  const { reason } = req.body;
  
  // In production, store in database and alert moderators
  console.log(`Post ${req.params.postId} reported by ${userId}: ${reason}`);
  
  res.json({ success: true, message: 'Report submitted' });
});

// ============ USER ENDPOINTS ============

// Get user profile
app.get('/api/v1/social/users/:userId', async (req, res) => {
  const user = users.get(req.params.userId);
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }
  res.json(user);
});

// Create/update user profile (called by auth service)
app.put('/api/v1/social/users/:userId', async (req, res) => {
  const { username, displayName, avatarUrl } = req.body;
  
  const user: User = {
    id: req.params.userId,
    username,
    displayName,
    avatarUrl,
    followerCount: 0,
    followingCount: 0,
  };
  
  users.set(user.id, user);
  res.json(user);
});

// ============ HEALTH CHECK ============

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'social-community' });
});

// ============ START SERVER ============

const PORT = process.env.PORT || 8082;
server.listen(PORT, () => {
  console.log(`Social Community Service running on port ${PORT}`);
});