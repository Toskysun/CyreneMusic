# 播放记忆功能

## 功能概述

这个功能可以记录用户最后播放的歌曲和位置，并在下次应用启动时通过系统通知询问用户是否继续播放。

## 功能特点

1. **自动保存播放状态**
   - 播放歌曲时，每10秒自动保存当前播放位置
   - 暂停播放时，立即保存当前位置
   - 播放位置小于5秒的歌曲不会保存（避免保存刚开始的歌曲）

2. **智能通知提醒**
   - 应用启动2秒后检查是否有待恢复的播放状态
   - 如果有（且在24小时内），显示系统通知询问用户
   - 通知包含两个操作按钮："继续播放" 和 "忽略"
   - **显示专辑封面图片**（Android 和 Windows）

3. **跨平台支持**
   - Android：使用 Android Notification 带操作按钮
   - Windows：使用 Windows Toast Notification 带操作按钮
   - 其他平台：可以显示基础通知

4. **数据持久化**
   - **完全基于云端**：所有播放状态只保存在服务器
   - **需要登录**：必须登录后才能使用播放记忆功能
   - **跨设备同步**：不同设备自动同步最新状态

## 技术实现

### 前端（Flutter）

#### 核心服务

1. **PlaybackStateService** (`lib/services/playback_state_service.dart`)
   - 保存和读取播放状态
   - 使用 `SharedPreferences` 本地存储
   - 包含24小时过期检查

2. **PlaybackResumeService** (`lib/services/playback_resume_service.dart`)
   - 在应用启动时检查播放状态
   - 显示恢复通知
   - 处理用户操作（继续播放/忽略）

3. **NotificationService** (`lib/services/notification_service.dart`)
   - 增强支持带操作按钮的通知
   - 处理通知点击回调
   - 下载并缓存专辑封面图片
   - 在通知中显示封面（Android BigPicture 样式）

4. **PlayerService** (`lib/services/player_service.dart`)
   - 播放时定期保存状态（每10秒）
   - 暂停时立即保存状态
   - 提供 `resumeFromSavedState` 方法恢复播放

#### 数据结构

```dart
class PlaybackState {
  final Track track;           // 歌曲信息
  final Duration position;     // 播放位置
  final DateTime lastPlayTime; // 最后播放时间
  final bool isFromPlaylist;   // 是否来自歌单
}
```

### 后端（Bun + Elysia）

#### API 端点

1. **POST /playback/save** - 保存播放状态
   ```json
   {
     "trackId": "123456",
     "trackName": "歌曲名",
     "artists": "歌手",
     "album": "专辑",
     "picUrl": "封面URL",
     "source": "netease",
     "position": 120,
     "isFromPlaylist": false,
     "platform": "Android"
   }
   ```

2. **GET /playback/last** - 获取上次播放状态
   ```json
   {
     "status": 200,
     "data": {
       "trackId": "123456",
       "trackName": "歌曲名",
       "artists": "歌手",
       "album": "专辑",
       "picUrl": "封面URL",
       "source": "netease",
       "position": 120,
       "isFromPlaylist": false,
       "platform": "Android",
       "updatedAt": 1234567890000
     }
   }
   ```

3. **DELETE /playback/clear** - 清除播放状态

#### 数据库

使用 Bun 内置的 SQLite 数据库 `data/playback.db`：

```sql
CREATE TABLE playback_state (
  user_id INTEGER PRIMARY KEY,
  track_id TEXT NOT NULL,
  track_name TEXT NOT NULL,
  artists TEXT NOT NULL,
  album TEXT NOT NULL,
  pic_url TEXT NOT NULL,
  source TEXT NOT NULL,
  position INTEGER NOT NULL,
  is_from_playlist INTEGER NOT NULL,
  platform TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);
```

**平台信息：**
- 记录播放时的平台（Android、Windows、iOS、macOS、Linux）
- 用于跨设备同步和平台提示

## 使用流程

### 用户视角

1. **播放歌曲**
   - 用户正常播放歌曲
   - 应用在后台自动保存播放位置

2. **关闭应用**
   - 暂停或正在播放的歌曲位置已保存
   - 无需手动操作

3. **再次启动应用**
   - 应用启动2秒后，系统会弹出通知
   - 通知显示：**"继续播放？"** 和 **"上次正在播放：歌曲名 - 歌手"**
   - 用户可以点击：
     - **"继续播放"**：应用会从上次位置继续播放
     - **"忽略"**：清除保存的状态，不做任何操作
     - **不操作**：通知自动消失，下次启动仍会询问

### 开发者视角

#### 启动流程

