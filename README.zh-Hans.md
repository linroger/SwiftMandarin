<p align="center">
  <img src="SwiftMandarin/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" width="128" height="128" alt="SwiftMandarin 应用图标" />
</p>

<h1 align="center">SwiftMandarin</h1>

<p align="center">
  <strong>你的全能中文 ⇄ 英文学习伴侣</strong>
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="README.zh-Hans.md">简体中文</a>
</p>

<p align="center">
  <a href="#功能特性">功能特性</a> •
  <a href="#应用截图">应用截图</a> •
  <a href="#安装方式">安装方式</a> •
  <a href="#使用指南">使用指南</a> •
  <a href="#隐私保护">隐私保护</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017%2B%20|%20iPadOS%2017%2B%20|%20macOS-blue" alt="平台" />
  <img src="https://img.shields.io/badge/Swift-6.2-orange" alt="Swift" />
  <img src="https://img.shields.io/badge/SwiftUI-Liquid%20Glass-purple" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="许可证" />
</p>

---

## 概述

**SwiftMandarin** 是一款设计精美的 Apple 原生应用，将强大的翻译、智能的生词本和高效的间隔重复闪卡学习融为一体。应用完全基于 SwiftUI 与 Apple 翻译框架构建，在 iPhone、iPad 和 Mac 上提供一致的高品质语言学习体验。

无论你是刚开始学中文的英语使用者、正在学英语的中文母语者，还是双语学习者，SwiftMandarin 都能提供你需要的全部工具。

两个方向是**完全镜像**的。英语母语者学中文，和中文母语者学英语，用的是同一套功能，只是两种语言互换——而不是在单向应用外面套一层翻译好的菜单。在设置里选择你的身份，整个应用就会随之调转：正在学的词占据主标题，讲解使用你已经会的语言，注音也会在拼音与国际音标之间切换。

### 为什么选择 SwiftMandarin？

- **原生 Apple 体验**：从零开始使用 SwiftUI 和 Apple Liquid Glass 设计语言打造
- **隐私优先**：核心功能完全在设备端运行——无账号、无跟踪、无需联网
- **智能学习**：间隔重复算法自动适应你的学习节奏
- **可选 AI 能力**：自带服务商——Apple Intelligence（端上）、本地 Ollama 服务器或云端模型——用于词语讲解、照片清理和作业批改
- **拍照与照片 OCR**：扫描课本、路牌和练习册，随后翻译并学习其中的文字
- **精美可视化**：GitHub 风格的活动热力图和交互式图表记录你的学习进度
- **跨平台**：iPhone、iPad、Mac 全平台无缝体验，界面针对各平台优化
- **两个方向完全镜像**：英→中与中→英是同一个应用的两面，连注音体系和哪个词用大号字都相互对应
- **可切换的双语界面**：整个应用支持英文和简体中文，随时在设置中一键切换

---

## 功能特性

### 🏠 首页 — 每日学习的起点

- **打开即有方向**：首页展示连续学习天数、每日目标圆环，以及下一步该做什么
- **立即复习**：一键开始智能复习——真正到期的卡片加上每日限额内的新卡
- **每日一词**：每天从你自己的词汇中确定性地挑选一个词，带声调着色拼音和一键朗读
- **继续阅读**：直接回到上次阅读的文本
- **首次启动引导**：三步设置学习方向、每日目标和可选的 AI

### 🗂️ 现代间隔重复（FSRS）

- **FSRS-4.5 调度器**：SM-2 的现代继任者——按卡片记录稳定性与难度，采用真实遗忘曲线，给出诚实的复习间隔
- **间隔预览**：每个评分按钮（重来 / 较难 / 良好 / 简单）都显示下次见到卡片的确切时间
- **本轮重学队列**：答错的卡片会在同一轮中再次出现，直到答对为止
- **每日新卡限额**，每轮结束后展示未来 7 天复习预测
- **无缝迁移**：现有 SM-2 进度自动转换

### 📖 沉浸式阅读与 AI 故事工坊

