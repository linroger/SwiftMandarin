# SwiftMandarin 新功能开发计划：拍照翻译与小学生学习模式

**创建日期**: 2026-02-23
**状态**: 规划中
**目标用户**: 小学生英语学习者（主要）、语言学习者（次要）

---

## 一、功能概述

### 1.1 核心需求分析

根据用户反馈，主要需求包括：

1. **拍照翻译功能** - 拍摄英文课本/文档，自动识别并翻译成中文
2. **课本内容导入** - 支持输入小学生英语课本内容
3. **单词中文释义** - 显示英文单词对应的中文翻译
4. **语法知识点** - 提供相关语法解释和知识点总结
5. **小学生友好界面** - 简洁、易于理解的界面设计

### 1.2 目标平台

- **主要**: iOS 26+ (iPhone/iPad)
- **次要**: macOS 26+ (仅图片导入，无相机功能)

---

## 二、技术架构研究

### 2.1 Apple 框架选型

#### 图像文字识别 (OCR)

| 框架 | 用途 | 优势 | 适用场景 |
|------|------|------|----------|
| **VisionKit DataScannerViewController** | 实时相机文字扫描 | 系统级UI、实时高亮、手势支持 | iOS相机实时扫描 |
| **Vision RecognizeTextRequest** | 静态图片OCR | 支持多语言、离线处理、精确度高 | 图片导入分析 |
| **VisionKit ImageAnalyzer** | Live Text交互 | 用户可选择文字、复制操作 | 图片预览时的文字交互 |

**推荐方案**:
- 相机扫描: `DataScannerViewController`
- 图片导入: `Vision RecognizeTextRequest` + `ImageAnalyzer`

#### 翻译功能

| 框架 | 用途 | 特点 |
|------|------|------|
| **Translation Framework** | 文本翻译 | 本地离线翻译、隐私保护、已在应用中使用 |

**现有集成**: 应用已使用 `TranslationSession` 进行翻译，可复用。

#### 自然语言处理

| 框架 | 用途 | 能力 |
|------|------|------|
| **NaturalLanguage NLTagger** | 词性分析 | 名词/动词/形容词等识别 |
| **NaturalLanguage NLLanguageRecognizer** | 语言检测 | 自动检测输入语言 |

**现有集成**: `ChineseTextAnalyzer.swift` 已使用 NLTagger，需扩展英文支持。

#### 图片选择

| 框架 | 用途 | 优势 |
|------|------|------|
| **PhotosUI PhotosPicker** | SwiftUI原生图片选择 | 无需权限申请、现代API |

---

## 三、功能模块设计

### 3.1 模块一：拍照翻译 (Photo Translation)

#### 功能描述
用户拍摄或选择图片，应用自动：
1. 识别图片中的英文文字
2. 翻译成中文
3. 显示逐词释义和拼音
4. 提供语法分析和知识点

#### 技术实现

