//
//  GrammarPoint.swift
//  SwiftMandarin
//
//  Grammar knowledge point model for elementary school English learning
//

import Foundation
import SwiftUI

// MARK: - Grammar Category

enum GrammarCategory: String, Codable, CaseIterable {
    case tense = "时态"
    case sentenceStructure = "句型"
    case partOfSpeech = "词性"
    case plurality = "单复数"
    case questionForm = "疑问句"
    case negativeForm = "否定句"
    case comparison = "比较级"
    case commonPhrases = "常用短语"
    
    var englishName: String {
        switch self {
        case .tense: return "Tense"
        case .sentenceStructure: return "Sentence Structure"
        case .partOfSpeech: return "Parts of Speech"
        case .plurality: return "Singular & Plural"
        case .questionForm: return "Question Forms"
        case .negativeForm: return "Negative Forms"
        case .comparison: return "Comparison"
        case .commonPhrases: return "Common Phrases"
        }
    }
    
    var icon: String {
        switch self {
        case .tense: return "clock"
        case .sentenceStructure: return "text.alignleft"
        case .partOfSpeech: return "textformat"
        case .plurality: return "plus.forwardslash.minus"
        case .questionForm: return "questionmark.circle"
        case .negativeForm: return "xmark.circle"
        case .comparison: return "arrow.left.arrow.right"
        case .commonPhrases: return "text.quote"
        }
    }
    
    var color: Color {
        switch self {
        case .tense: return .blue
        case .sentenceStructure: return .purple
        case .partOfSpeech: return .green
        case .plurality: return .orange
        case .questionForm: return .cyan
        case .negativeForm: return .red
        case .comparison: return .mint
        case .commonPhrases: return .indigo
        }
    }
}

// MARK: - Grammar Example

struct GrammarExample: Codable, Identifiable {
    var id: String { english }
    let english: String
    let chinese: String
    let highlight: [String]  // Words to highlight as grammar point
    
    init(english: String, chinese: String, highlight: [String] = []) {
        self.english = english
        self.chinese = chinese
        self.highlight = highlight
    }
}

// MARK: - Grammar Point

struct GrammarPoint: Identifiable, Codable {
    let id: String
    let category: GrammarCategory
    let name: String           // Chinese name
    let englishName: String
    let explanation: String    // Chinese explanation
    let rules: [String]        // Grammar rules
    let examples: [GrammarExample]
    let gradeLevel: Int        // 1-6 for elementary school
    let keywords: [String]     // Keywords that trigger this grammar point
    
    init(
        id: String,
        category: GrammarCategory,
        name: String,
        englishName: String,
        explanation: String,
        rules: [String],
        examples: [GrammarExample],
        gradeLevel: Int,
        keywords: [String] = []
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.englishName = englishName
        self.explanation = explanation
        self.rules = rules
        self.examples = examples
        self.gradeLevel = gradeLevel
        self.keywords = keywords
    }
}

// MARK: - Grammar Knowledge Base

final class GrammarKnowledgeBase {
    
    static let shared = GrammarKnowledgeBase()
    
    /// All grammar points
    let allPoints: [GrammarPoint]
    
    private init() {
        self.allPoints = Self.buildKnowledgeBase()
    }
    
    /// Get grammar points by category
    func points(for category: GrammarCategory) -> [GrammarPoint] {
        allPoints.filter { $0.category == category }
    }
    
    /// Get grammar points by grade level
    func points(forGrade grade: Int) -> [GrammarPoint] {
        allPoints.filter { $0.gradeLevel <= grade }
    }
    
    /// Search grammar points by keyword
    func search(_ query: String) -> [GrammarPoint] {
        let lowercased = query.lowercased()
        return allPoints.filter { point in
            point.name.lowercased().contains(lowercased) ||
            point.englishName.lowercased().contains(lowercased) ||
            point.explanation.lowercased().contains(lowercased) ||
            point.keywords.contains { $0.lowercased().contains(lowercased) }
        }
    }
    
    /// Find matching grammar points for a sentence
    func findMatchingPoints(for sentence: String) -> [GrammarPoint] {
        let lowercased = sentence.lowercased()
        return allPoints.filter { point in
            point.keywords.contains { keyword in
                lowercased.contains(keyword.lowercased())
            }
        }
    }
    
    // MARK: - Build Knowledge Base
    