- **想读就读**：粘贴、自己写或导入文本，建立你的阅读库
- **点按查词**：当前段落中的每个词都可交互，并带拼音注音
- **AI 分级故事**：生成符合你水平的故事，尽量使用你已保存的词汇
- **逐段翻译与朗读**、阅读进度，以及"约 % 已认识"的词汇覆盖率估算

### 💬 AI 对话伙伴

- **真实场景角色扮演**：咖啡馆、问路、购物、自我介绍、旅行、看医生或自由聊天
- **语音或文字**：内置语音输入；对方用你正在学习的语言回复
- **温和纠错**：伙伴会用你的母语指出错误
- **每条消息**都可展开拼音与翻译，并支持一键朗读

### 🎯 练习中心

- **选择题**：从你的词汇出题，干扰项优先选择相同词性
- **听写**：先听后写，逐字对比显示差异
- **声调训练**：双音节声调组合练习，并给出个人易混淆声调洞察

### 🔤 智能翻译

- **双向翻译**：基于 Apple 端上翻译框架，在英文与中文之间自由互译
- **交互式词语分析**：点按任意中文词语即可查看：
  - 带声调的拼音
  - 词性分类
  - 单词释义
  - 快速保存、复制、朗读
- **声调着色拼音**：用颜色直观区分声调：
  - 🔴 一声（阴平）
  - 🟢 二声（阳平）
  - 🔵 三声（上声）
  - 🟣 四声（去声）
  - ⚫ 轻声
- **注音文字显示**：拼音优雅地标注在汉字上方（也可设置为下方或行内）
- **自动翻译选项**：边输入边翻译，或粘贴后立即翻译
- **语音朗读**：使用 Apple 系统语音，或自愿开启 MiniMax AI 语音，把中英文朗读保存为可复用的 MP3

### 🧩 多模态翻译

- **照片翻译**：选取课本、菜单或路牌的照片，SwiftMandarin 自动识别并翻译其中文字
- **实时相机扫描**：将相机对准文字即可实时端上识别（iOS）
- **语言感知 OCR**：可选 自动 / 中文 / English / 双语，确保汉字不会被错认成乱码
- **截图拼接**：把长页面的多张截图合并为一张——重叠区域自动去除——再整体翻译
- **AI 照片清理（可选）**：将扫描文字交给所选 AI 服务商修正 OCR 错误后再翻译
- **清理过程透明**：AI 清理生效时会显示徽章，可一键切回原始识别文字；清理无法运行时也会明确提示，绝不静默失败
- **提取重点词汇**：从任意扫描段落中提取最有用的词汇，一键保存
- **计入学习统计**：照片翻译会和文字翻译一样写入历史记录与每日学习活动
- **录音或导入音频**：直接录制语音或选择不超过 60 秒的音频文件，在本地预听后转写到同一个可编辑原文区
- **转写并翻译**：一步完成转写和既有翻译流程，同时保留原始转写供你检查与修改
- **两种转写引擎**：Apple 语音识别会下载并使用所选语言的设备端模型（首次使用时显示下载进度）；也可以把音频发送给**你所选择的** AI 服务商——上传前，面板会用文字明确写出目的地

### 🎙️ 语音翻译

- **实时语音翻译**：边说话边查看实时转写与翻译
- **点按学习**：点按转写文本中的任意词语即可查看详情并保存
- **双语朗读**：词语和译文都能朗读
- **双向回填**：采用语音翻译结果时，原文与译文会同时填入翻译页，并记录到历史

### 🤖 AI 增强功能（可选，自带服务商）