```
┌─────────────────────────────────────────────────────────────┐
│                    Photo Translation Flow                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────┐    ┌──────────┐    ┌──────────────────────┐  │
│  │  相机    │    │  相册    │    │  图片导入            │  │
│  │  拍照    │    │  选择    │    │  (剪贴板/文件)       │  │
│  └────┬─────┘    └────┬─────┘    └──────────┬───────────┘  │
│       │               │                      │               │
│       └───────────────┴──────────────────────┘               │
│                       │                                      │
│                       ▼                                      │
│              ┌────────────────┐                              │
│              │  Vision OCR    │                              │
│              │  文字识别      │                              │
│              └───────┬────────┘                              │
│                      │                                       │
│                      ▼                                       │
│              ┌────────────────┐                              │
│              │  NLTagger      │                              │
│              │  词性标注      │                              │
│              └───────┬────────┘                              │
│                      │                                       │
│                      ▼                                       │
│              ┌────────────────┐                              │
│              │  Translation   │                              │
│              │  翻译服务      │                              │
│              └───────┬────────┘                              │
│                      │                                       │
│                      ▼                                       │
│              ┌────────────────┐                              │
│              │  Grammar       │                              │
│              │  语法分析      │                              │
│              └───────┬────────┘                              │
│                      │                                       │
│                      ▼                                       │
│      ┌───────────────────────────────────┐                   │
│      │         结果展示界面              │                   │
│      │  • 原文 (英文)                    │                   │
│      │  • 译文 (中文)                    │                   │
│      │  • 逐词释义 (点击查看详情)         │                   │
│      │  • 语法知识点                     │                   │
│      │  • 保存到词汇本                   │                   │
│      └───────────────────────────────────┘                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### 新增文件

| 文件路径 | 用途 |
|----------|------|
| `Services/PhotoTextRecognitionService.swift` | 图片OCR服务 |
| `Services/EnglishTextAnalyzer.swift` | 英文文本分析（词性、语法） |
| `Services/GrammarAnalysisService.swift` | 语法规则和知识点生成 |
| `Views/PhotoTranslateView.swift` | 拍照翻译主界面 |
| `Views/Components/CameraScannerView.swift` | 相机扫描组件 |
| `Views/Components/TextRecognitionResultView.swift` | 识别结果展示 |
| `Views/Components/GrammarExplanationView.swift` | 语法知识点展示 |
| `Models/RecognizedText.swift` | 识别文本数据模型 |
| `Models/GrammarPoint.swift` | 语法知识点模型 |

---

### 3.2 模块二：课本导入 (Textbook Import)

#### 功能描述
支持用户手动输入或粘贴英语课本内容，系统自动：
1. 分析文本结构（对话、段落、单词列表）
2. 生成单词列表及释义
3. 创建学习卡片

#### 界面设计

```
┌─────────────────────────────────────────┐
│           课本内容导入                  │
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  输入或粘贴英语课本内容...       │   │
│  │                                 │   │
│  │  Unit 1: Hello!                 │   │
│  │  - Good morning!                │   │
│  │  - How are you?                 │   │
│  │  - I'm fine, thank you.         │   │
│  │                                 │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  📸 拍照导入  │  📁 选择图片     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [        分析内容        ]             │
│                                         │
├─────────────────────────────────────────┤
│  分析结果:                              │
│                                         │
│  📚 识别到 12 个单词                    │
│  📝 识别到 4 个句子                     │
│  💡 识别到 2 个语法点                   │
│                                         │
│  [  生成学习卡片  ]  [  保存到词汇本  ] │
│                                         │
└─────────────────────────────────────────┘
```

#### 新增文件

| 文件路径 | 用途 |
|----------|------|
| `Views/TextbookImportView.swift` | 课本导入主界面 |
| `Models/TextbookContent.swift` | 课本内容模型 |
| `Services/TextbookAnalyzer.swift` | 课本内容分析服务 |

---

### 3.3 模块三：语法知识库 (Grammar Knowledge Base)

#### 功能描述
内置小学英语语法知识库，包括：

1. **词性分类**
   - Noun (名词): apple, book, teacher
   - Verb (动词): run, eat, study
   - Adjective (形容词): big, beautiful, happy
   - 等等...

2. **基础语法规则**
   - 单复数变化规则
   - 现在时/过去时/将来时
   - 疑问句/否定句构造
   - 常见句型模式

3. **知识点关联**
   - 识别句子中的语法点
   - 显示简明的语法解释
   - 提供例句

#### 数据结构

```swift
struct GrammarPoint: Identifiable, Codable {
    let id: String
    let category: GrammarCategory  // tense, plurality, question, etc.
    let name: String               // "一般现在时"
    let englishName: String        // "Simple Present Tense"
    let explanation: String        // 中文解释
    let rules: [String]            // 语法规则列表
    let examples: [GrammarExample] // 例句
    let gradeLevel: Int            // 适用年级 (1-6)
}

struct GrammarExample: Codable {
    let english: String
    let chinese: String
    let highlight: [String]  // 高亮的语法点
}

