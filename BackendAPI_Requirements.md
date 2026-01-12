# 后端接口新增需求文档 (Backend API Requirements)

为了支持流体云播放器新增的“歌手详情”与“歌曲百科”功能，后端基础 URL (`baseUrl`) 需要适配以下新增接口。

## 1. 歌手模块 (Artist Module)

### 获取歌手介绍
- **路由**: `GET /artist/desc`
- **参数**: `id` (int/string) - 歌手 ID
- **描述**: 获取歌手的百科介绍、简介等文字信息。
- **返回数据结构建议**:
```json
{
  "status": 200,
  "briefDesc": "歌手简短介绍",
  "introduction": [
    { "ti": "章节标题", "txt": "章节内容" }
  ]
}
```

### 获取歌手详情 (包含热门歌曲)
- **路由**: `GET /artist/detail`
- **参数**: `id` (int/string) - 歌手 ID
- **描述**: 获取歌手基本信息及热门歌曲列表。
- **返回数据结构建议**:
```json
{
  "status": 200,
  "data": {
    "artist": { "name": "歌手名", "briefDesc": "回复备份简介" },
    "songs": [
      { "id": 123, "name": "歌名", "picUrl": "封面", "artists": "歌手", "album": "专辑" }
    ]
  }
}
```

---

## 2. 歌曲百科模块 (Song Wiki Module)

### 获取歌曲百科摘要
- **路由**: `GET /song/wiki/summary`
- **参数**: `id` (int/string) - 歌曲 ID
- **描述**: 获取歌曲的曲风、语种、详细简介等百科信息。
- **返回数据结构建议**:
```json
{
  "status": 200,
  "data": {
    "wiki": {
      "brief": "歌曲背景/创作简介",
      "styles": ["流行", "民谣"],
      "language": "国语"
    }
  }
}
```

### 获取歌曲音轨元数据
- **路由**: `GET /song/music/detail/get`
- **参数**: `id` (int/string) - 歌曲 ID
- **描述**: 获取歌曲的 BPM、能量、情感等技术性元数据。
- **返回数据结构建议**:
```json
{
  "status": 200,
  "data": {
    "bpm": 120
  }
}
```

---

## 3. 实现指南 (Implementation Tips)

如果你使用的是 **NeteaseCloudMusicApi** (NodeJS 版)，这些接口通常对应以下 API：
- `/artist/desc` -> `artist_desc`
- `/artist/detail` -> `artist_detail`
- `/song/wiki/summary` -> `song_wiki_summary`
- `/song/music/detail/get` -> `song_music_detail_get` (可能需要最新版本)

请确保后端返回的 JSON 结构中包含 `status: 200`，以便 App 正确识别请求成功。