- **十大服务商任选**：Apple Intelligence（端上）、本地 **Ollama** 服务器，或云端模型——**OpenAI、Claude、DeepSeek、豆包、通义千问、Kimi、智谱、MiniMax**
- **详尽词语讲解**：生成包含语义辨析、语法用法、例句、同义词和搭配的学习卡片
- **实时模型列表**：输入 API 密钥即可直接从服务商 API 拉取可用模型
- **连接测试与能力标识**：一键验证密钥、端点和模型的完整链路；徽章直观显示该服务商是否支持视觉（图像）与严格 JSON 模式
- **密钥安全存储**：API 密钥保存在系统**钥匙串**中，绝不写入明文文件或上传云端
- **可选 MiniMax AI 语音**：实时刷新账户中的普通话/英文音色，选择最新 Speech 2.8 模型或兼容旧版 2.6/02/01 模型，让所有朗读按钮统一使用 MiniMax TTS；生成的 MP3 持久保存，之后重播不再发起付费请求，并可分享或导出
- **批量 AI 分析与音频**：分析缺少结果的已保存词语，并可在准确确认新增付费请求数和字符数后，批量预生成去重且持久保存的中英文 MiniMax 音频
- **自动翻译新单词**：开启后，你保存的每个词——无论来自翻译、拍照、阅读器、快捷指令还是导入——都会由所选服务商在后台翻译并分析，之后打开即可直接看到完成的分析。队列会去重、设有上限、重启后自动恢复、在手动批处理运行时让行、多次失败后自动暂停，并且绝不会生成付费音频
- **学习者模式**：告诉应用你是「英语母语学中文」「中文母语学英语」还是「双语学习」——默认设置随之自动调整
- **完全可选**：不开启 AI，所有核心功能依然完整可用

### ✅ AI 作业批改

- **拍照批改**：上传练习册照片（答案单独成页也可以），由具备视觉能力的 AI 批改每一道题
- **逐题反馈**：每道题给出 ✓/✗ 判定、正确答案和简短讲解
- **诚实报错**：模型读不出题目时（页面空白、模型不支持图像等），会给出明确的双语错误提示和改进建议——绝不会悄悄返回「0/0」
- **整句朗读**：每道题都展示完整英文句子并配有 🔊 按钮，方便练习发音
- **错题词汇**：把答错的单词直接存入词汇本——每条记录同时保留**正确答案和你写的答案**（✓ 正确 · ✗ 你的）
- **自定义批改要求**：可附加批改说明（例如「三年级英语词汇，拼写从严」）
- **灵活输入**：支持从照片图库、文件 App/访达添加，或直接拖拽

### 📚 词汇管理

- **快捷保存**：在翻译、短语或词语详情中一键保存生词
- **灵活整理**：按添加日期、字母顺序或拼音排序
- **强大搜索**：按汉字、拼音或英文释义查找
- **连续浏览**：在 iPhone 和 iPad 上左右滑动词语详情，或使用“上一个/下一个”控件，无需返回列表；浏览顺序始终跟随当前搜索和排序
- **完整词条信息**：每个保存的词条包含：
  - 汉字
  - 带声调拼音
  - 英文释义
  - 词性
  - 保存日期
- **导出选项**：以 CSV、JSON 或纯文本格式分享词汇表，便于备份或在其他应用中使用

### 🧠 间隔重复学习

- **自适应算法**：基于 SM-2 的间隔重复算法在最佳时间安排复习
- **多种卡组来源**：
  - 内置常用词汇卡组
  - 你保存的词汇
  - 合并卡组全面复习
- **学习模式**：
  - 全部卡片：复习所有内容
  - 待复习：专注今天到期的卡片
  - 新卡片：学习还没见过的词汇
  - 困难卡片：专攻难记的词
- **掌握度跟踪**：从「新词」到「已掌握」共五个等级
- **键盘操作**（macOS/iPad）：方向键切换卡片，空格键翻面

### 📊 学习数据分析

- **GitHub 风格活动热力图**：直观展示过去一年的每日学习活动
- **交互式环形图**：
  - 掌握进度：查看各学习阶段的分布
  - 词性分布：按名词、动词、形容词等分类统计
  - 点按扇区可高亮并查看详细数量
- **堆叠柱状图**：按词性跟踪每日新学词汇
- **核心指标面板**：
  - 当前连续学习天数与最佳纪录
  - 累计保存词汇
  - 学习过的卡片
  - 完成的复习次数
  - 每日平均
- **平台自适应布局**：针对 iPhone（6 个月）、iPad 和 Mac（全年）优化展示

### 💬 常用短语

- **实用分类**：按场景整理的必备短语：
  - 问候与社交
  - 基础表达
  - 旅行与交通
  - 餐饮美食
  - 购物砍价
  - 问路导航
  - 紧急求助
  - 时间与数字