enum GrammarCategory: String, Codable {
    case tense              // 时态
    case plurality          // 单复数
    case questionForm       // 疑问句
    case negativeForm       // 否定句
    case partOfSpeech       // 词性
    case sentenceStructure  // 句子结构
    case commonPhrases      // 常用短语
}
```

#### 新增文件

| 文件路径 | 用途 |
|----------|------|
| `Models/GrammarPoint.swift` | 语法知识点模型 |
| `Services/GrammarKnowledgeBase.swift` | 语法知识库 |
| `Views/GrammarBrowserView.swift` | 语法浏览界面 |
| `Resources/grammar_data.json` | 内置语法数据 |

---

### 3.4 模块四：逐词释义 (Word-by-Word Translation)

#### 功能描述
对于识别的英文文本：
1. 分词并标注词性
2. 显示每个单词的中文释义
3. 支持点击查看详细信息
4. 可一键保存到词汇本

#### 界面设计 (复用现有 RubyTextView 模式)

```
┌─────────────────────────────────────────────────────────┐
│  原文: The cat is sleeping on the sofa.                │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   The      cat       is     sleeping    on    the      │
│   这/那    猫        是     正在睡觉    在    这/那     │
│   [冠词]  [名词]   [动词]   [动词]    [介词] [冠词]    │
│                                                         │
│   sofa                                                  │
│   沙发                                                  │
│   [名词]                                                │
│                                                         │
├─────────────────────────────────────────────────────────┤
│  💡 语法知识点:                                         │
│  • 现在进行时: be + 动词ing (is sleeping)               │
│  • 介词短语: on the sofa (在沙发上)                     │
└─────────────────────────────────────────────────────────┘
```

#### 新增组件

| 文件路径 | 用途 |
|----------|------|
| `Views/Components/EnglishRubyTextView.swift` | 英文逐词释义视图 |
| `Views/Components/WordChipEnglish.swift` | 英文单词卡片组件 |

---

## 四、实现计划

### 4.1 第一阶段：基础 OCR 功能 (优先级: 高)

**预计工作量**: 2-3 个开发周期

#### 任务清单

- [ ] **P1-1**: 创建 `PhotoTextRecognitionService.swift`
  - 使用 Vision `RecognizeTextRequest` 实现图片OCR
  - 支持多行文本识别
  - 处理识别置信度和边界框

- [ ] **P1-2**: 创建 `CameraScannerView.swift`
  - 集成 `DataScannerViewController` (iOS)
  - 实现实时文字高亮
  - 添加拍照/确认按钮

- [ ] **P1-3**: 创建 `PhotoTranslateView.swift`
  - 整合相机扫描和图片选择
  - 使用 `PhotosPicker` 选择图片
  - 显示识别结果

- [ ] **P1-4**: 集成翻译功能
  - 复用现有 `TranslationSession`
  - 实现英文→中文翻译
  - 批量翻译优化

### 4.2 第二阶段：逐词分析功能 (优先级: 高)

**预计工作量**: 1-2 个开发周期

#### 任务清单

- [ ] **P2-1**: 创建 `EnglishTextAnalyzer.swift`
  - 使用 NLTagger 进行英文分词
  - 词性标注 (noun, verb, adjective, etc.)
  - 句子边界检测

- [ ] **P2-2**: 创建 `EnglishRubyTextView.swift`
  - 复用 RubyTextView 的交互模式
  - 显示单词+中文释义+词性
  - 点击单词显示详情

- [ ] **P2-3**: 扩展 `WordTranslationService.swift`
  - 支持英文单词→中文释义
  - 缓存常用单词翻译
  - 批量翻译接口

### 4.3 第三阶段：语法分析功能 (优先级: 中)

**预计工作量**: 2 个开发周期

#### 任务清单

- [ ] **P3-1**: 创建语法知识库
  - 编写 `grammar_data.json` (小学1-6年级)
  - 创建 `GrammarKnowledgeBase.swift`
  - 实现语法规则匹配

- [ ] **P3-2**: 创建 `GrammarAnalysisService.swift`
  - 句子时态分析
  - 句型识别 (疑问句/否定句/肯定句)
  - 语法知识点提取

- [ ] **P3-3**: 创建 `GrammarExplanationView.swift`
  - 语法知识点卡片
  - 例句展示
  - 相关语法链接

### 4.4 第四阶段：课本导入功能 (优先级: 中)

**预计工作量**: 1 个开发周期

#### 任务清单

- [ ] **P4-1**: 创建 `TextbookImportView.swift`
  - 文本输入区域
  - 图片导入按钮
  - 分析结果预览

- [ ] **P4-2**: 创建 `TextbookAnalyzer.swift`
  - 内容结构分析
  - 单词提取
  - 句子分割

- [ ] **P4-3**: 集成学习卡片生成
  - 自动生成 LearningCard
  - 批量保存到词汇本
  - 创建学习计划

### 4.5 第五阶段：界面优化和集成 (优先级: 低)

**预计工作量**: 1 个开发周期

#### 任务清单

- [ ] **P5-1**: 添加新Tab到主界面
  - 更新 `ContentView.swift`
  - 添加"拍照翻译"Tab
  - 图标和标题设计

- [ ] **P5-2**: 小学生友好界面优化
  - 增大字体和按钮
  - 添加图标和颜色指示
  - 简化操作流程

- [ ] **P5-3**: 学习历史和统计
  - 记录拍照翻译历史
  - 学习进度统计
  - 知识点掌握情况

---

## 五、API 和权限要求

### 5.1 Info.plist 配置

```xml
<!-- 相机权限 (拍照翻译) -->
<key>NSCameraUsageDescription</key>
<string>SwiftMandarin需要访问相机来扫描和翻译文本</string>