```dart
void main() async {
  // ... 其他初始化 ...
  
  // 初始化通知服务
  await NotificationService().initialize();
  
  // 检查并显示恢复播放通知（延迟2秒）
  Future.delayed(const Duration(seconds: 2), () {
    PlaybackResumeService().checkAndShowResumeNotification();
  });
  
  runApp(const MyApp());
}
```

#### 保存播放状态

```dart
// PlayerService 中自动调用
void _saveCurrentPlaybackState() {
  if (_currentTrack == null || _state != PlayerState.playing) {
    return;
  }

  if (_position.inSeconds < 5) {
    return; // 播放时间太短，不保存
  }

  PlaybackStateService().savePlaybackState(
    track: _currentTrack!,
    position: _position,
    isFromPlaylist: PlaylistQueueService().hasQueue,
  );
}
```

#### 恢复播放

```dart
// 从保存的状态恢复
await PlayerService().resumeFromSavedState(state);
```

### 封面图片处理

通知服务会自动下载并缓存专辑封面：

```dart
// 下载封面（内部调用）
final coverPath = await _downloadCoverImage(coverUrl);

// Android：使用 BigPictureStyle 显示长方形大图
styleInformation: BigPictureStyleInformation(
  FilePathAndroidBitmap(coverPath),
  largeIcon: FilePathAndroidBitmap(coverPath),
  hideExpandedLargeIcon: true, // 隐藏展开后的方形图标
),

// Windows：圆角正方形封面，显示在应用图标位置
WindowsImage(
  Uri.file(coverPath, windows: true),
  placement: WindowsImagePlacement.appLogoOverride,
),
```

**显示效果：**
- **Android**：通知折叠时显示小圆形图标，展开后显示长方形大图
- **Windows**：圆角正方形封面显示在通知左侧（替代应用图标）

**缓存机制：**
- 封面下载到临时目录：`{tempDir}/notification_covers/`
- 文件名使用URL的hash值，避免重复下载
- 自动重用已下载的封面

**清理缓存：**
```dart
await NotificationService().clearCoverCache();
```

## 配置选项

### 过期时间

默认24小时，可在 `PlaybackStateService.getLastPlaybackState()` 中修改：

```dart
if (timeDiff.inHours > 24) {
  return null; // 修改这里的 24 为其他小时数
}
```

### 最小保存时间

默认5秒，可在 `PlayerService._saveCurrentPlaybackState()` 中修改：

```dart
if (_position.inSeconds < 5) {
  return; // 修改这里的 5 为其他秒数
}
```

### 保存频率

默认每10秒，可在 `PlayerService._startStateSaveTimer()` 中修改：

```dart
_stateSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
  // 修改这里的 10 为其他秒数
  _saveCurrentPlaybackState();
});
```

## 调试日志

播放记忆功能会输出以下日志：

- `💾 [PlaybackStateService] 播放状态已保存`
- `✅ [PlaybackStateService] 找到播放记录`
- `🖼️ [NotificationService] 开始下载封面`
- `✅ [NotificationService] 封面下载完成`
- `🔔 [PlaybackResumeService] 已显示恢复播放通知`
- `▶️ [PlaybackResumeService] 用户选择继续播放`
- `🚫 [PlaybackResumeService] 用户选择忽略`

## 已知限制

1. **Android 13+**：需要用户授予通知权限，否则无法显示恢复通知
2. **iOS**：需要额外配置通知权限（当前未完全支持）
3. **Web**：不支持本地通知，需要使用浏览器通知API

## 未来改进

- [ ] 支持多设备同步（通过后端API）
- [ ] 支持保存整个播放队列
- [ ] 支持保存播放模式（随机/顺序/单曲循环）
- [ ] 添加用户设置开关（允许用户禁用此功能）
- [ ] 支持更多平台（iOS、Web）

## 测试建议

1. **基础测试**
   - 播放一首歌超过5秒
   - 关闭应用
   - 重新打开，检查是否弹出通知
   - 检查通知中是否显示专辑封面

2. **过期测试**
   - 修改系统时间到25小时后
   - 打开应用，应该不会弹出通知

3. **操作测试**
   - 点击"继续播放"，检查是否从保存位置继续
   - 点击"忽略"，检查状态是否清除

4. **边界测试**
   - 播放少于5秒的歌曲，关闭应用，重新打开（不应该弹通知）
   - 多次快速切歌，检查保存的是否是最后一首

5. **封面测试**
   - 查看通知中的封面图片是否正确
   - 检查临时目录是否缓存了封面
   - 测试封面下载失败时的降级处理

## 参考文档

- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)
- [Bun SQLite](https://bun.sh/docs/api/sqlite)