- **完整短语详情**：每条短语都有汉字、拼音和英文
- **快捷操作**：即点即用的朗读、复制、保存
- **搜索功能**：按中文、拼音或英文查找短语

### 🕐 翻译历史

- **完整记录**：键入、拍照、语音和快捷指令产生的翻译都会自动保存（可关闭）
- **搜索与筛选**：全文搜索，外加方向筛选（EN → 中 / 中 → EN）
- **快速恢复**：点按任意历史记录即可恢复到翻译器
- **丰富操作**：
  - 恢复翻译
  - 反向翻译
  - 复制词条
  - 复制到剪贴板
  - 删除单条，或确认后清空全部

### ⚙️ 个性化设置

- **语言与学习**：
  - 学习者模式（英→中、中→英或双语）——会重新调转整个应用，包括界面语言
  - 应用语言切换（English / 中文），与学习者模式保持同步
  - 双语朗读（先读所学语言，再读母语释义）
  - 拼音显示选项（位置、声调颜色）仅对学中文的用户显示——中文母语者无需配置
- **AI 服务商**：
  - 选择服务商、输入 API 密钥、拉取实时模型列表、端到端测试连接
  - 一目了然地查看服务商是否支持视觉（图像）和 JSON 模式
  - 开关 AI 照片清理
- **AI 语音**：
  - 全局开关 MiniMax 语音，无需逐个修改朗读按钮
  - 选择 API 区域以及最新 Speech 2.8 或兼容旧版模型；从所选 MiniMax 账户实时刷新易读的中英文音色名称，并保留最近一次公开目录供离线使用
  - 试听会直接测试 MiniMax 本身，不再用系统语音掩盖失败；还可管理、重播、分享、导出或删除已保存的 MP3
  - 在“批量 AI 分析与音频”中选择仅学习语言或中英文，检查准确的新增请求数与字符数，再以缓存优先、无自动播放的方式生成音频
- **翻译偏好**：
  - 自动翻译开关
  - 粘贴即翻译
  - 默认翻译方向
  - 照片扫描语言（自动 / 中文 / English / 双语）
- **输出选项**：
  - 自动复制到剪贴板
  - 历史记录开关
- **显示设置**：
  - 显示/隐藏拼音
  - 拼音位置：汉字上方、下方或行内
  - 声调颜色
  - 文字大小调节
- **数据管理**：
  - 导入/导出词汇（CSV、JSON、TXT）
  - 清空词汇
  - 清空历史
  - 重置学习进度

### 🔄 两个学习方向

在**设置 → 我是…**中选择身份，应用会围绕你重新组织。界面语言*即*你的母语，因此两项设置始终保持同步——选择「中文母语者学英语」，界面会切换为中文、学习材料切换为英文，一步到位。

|                    | 英语母语者学中文        | 中文母语者学英语              |
| ------------------ | ----------------------- | ----------------------------- |
| 界面语言           | English                 | 简体中文                      |
| 生词本主标题       | 中文词，大号字          | 英文词，大号字                |
| 次要行             | 英文释义，小号字        | 中文释义，小号字              |
| 注音               | 带声调颜色的拼音        | 带重音标记的国际音标（`/kəˈmɪt/`） |
| AI 讲解使用的语言  | English                 | 简体中文                      |
| 可点击的逐词文本   | 中文，上方标注拼音      | 英文单词卡片                  |
| 朗读               | 中文优先                | 英文优先                      |
| 声调训练           | 提供                    | 隐藏（无需训练）              |

任何一个方向都不是另一个方向的简化版：反向模式同样提供完整的构词讲解、同样质量的例句和同样的朗读覆盖——只是把注音体系、字号和提示语的语言一并对调。

### 🌐 本地化

- **完整双语支持**：整个界面——每个标签页、页面、弹窗和提醒——都提供英文和简体中文版本
- **应用内语言切换**：随时在**设置 → 语言**中切换整个应用的语言，独立于系统语言，无需重启
- **智能默认**：首次启动时跟随设备语言偏好
- **地道用语**：所有翻译均经过准确性、一致性与自然度审校（敬语「您」、统一术语、保留格式占位符）