<!-- 图片库权限 (已有PhotosPicker不需要) -->
<!-- PhotosPicker 使用系统级隔离，无需显式权限 -->
```

### 5.2 必需框架

```swift
import Vision          // OCR 文字识别
import VisionKit       // DataScannerViewController
import Translation     // 翻译服务 (已使用)
import NaturalLanguage // 词性分析 (已使用)
import PhotosUI        // 图片选择
```

### 5.3 设备要求

| 功能 | 最低要求 |
|------|----------|
| DataScannerViewController | iOS 16+, A12 芯片 |
| Vision OCR | iOS 13+ |
| Translation Framework | iOS 17.4+ |
| PhotosPicker | iOS 16+ |

---

## 六、代码示例

### 6.1 PhotoTextRecognitionService 核心实现

```swift
import Vision
import UIKit

@Observable
final class PhotoTextRecognitionService {

    static let shared = PhotoTextRecognitionService()
    private init() {}

    /// 识别图片中的文字
    func recognizeText(in image: UIImage) async throws -> [RecognizedTextBlock] {
        guard let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return RecognizedTextBlock(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }

                continuation.resume(returning: blocks)
            }

            // 配置识别参数
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US", "en-GB"]  // 英文优先
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

struct RecognizedTextBlock: Identifiable {
    let id = UUID()
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

enum RecognitionError: Error {
    case invalidImage
    case recognitionFailed
}
```

### 6.2 EnglishTextAnalyzer 核心实现

```swift
import NaturalLanguage
import SwiftUI

final class EnglishTextAnalyzer {

    static let shared = EnglishTextAnalyzer()
    private init() {}

    /// 分析英文文本，返回带词性的单词列表
    func analyzeWords(_ text: String) -> [AnalyzedEnglishWord] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)

        var words: [AnalyzedEnglishWord] = []

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: options
        ) { tag, tokenRange in
            let word = String(text[tokenRange])
            let lemma = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
            let partOfSpeech = tag.map { EnglishPartOfSpeech(from: $0) } ?? .unknown

            words.append(AnalyzedEnglishWord(
                text: word,
                lemma: lemma ?? word.lowercased(),
                partOfSpeech: partOfSpeech,
                range: tokenRange
            ))
            return true
        }

        return words
    }

    /// 分析句子结构
    func analyzeSentences(_ text: String) -> [AnalyzedSentence] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [AnalyzedSentence] = []

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            let type = detectSentenceType(sentence)
            let words = analyzeWords(sentence)

            sentences.append(AnalyzedSentence(
                text: sentence,
                type: type,
                words: words
            ))
            return true
        }

        return sentences
    }

    private func detectSentenceType(_ sentence: String) -> SentenceType {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("?") {
            return .question
        } else if trimmed.hasSuffix("!") {
            return .exclamation
        } else {
            // 检测否定句
            let negativePatterns = ["don't", "doesn't", "didn't", "won't", "can't", "not", "no"]
            let lowercased = trimmed.lowercased()
            if negativePatterns.contains(where: { lowercased.contains($0) }) {
                return .negative
            }
            return .declarative
        }
    }
}

struct AnalyzedEnglishWord: Identifiable {
    let id = UUID()
    let text: String
    let lemma: String           // 词根
    let partOfSpeech: EnglishPartOfSpeech
    let range: Range<String.Index>
}

struct AnalyzedSentence: Identifiable {
    let id = UUID()
    let text: String
    let type: SentenceType
    let words: [AnalyzedEnglishWord]
}

enum SentenceType: String {
    case declarative = "陈述句"
    case question = "疑问句"
    case exclamation = "感叹句"
    case negative = "否定句"
}

enum EnglishPartOfSpeech: String {
    case noun = "名词"
    case verb = "动词"
    case adjective = "形容词"
    case adverb = "副词"
    case pronoun = "代词"
    case preposition = "介词"
    case conjunction = "连词"
    case determiner = "限定词"
    case interjection = "感叹词"
    case number = "数词"
    case unknown = "其他"

    init(from tag: NLTag) {
        switch tag {
        case .noun: self = .noun
        case .verb: self = .verb
        case .adjective: self = .adjective
        case .adverb: self = .adverb
        case .pronoun: self = .pronoun
        case .preposition: self = .preposition
        case .conjunction: self = .conjunction
        case .determiner: self = .determiner
        case .interjection: self = .interjection
        case .number: self = .number
        default: self = .unknown
        }
    }

