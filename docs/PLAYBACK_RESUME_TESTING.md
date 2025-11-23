# 播放恢复通知测试指南

## 🧪 测试步骤

### 方法一：使用开发者选项测试按钮

1. **打开开发者模式**
   - 进入"我的"页面
   - 点击右上角"开发者模式"

2. **切换到"设置"标签页**

3. **点击"测试播放恢复通知"按钮**
   - 如果有保存的播放状态，将使用真实歌曲信息
   - 如果没有，将使用测试数据
   - 通知会立即显示

4. **检查通知**
   - Android：下拉通知栏查看
   - Windows：右下角 Toast 通知
   - 通知应该包含"继续播放"和"忽略"两个按钮

### 方法二：模拟真实使用场景

1. **播放一首歌**
   - 播放任意歌曲超过5秒
   - 等待至少10秒（自动保存间隔）或暂停（立即保存）

2. **关闭应用**
   - 完全退出应用（不要只是切换到后台）

3. **重新打开应用**
   - 等待2秒（启动延迟）
   - 应该会弹出恢复播放通知

4. **测试操作**
   - 点击"继续播放"：应该从上次位置继续
   - 点击"忽略"：清除保存的状态

## 🔍 调试日志

打开开发者选项-日志标签页，查看以下关键日志：

### 启动时的日志
```
⏰ [Main] 将在2秒后检查播放恢复状态...
🔄 [Main] 开始检查播放恢复状态...
🔍 [PlaybackResumeService] 开始检查启动状态...
📱 [PlaybackResumeService] 正在获取上次播放状态...
🔍 [PlaybackStateService] 开始读取播放状态...
📦 [PlaybackStateService] SharedPreferences 数据:
   trackJson: 存在
   positionSeconds: 120
   timestamp: 1234567890000
   isFromPlaylist: false
⏰ [PlaybackStateService] 播放记录时间: 2025-11-23 10:00:00
⏰ [PlaybackStateService] 时间差: 0小时 5分钟
✅ [PlaybackStateService] 找到播放记录: 歌曲名, 位置: 120秒, 5分钟前
✅ [PlaybackResumeService] 找到播放状态: 歌曲名 - 歌手
   播放位置: 120秒
   最后播放时间: 2025-11-23 10:00:00
🔔 [PlaybackResumeService] 准备显示恢复播放通知...
✅ [PlaybackResumeService] 已显示恢复播放通知
```

### 如果没有播放状态的日志
```
🔍 [PlaybackStateService] 开始读取播放状态...
📦 [PlaybackStateService] SharedPreferences 数据:
   trackJson: null
   positionSeconds: null
   timestamp: null
   isFromPlaylist: false
ℹ️ [PlaybackStateService] 没有保存的播放状态
ℹ️ [PlaybackResumeService] 没有待恢复的播放状态
```

### 播放时的保存日志
```
💾 [PlayerService] 开始定期保存播放状态（每10秒）
💾 [PlaybackStateService] 播放状态已保存: 歌曲名, 位置: 15秒
💾 [PlaybackStateService] 播放状态已保存: 歌曲名, 位置: 25秒
```

## ⚠️ 常见问题

### 1. 通知没有显示

**可能原因：**
- 没有保存的播放状态（播放时间 < 5秒）
- 播放状态已过期（> 24小时）
- 通知权限未授予（Android 13+）
- 通知服务初始化失败

**解决方法：**
- 查看开发者日志确认原因
- Android：设置 > 应用 > Cyrene Music > 通知 > 允许通知
- 使用"测试播放恢复通知"按钮强制测试

### 2. 点击通知按钮没反应

**可能原因：**
- 通知回调未正确设置
- 应用已被系统杀死

**解决方法：**
- 查看日志是否有 `🔔 [PlaybackResumeService] 通知操作: xxx`
- 重启应用并重新测试

### 3. 播放状态没有保存

**可能原因：**
- 播放时间 < 5秒
- 定时器未启动（播放状态不是 playing）
- SharedPreferences 写入失败

**解决方法：**
- 确保歌曲至少播放了5秒
- 暂停后再关闭应用（暂停时会立即保存）
- 查看日志确认是否有保存成功的日志

### 4. 恢复播放后位置不对

**可能原因：**
- seek 操作失败
- 播放器未完全加载

**解决方法：**
- 等待播放器完全加载后再 seek
- 检查日志是否有播放器错误

## 📱 平台特定说明

### Android
- 需要通知权限（Android 13+自动请求）
- 通知样式：Material Design 风格
- 操作按钮：在通知卡片底部

### Windows
- 使用 Windows Toast Notification
- 操作按钮：在通知底部
- 需要应用已在任务栏注册

### iOS/macOS
- 当前版本未完全支持
- 需要额外配置通知权限

## 🎯 验收标准

✅ 播放歌曲 > 5秒后，关闭应用，重新打开能看到通知
✅ 通知显示正确的歌曲名和歌手
✅ 点击"继续播放"能从上次位置继续
✅ 点击"忽略"能清除状态
✅ 超过24小时的记录不会显示通知
✅ 没有播放记录时不显示通知

## 📝 开发日志示例

完整的调试流程示例：

```
1. 播放歌曲
🎵 [PlayerService] 开始播放: 歌曲名 - 歌手
📊 [PlayerService] 开始听歌时长追踪
💾 [PlayerService] 开始定期保存播放状态（每10秒）

2. 等待保存
💾 [PlaybackStateService] 播放状态已保存: 歌曲名, 位置: 15秒

3. 关闭应用

4. 重新打开
⏰ [Main] 将在2秒后检查播放恢复状态...
🔄 [Main] 开始检查播放恢复状态...
✅ [PlaybackStateService] 找到播放记录: 歌曲名, 位置: 15秒, 1分钟前
✅ [PlaybackResumeService] 已显示恢复播放通知

5. 点击"继续播放"
🔔 [PlaybackResumeService] 通知操作: resume
▶️ [PlaybackResumeService] 用户选择继续播放
🎵 [PlayerService] 开始播放: 歌曲名 - 歌手
⏩ [PlayerService] 已跳转到保存的位置: 15秒
✅ [PlaybackResumeService] 播放已恢复
```