---

## 应用截图

### macOS

在 Mac 上体验 SwiftMandarin 的完整能力：宽敞的边栏导航和全面的数据可视化。

<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.24.47@2x.png" width="45%" alt="macOS - 翻译页面" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.25.06@2x.png" width="45%" alt="macOS - 学习统计" />
</p>
<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-23%20at%2016.25.12@2x.png" width="45%" alt="macOS - 闪卡学习" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-02-11%20at%2004.17.56@2x.png" width="45%" alt="macOS - 常用短语" />
</p>
<p align="center">
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-06-07%20at%2023.28.05@2x.png" width="45%" alt="macOS - AI 作业批改（上传）" />
  <img src="Screenshots/macOS%20Screenshots/SwiftMandarin%202026-06-07%20at%2023.28.11@2x.png" width="45%" alt="macOS - AI 作业批改（结果与朗读）" />
</p>

### iPhone

为移动场景优化的紧凑布局与直观的标签导航。

<p align="center">
  <img src="Screenshots/iOS%20Screenshots/IMG_9055.PNG" width="24%" alt="iPhone - 翻译" />
  <img src="Screenshots/iOS%20Screenshots/IMG_9056.PNG" width="24%" alt="iPhone - 统计" />
  <img src="Screenshots/iOS%20Screenshots/IMG_9057.PNG" width="24%" alt="iPhone - 学习" />
  <img src="Screenshots/iOS%20Screenshots/IMG_8532.PNG" width="24%" alt="iPhone - 词汇" />
</p>

### iPad

两全其美——宽屏布局加自适应边栏导航。

<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0588.PNG" width="45%" alt="iPad - 翻译" />
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0589.PNG" width="45%" alt="iPad - 词汇" />
</p>
<p align="center">
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0590.PNG" width="45%" alt="iPad - 学习" />
  <img src="Screenshots/iPadOS%20Screenshots/IMG_0591.PNG" width="45%" alt="iPad - 短语" />
</p>

---

## 安装方式

### App Store（推荐）