    var color: Color {
        switch self {
        case .noun: return .blue
        case .verb: return .red
        case .adjective: return .green
        case .adverb: return .orange
        case .pronoun: return .purple
        case .preposition: return .cyan
        case .conjunction: return .mint
        case .determiner: return .gray
        case .interjection: return .yellow
        case .number: return .indigo
        case .unknown: return .secondary
        }
    }

    var englishName: String {
        switch self {
        case .noun: return "Noun"
        case .verb: return "Verb"
        case .adjective: return "Adjective"
        case .adverb: return "Adverb"
        case .pronoun: return "Pronoun"
        case .preposition: return "Preposition"
        case .conjunction: return "Conjunction"
        case .determiner: return "Determiner"
        case .interjection: return "Interjection"
        case .number: return "Number"
        case .unknown: return "Other"
        }
    }
}
```

### 6.3 CameraScannerView SwiftUI 封装

```swift
import SwiftUI
import VisionKit

#if os(iOS)
struct CameraScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var isPresented: Bool
    let onTextRecognized: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isPresented && !uiViewController.isScanning {
            try? uiViewController.startScanning()
        } else if !isPresented && uiViewController.isScanning {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: CameraScannerView

        init(_ parent: CameraScannerView) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text):
                parent.recognizedText = text.transcript
                parent.onTextRecognized(text.transcript)
            default:
                break
            }
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            // 更新所有识别到的文本
            let allText = allItems.compactMap { item -> String? in
                if case .text(let text) = item {
                    return text.transcript
                }
                return nil
            }.joined(separator: "\n")

            parent.recognizedText = allText
        }
    }

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }
}
#endif
```

---

## 七、测试计划

### 7.1 功能测试用例

| 测试ID | 测试场景 | 预期结果 |
|--------|----------|----------|
| T1 | 拍摄清晰英文文本 | 正确识别所有文字 |
| T2 | 拍摄模糊/倾斜图片 | 提示重拍或部分识别 |
| T3 | 识别并翻译单句 | 显示中文译文和逐词释义 |
| T4 | 识别长段落 | 正确分句并逐句翻译 |
| T5 | 词性标注准确性 | 90%以上准确率 |
| T6 | 语法知识点匹配 | 正确识别时态/句型 |
| T7 | 保存单词到词汇本 | 成功保存并可在词汇本查看 |
| T8 | 生成学习卡片 | 卡片内容完整可用 |

### 7.2 性能测试

| 测试项 | 目标值 |
|--------|--------|
| 图片OCR响应时间 | < 2秒 (1080p图片) |
| 翻译响应时间 | < 1秒 (单句) |
| 内存使用 | < 100MB 增量 |
| 电池消耗 | 正常使用无明显增加 |

---

## 八、风险和缓解措施

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| OCR识别率低 | 用户体验差 | 提供手动编辑功能；优化拍摄引导 |
| 翻译质量不佳 | 学习效果受影响 | 使用Apple官方翻译API；提供反馈机制 |
| 语法分析不准确 | 知识点错误 | 使用规则引擎而非纯NLP；人工校验语法库 |
| 设备兼容性 | 部分设备不支持 | 优雅降级；提供图片导入替代方案 |

---

## 九、后续扩展计划

1. **语音朗读功能** - 英文原文朗读
2. **手写识别** - 识别手写英文
3. **AR翻译** - 实时相机AR文字翻译叠加
4. **云端同步** - 学习记录跨设备同步
5. **家长模式** - 学习进度报告

---

## 十、参考资料

### Apple 官方文档

- [Vision Framework - Text Recognition](https://developer.apple.com/documentation/vision/recognizing-text-in-images)
- [VisionKit - DataScannerViewController](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller)
- [Translation Framework](https://developer.apple.com/documentation/translation)
- [Natural Language Framework](https://developer.apple.com/documentation/naturallanguage)
- [PhotosUI - PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker)

### 示例代码

- [Locating and displaying recognized text](https://developer.apple.com/documentation/vision/locating-and-displaying-recognized-text)
- [Scanning data with the camera](https://developer.apple.com/documentation/visionkit/scanning-data-with-the-camera)
- [Bringing Photos picker to your SwiftUI app](https://developer.apple.com/documentation/photokit/bringing-photos-picker-to-your-swiftui-app)

---

**文档版本**: 1.0
**最后更新**: 2026-02-23