    private static func buildKnowledgeBase() -> [GrammarPoint] {
        var points: [GrammarPoint] = []
        
        // MARK: Tense - 时态
        
        points.append(GrammarPoint(
            id: "simple_present",
            category: .tense,
            name: "一般现在时",
            englishName: "Simple Present Tense",
            explanation: "表示经常发生的动作、习惯、真理或现在的状态",
            rules: [
                "主语 + 动词原形 (I/You/We/They)",
                "主语 + 动词+s/es (He/She/It)",
                "否定: don't/doesn't + 动词原形",
                "疑问: Do/Does + 主语 + 动词原形?"
            ],
            examples: [
                GrammarExample(english: "I go to school every day.", chinese: "我每天上学。", highlight: ["go"]),
                GrammarExample(english: "She likes apples.", chinese: "她喜欢苹果。", highlight: ["likes"]),
                GrammarExample(english: "The sun rises in the east.", chinese: "太阳从东方升起。", highlight: ["rises"])
            ],
            gradeLevel: 3,
            keywords: ["every day", "always", "usually", "often", "sometimes", "never"]
        ))
        
        points.append(GrammarPoint(
            id: "present_continuous",
            category: .tense,
            name: "现在进行时",
            englishName: "Present Continuous Tense",
            explanation: "表示现在正在进行的动作",
            rules: [
                "主语 + am/is/are + 动词ing",
                "否定: 主语 + am/is/are + not + 动词ing",
                "疑问: Am/Is/Are + 主语 + 动词ing?"
            ],
            examples: [
                GrammarExample(english: "I am reading a book.", chinese: "我正在读书。", highlight: ["am", "reading"]),
                GrammarExample(english: "She is cooking dinner.", chinese: "她正在做晚饭。", highlight: ["is", "cooking"]),
                GrammarExample(english: "They are playing football.", chinese: "他们正在踢足球。", highlight: ["are", "playing"])
            ],
            gradeLevel: 4,
            keywords: ["am", "is", "are", "ing", "now", "at the moment", "look", "listen"]
        ))
        
        points.append(GrammarPoint(
            id: "simple_past",
            category: .tense,
            name: "一般过去时",
            englishName: "Simple Past Tense",
            explanation: "表示过去发生的动作或存在的状态",
            rules: [
                "主语 + 动词过去式",
                "规则变化: 动词 + ed",
                "不规则动词需要记忆 (go→went, have→had)",
                "否定: didn't + 动词原形",
                "疑问: Did + 主语 + 动词原形?"
            ],
            examples: [
                GrammarExample(english: "I went to the park yesterday.", chinese: "我昨天去了公园。", highlight: ["went", "yesterday"]),
                GrammarExample(english: "She watched TV last night.", chinese: "她昨晚看了电视。", highlight: ["watched", "last night"]),
                GrammarExample(english: "Did you eat breakfast?", chinese: "你吃早饭了吗？", highlight: ["Did", "eat"])
            ],
            gradeLevel: 4,
            keywords: ["yesterday", "last", "ago", "ed", "went", "was", "were", "did"]
        ))
        
        points.append(GrammarPoint(
            id: "simple_future",
            category: .tense,
            name: "一般将来时",
            englishName: "Simple Future Tense",
            explanation: "表示将来要发生的动作或存在的状态",
            rules: [
                "主语 + will + 动词原形",
                "主语 + be going to + 动词原形",
                "否定: won't / be not going to + 动词原形",
                "疑问: Will + 主语 + 动词原形?"
            ],
            examples: [
                GrammarExample(english: "I will go shopping tomorrow.", chinese: "我明天要去购物。", highlight: ["will", "go", "tomorrow"]),
                GrammarExample(english: "She is going to visit her grandma.", chinese: "她打算去看望奶奶。", highlight: ["is going to", "visit"]),
                GrammarExample(english: "Will you come to my party?", chinese: "你会来参加我的派对吗？", highlight: ["Will", "come"])
            ],
            gradeLevel: 5,
            keywords: ["will", "going to", "tomorrow", "next", "soon"]
        ))
        
        // MARK: Sentence Structure - 句型
        
        points.append(GrammarPoint(
            id: "there_be",
            category: .sentenceStructure,
            name: "There be 句型",
            englishName: "There be Structure",
            explanation: "表示\"某处有某物\"",
            rules: [
                "There is + 单数名词/不可数名词",
                "There are + 复数名词",
                "就近原则：be动词与最近的名词保持一致"
            ],
            examples: [
                GrammarExample(english: "There is a book on the desk.", chinese: "桌子上有一本书。", highlight: ["There is", "a book"]),
                GrammarExample(english: "There are some apples in the basket.", chinese: "篮子里有一些苹果。", highlight: ["There are", "apples"]),
                GrammarExample(english: "Is there a park near your home?", chinese: "你家附近有公园吗？", highlight: ["Is there"])
            ],
            gradeLevel: 3,
            keywords: ["there is", "there are", "there was", "there were"]
        ))
        
        points.append(GrammarPoint(
            id: "subject_verb_object",
            category: .sentenceStructure,
            name: "主谓宾结构",
            englishName: "Subject-Verb-Object",
            explanation: "英语句子的基本结构：主语 + 谓语动词 + 宾语",
            rules: [
                "主语 (谁/什么) + 谓语 (做什么) + 宾语 (对象)",
                "主语通常是名词或代词",
                "谓语是动词",
                "宾语接在动词后面"
            ],
            examples: [
                GrammarExample(english: "I love my mother.", chinese: "我爱我的妈妈。", highlight: ["I", "love", "mother"]),
                GrammarExample(english: "Tom eats an apple.", chinese: "汤姆吃了一个苹果。", highlight: ["Tom", "eats", "apple"]),
                GrammarExample(english: "We play games.", chinese: "我们玩游戏。", highlight: ["We", "play", "games"])
            ],
            gradeLevel: 2,
            keywords: []
        ))
        
        // MARK: Question Forms - 疑问句
        
        points.append(GrammarPoint(
            id: "what_question",
            category: .questionForm,
            name: "What 疑问句",
            englishName: "What Questions",
            explanation: "用于询问\"什么\"",
            rules: [
                "What + be动词 + 主语?",
                "What + do/does + 主语 + 动词原形?",
                "What + 名词 + be动词/助动词 + 主语?"
            ],
            examples: [
                GrammarExample(english: "What is this?", chinese: "这是什么？", highlight: ["What"]),
                GrammarExample(english: "What do you like?", chinese: "你喜欢什么？", highlight: ["What", "do"]),
                GrammarExample(english: "What color is it?", chinese: "它是什么颜色？", highlight: ["What color"])
            ],
            gradeLevel: 2,
            keywords: ["what", "what is", "what are", "what do", "what does"]
        ))
        
        points.append(GrammarPoint(
            id: "where_question",
            category: .questionForm,
            name: "Where 疑问句",
            englishName: "Where Questions",
            explanation: "用于询问\"哪里\"（地点）",
            rules: [
                "Where + be动词 + 主语?",
                "Where + do/does + 主语 + 动词原形?",
                "回答通常包含地点介词短语"
            ],
            examples: [
                GrammarExample(english: "Where is my book?", chinese: "我的书在哪里？", highlight: ["Where"]),
                GrammarExample(english: "Where do you live?", chinese: "你住在哪里？", highlight: ["Where", "do"]),
                GrammarExample(english: "Where are you going?", chinese: "你要去哪里？", highlight: ["Where", "are"])
            ],
            gradeLevel: 2,
            keywords: ["where", "where is", "where are", "where do", "where does"]
        ))
        
        points.append(GrammarPoint(
            id: "how_question",
            category: .questionForm,
            name: "How 疑问句",
            englishName: "How Questions",
            explanation: "用于询问\"怎样\"（方式、状态）",
            rules: [
                "How + be动词 + 主语? (询问状态)",
                "How + do/does + 主语 + 动词? (询问方式)",
                "How many + 可数名词复数 (询问数量)",
                "How much + 不可数名词 (询问数量/价格)",
                "How old (年龄)、How often (频率)"
            ],
            examples: [
                GrammarExample(english: "How are you?", chinese: "你好吗？", highlight: ["How"]),
                GrammarExample(english: "How many apples do you have?", chinese: "你有多少个苹果？", highlight: ["How many"]),
                GrammarExample(english: "How much is this?", chinese: "这个多少钱？", highlight: ["How much"]),
                GrammarExample(english: "How old are you?", chinese: "你多大了？", highlight: ["How old"])
            ],
            gradeLevel: 3,
            keywords: ["how", "how are", "how is", "how many", "how much", "how old", "how often"]
        ))
        
        // MARK: Plurality - 单复数
        
        points.append(GrammarPoint(
            id: "noun_plural",
            category: .plurality,
            name: "名词复数",
            englishName: "Noun Plurals",
            explanation: "表示两个或两个以上的人或物",
            rules: [
                "一般在词尾加 -s: book→books",
                "以s, x, ch, sh结尾加 -es: box→boxes",
                "以辅音字母+y结尾，变y为i加 -es: baby→babies",
                "以f/fe结尾，变f/fe为v加 -es: knife→knives",
                "不规则变化需记忆: man→men, child→children"
            ],
            examples: [
                GrammarExample(english: "I have two cats.", chinese: "我有两只猫。", highlight: ["cats"]),
                GrammarExample(english: "There are five boxes.", chinese: "有五个盒子。", highlight: ["boxes"]),
                GrammarExample(english: "The children are playing.", chinese: "孩子们在玩耍。", highlight: ["children"])
            ],
            gradeLevel: 3,
            keywords: ["s", "es", "ies", "ves", "men", "women", "children", "feet", "teeth"]
        ))
        
        // MARK: Comparison - 比较级
        
        points.append(GrammarPoint(
            id: "comparative",
            category: .comparison,
            name: "比较级",
            englishName: "Comparative",
            explanation: "用于两者之间的比较",
            rules: [
                "单音节词 + er: tall→taller",
                "以e结尾 + r: large→larger",
                "辅音字母+y结尾，变y为i + er: happy→happier",
                "双写辅音字母 + er: big→bigger",
                "多音节词: more + 形容词: beautiful→more beautiful",
                "不规则: good→better, bad→worse"
            ],
            examples: [
                GrammarExample(english: "Tom is taller than Jerry.", chinese: "汤姆比杰瑞高。", highlight: ["taller", "than"]),
                GrammarExample(english: "This book is more interesting.", chinese: "这本书更有趣。", highlight: ["more interesting"]),
                GrammarExample(english: "I'm better today.", chinese: "我今天好多了。", highlight: ["better"])
            ],
            gradeLevel: 5,
            keywords: ["er", "more", "than", "taller", "bigger", "better", "worse"]
        ))
        
        points.append(GrammarPoint(
            id: "superlative",
            category: .comparison,
            name: "最高级",
            englishName: "Superlative",
            explanation: "用于三者或三者以上的比较",
            rules: [
                "the + 形容词 + est: the tallest",
                "the most + 多音节形容词: the most beautiful",
                "不规则: the best, the worst",
                "最高级前面通常加 the"
            ],
            examples: [
                GrammarExample(english: "She is the tallest in our class.", chinese: "她是我们班最高的。", highlight: ["the tallest"]),
                GrammarExample(english: "This is the most beautiful flower.", chinese: "这是最漂亮的花。", highlight: ["the most beautiful"]),
                GrammarExample(english: "He is the best student.", chinese: "他是最好的学生。", highlight: ["the best"])
            ],
            gradeLevel: 5,
            keywords: ["est", "most", "the tallest", "the biggest", "the best", "the worst"]
        ))
        
        // MARK: Common Phrases - 常用短语
        
        points.append(GrammarPoint(
            id: "would_like",
            category: .commonPhrases,
            name: "would like 句型",
            englishName: "Would like",
            explanation: "表示\"想要\"，比want更礼貌",
            rules: [
                "I/We/You/They would like + 名词/to do",
                "He/She would like + 名词/to do",
                "缩写: I'd like, He'd like",
                "疑问: Would you like...?"
            ],
            examples: [
                GrammarExample(english: "I would like some water.", chinese: "我想要一些水。", highlight: ["would like"]),
                GrammarExample(english: "Would you like to come?", chinese: "你想来吗？", highlight: ["Would", "like to"]),
                GrammarExample(english: "I'd like a cup of tea.", chinese: "我想要一杯茶。", highlight: ["I'd like"])
            ],
            gradeLevel: 4,
            keywords: ["would like", "would you like", "i'd like", "he'd like", "she'd like"]
        ))
        
        points.append(GrammarPoint(
            id: "have_to",
            category: .commonPhrases,
            name: "have to / has to",
            englishName: "Have to / Has to",
            explanation: "表示\"必须、不得不\"（客观需要）",
            rules: [
                "I/You/We/They have to + 动词原形",
                "He/She/It has to + 动词原形",
                "否定: don't/doesn't have to (不必)",
                "过去时: had to"
            ],
            examples: [
                GrammarExample(english: "I have to do my homework.", chinese: "我必须做作业。", highlight: ["have to"]),
                GrammarExample(english: "She has to go now.", chinese: "她现在必须走了。", highlight: ["has to"]),
                GrammarExample(english: "You don't have to wait.", chinese: "你不必等。", highlight: ["don't have to"])
            ],
            gradeLevel: 4,
            keywords: ["have to", "has to", "had to", "don't have to", "doesn't have to"]
        ))
        
        return points
    }
}