在 [App Store](https://apps.apple.com/app/swiftmandarin) 下载 SwiftMandarin，支持 iPhone、iPad 和 Mac。

### macOS DMG 安装包

1. 从 [Releases](https://github.com/linroger/SwiftMandarin/releases) 下载最新 DMG
2. 打开 `SwiftMandarin-4.2.0-macOS.dmg`
3. 将 `SwiftMandarin.app` 拖入「应用程序」文件夹
4. 从「应用程序」启动 SwiftMandarin

> **提示**：如果 macOS 门禁（Gatekeeper）弹出警告，请右键点按应用，选择**打开**，然后确认。

### 从源码构建

**环境要求：**
- Xcode 26+
- Swift 6.2+
- iOS 17.0+ / macOS 26.2+（部署目标）

```bash
# 克隆仓库
git clone https://github.com/linroger/SwiftMandarin.git
cd SwiftMandarin

# 在 Xcode 中打开
open SwiftMandarin.xcodeproj
```

在 Xcode 中：
1. 选择 `SwiftMandarin` scheme
2. 选择目标设备（iPhone、iPad 或 My Mac）
3. 按 ⌘R 构建并运行

**命令行构建：**
```bash
xcodebuild -project SwiftMandarin.xcodeproj -scheme SwiftMandarin -configuration Release -destination 'platform=macOS' build
```

---

## 使用指南

### 快速上手

1. 在 iPhone、iPad 或 Mac 上**启动 SwiftMandarin**
2. 在翻译页的输入框中**输入文字**
3. **点按翻译**，或开启自动翻译即时出结果
4. **点按任意中文词语**查看拼音、释义和保存选项

### 积累词汇

1. 翻译时点按任意中文词语打开详情
2. 点按**保存**加入词汇本
3. 随时在**词汇**标签页查看
4. 用搜索和排序快速定位

### 闪卡学习

1. 进入**学习**标签页
2. 选择卡组来源（内置、我的词汇或全部）
3. 根据目标选择学习模式
4. 点按卡片翻面，然后评价记忆程度
5. 算法会自动安排最佳复习时间

### 跟踪进度

1. 打开**统计**标签页查看学习数据
2. 关注连续学习天数，努力保持
3. 通过活动热力图发现学习规律
4. 点按图表扇区查看详细分布

### 使用短语

1. 打开**短语**标签页
2. 浏览分类或搜索特定短语
3. 点按短语即可听发音
4. 把常用短语保存到词汇本

### 使用多模态工作区

1. 打开**多模态**标签页，选择**图像**或**音频**
2. 图像模式可从照片图库、文件/访达、拖拽或实时相机添加图片，然后选择扫描语言并翻译识别文字
3. 音频模式可录音或导入不超过 60 秒的文件，选择语音语言，再点**转写到编辑器**或**翻译音频**
4. 在原文编辑器检查或修改转写；直接翻译音频也会先回填转写，再运行正常翻译流程
5. 批改作业请从多模态页工具栏打开**作业批改**，添加页面与可选说明后点按**批改**

> 图像 OCR 无需 AI。音频转写使用 Apple Speech；设备不支持端上识别时可能使用 Apple 服务。翻译、AI 照片清理和作业批改遵循设置中的翻译/服务商配置。

### 切换应用语言

1. 打开**设置**（iOS 在「更多」标签页，Mac 按 ⌘,），找到**语言**
2. 选择 **English** 或**中文**——整个界面立即切换

---

## 技术细节

### 架构

- **SwiftUI**：100% SwiftUI，OS 26+ 采用 Liquid Glass 设计体系（iOS 17 起优雅回退到材质效果），覆盖 iOS / iPadOS / macOS / visionOS
- **翻译**：iOS 18+/macOS 使用 Apple 翻译框架（端上运行，保护隐私）；iOS 17 通过 AI 服务商回退，所有翻译功能依旧可用
- **AI（可选）**：十服务商统一抽象——Apple Foundation Models、Ollama，以及通过 `URLSession` 访问的 OpenAI 兼容 / Anthropic 云端 API——支撑词语讲解、照片清理与作业批改
- **OCR**：Vision 框架，支持语言感知识别（`PhotoTextRecognitionService`）
- **语音**：AVFoundation 提供系统朗读、录音和播放；可选 MiniMax `/v1/t2a_v2` 语音会持久保存为本地 MP3；Speech 框架负责实时及文件转写
- **NLP**：NaturalLanguage 框架完成中文分词与词性分析
- **本地化**：字符串目录（`Localizable.xcstrings`，600+ 词条，完整双语覆盖）+ `LocalizationManager` 运行时切换 `.lproj` 实现应用内换语言
- **存储**：UserDefaults + Codable 本地存储，并自动保留最近一次完好备份——数据损坏也不会悄悄清空词汇、历史或学习进度；API 密钥存于系统钥匙串
- **App Intents / 快捷指令**：通过 Siri 与快捷指令完成翻译、查词、开始复习、扫描等操作

### 文件结构

```
SwiftMandarin/
├── Views/
│   ├── TranslateView.swift          # 主翻译界面
│   ├── PhotoTranslateView.swift     # 拍照 / OCR 翻译
│   ├── WorkbookGradingView.swift    # AI 作业批改
│   ├── HistoryTabView.swift         # 翻译历史
│   ├── VocabularyView.swift         # 词汇管理
│   ├── LearnView.swift              # 闪卡学习
│   ├── PhrasesView.swift            # 常用短语
│   ├── StatsView.swift              # 数据面板
│   ├── MacOSSettingsView.swift      # 设置（macOS）
│   ├── MoreView.swift               # 设置中心（iOS）
│   └── Components/                  # 相机扫描、语音翻译、AI 卡片等
├── Models/
│   ├── SavedTerm.swift              # 词汇模型
│   ├── AIModelSettings.swift        # AI 服务商与配置
│   ├── AppPreferences.swift         # 学习者模式、扫描语言、朗读
│   ├── LocalizationManager.swift    # 应用内语言切换
│   ├── LearningCard.swift           # 闪卡模型
│   └── TranslationHistory.swift     # 历史模型
├── Services/
│   ├── CloudAIService.swift         # 云端 AI（OpenAI 兼容 + Anthropic）
│   ├── AIWordExplanationService.swift # 讲解、词汇提取、批改
│   ├── PhotoTextRecognitionService.swift # Vision OCR
│   ├── KeychainHelper.swift         # 密钥安全存储
│   ├── PinyinConverter.swift        # 拼音转换
│   ├── SpeechService.swift          # 语音朗读
│   ├── ChineseTextAnalyzer.swift    # NLP 分析
│   └── ClipboardService.swift       # 剪贴板
├── Intents/                         # App Intents / Siri 快捷指令
└── Localizable.xcstrings            # 英文 + 简体中文字符串
```

---

## 隐私保护

SwiftMandarin 以隐私为核心原则：

- **无需账号**：所有功能无需注册即可使用
- **默认本地存储**：词汇、历史、进度、录制/导入的工作音频与 AI 生成语音都保存在应用本地容器中，除非你主动导出
- **端上翻译**：Apple 翻译框架在设备端处理文本
- **零跟踪**：没有分析、没有遥测、没有第三方跟踪 SDK
- **核心功能离线可用**：翻译、词汇、闪卡、短语、统计和端上 OCR 完全离线工作（下载语言包后）
- **AI 完全自愿**：云端 AI 功能在*你*选择服务商并添加密钥之前始终关闭。Apple Intelligence 和 Ollama 在本地运行；云端服务商只会收到你主动提交的文字或图片。开启 MiniMax AI 语音后，你要求朗读的文字会发送给 MiniMax。API 密钥始终保存在钥匙串中，只发送给对应的服务商。

你的学习旅程只属于你自己。

---

## 系统要求

| 平台 | 最低版本 |
|--------|----------------|
| iOS      | 17.0+          |
| iPadOS   | 17.0+          |
| macOS    | 26.2+          |

**各 iOS 版本的功能差异** — 应用会自动适配系统能力：

| 功能 | iOS 17 | iOS 18 – 25 | iOS 26+ |
|---|---|---|---|
| 翻译（翻译 / 拍照 / 语音页） | 通过你配置的 AI 服务商 | Apple 端上翻译 | Apple 端上翻译 |
| 点词查询、截图与快捷指令翻译 | 通过 AI 服务商 | 通过 AI 服务商 | Apple 端上翻译 |
| 实时语音转写 | ✓（SFSpeechRecognizer） | ✓（SFSpeechRecognizer） | ✓（SpeechAnalyzer，全程端上） |
| Apple Intelligence 服务商 | — | — | ✓ |
| 云端 AI 服务商、Ollama、OCR、词汇、闪卡、统计、短语 | ✓ | ✓ | ✓ |
| Liquid Glass 设计 / 自适应边栏标签栏 | 材质效果回退 / 经典标签栏 | 材质效果回退 / ✓ | ✓ / ✓ |

**语言包**（iOS 18+/macOS）：要使用端上翻译，请在 系统设置 > 通用 > 语言与地区 > 翻译语言 中下载中英语言包。iOS 17 请改为在 设置 → AI 中配置 AI 服务商。

---

## 支持

- **问题反馈**：[GitHub Issues](https://github.com/linroger/SwiftMandarin/issues)
- **讨论交流**：[GitHub Discussions](https://github.com/linroger/SwiftMandarin/discussions)

---

## 许可证

SwiftMandarin 基于 MIT 许可证发布。详见 [LICENSE](LICENSE)。

---

## 致谢

- Apple 翻译、Vision、Speech 与 NaturalLanguage 框架
- Apple Foundation Models 端上 AI
- [ollama-swift](https://github.com/mattt/ollama-swift) 本地模型接入
- 可选的用户自配 AI 服务商（OpenAI、Anthropic、DeepSeek、豆包、通义千问、Kimi、智谱、MiniMax）
- 带来 Liquid Glass 与现代 UI 组件的 SwiftUI 团队
- 提供灵感与最佳实践的开源社区

---

<p align="center">
  <strong>学中文，用 Apple 的方式。</strong>
</p>

<p align="center">
  用 ❤️ 和 SwiftUI 打造
</p>
