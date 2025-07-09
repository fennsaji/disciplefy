// Mock JSON data for offline LLM fallback testing
// Based on structured study methodology and sprint requirements

export interface MockStudyGuide {
  id: string
  summary: string
  interpretation: string // Optional field for additional context
  context: string
  related_verses: string[]
  reflection_questions: string[]
  prayer_points: string[]
  language: string
  created_at: string
}

export const MOCK_STUDY_GUIDES: { [key: string]: MockStudyGuide } = {
  // Scripture-based study guides
  'john_3_16': {
    id: 'mock-guide-1',
    summary: 'God\'s love demonstrated through the gift of His Son for eternal life. This verse encapsulates the heart of the Gospel message.',
    interpretation: 'This verse highlights the depth of God\'s love for humanity, emphasizing that salvation is available to all who believe in Jesus Christ. The term "eternal life" refers to a quality of life that begins now and continues forever in relationship with God, rather than merely a future existence after death.',
    context: 'Jesus spoke these words to Nicodemus, a Pharisee and member of the Jewish ruling council, during a nighttime conversation. This famous verse comes in the context of Jesus explaining spiritual rebirth and God\'s plan of salvation. The word "world" (kosmos) refers to humanity in rebellion against God, yet loved by Him.',
    related_verses: [
      'Romans 5:8 - But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.',
      '1 John 4:9 - This is how God showed his love among us: He sent his one and only Son into the world that we might live through him.',
      'Ephesians 2:8-9 - For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast.',
      'John 14:6 - Jesus answered, "I am the way and the truth and the life. No one comes to the Father except through me."',
      'Romans 10:9 - If you declare with your mouth, "Jesus is Lord," and believe in your heart that God raised him from the dead, you will be saved.'
    ],
    reflection_questions: [
      'How does knowing that God loves the world change your perspective on difficult people in your life?',
      'What does it mean to you personally that God gave His "one and only Son"?',
      'How can you live today in light of the eternal life you have been given?',
      'In what ways can you share this good news with others who need hope?',
      'How does this verse challenge any feelings of unworthiness or shame you might have?'
    ],
    prayer_points: [
      'Thank God for His incredible love that He demonstrated by sending Jesus',
      'Ask for a deeper understanding of what eternal life means in your daily walk',
      'Pray for opportunities to share God\'s love with those who don\'t know Him',
      'Request God\'s help to live worthy of the sacrifice Christ made for you'
    ],
    language: 'en',
    created_at: new Date().toISOString()
  },

  'romans_8_28': {
    id: 'mock-guide-2',
    summary: 'God\'s sovereignty and goodness work together in all circumstances for the benefit of those who love Him and are called according to His purpose.',
    interpretation: 'This verse reassures believers that God is actively involved in every aspect of their lives, orchestrating events for their ultimate good. The phrase "all things" includes both positive and negative experiences, emphasizing that nothing is wasted in God\'s plan. The promise is specifically for those who love God and are called according to His purpose, indicating a relationship of trust and obedience.',
    context: 'Paul writes this in his letter to the Roman church, addressing believers who were facing persecution and suffering. This verse comes in a chapter about living by the Spirit and the assurance of salvation. The phrase "all things" is comprehensive - including trials, suffering, and difficult circumstances.',
    related_verses: [
      'Jeremiah 29:11 - For I know the plans I have for you," declares the Lord, "plans to prosper you and not to harm you, to give you hope and a future.',
      'Genesis 50:20 - You intended to harm me, but God intended it for good to accomplish what is now being done, the saving of many lives.',
      'James 1:2-4 - Consider it pure joy, my brothers and sisters, whenever you face trials of many kinds, because you know that the testing of your faith produces perseverance.',
      '2 Corinthians 4:17 - For our light and momentary troubles are achieving for us an eternal glory that far outweighs them all.',
      'Proverbs 3:5-6 - Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.'
    ],
    reflection_questions: [
      'How have you seen God work good from difficult situations in your past?',
      'What current challenges are you facing that you need to trust God with?',
      'How does being "called according to His purpose" change your perspective on your circumstances?',
      'In what ways can you actively love God more deeply during trials?',
      'How can you encourage others who are struggling with this truth?'
    ],
    prayer_points: [
      'Thank God for His sovereign control over every detail of your life',
      'Ask for faith to trust Him when circumstances don\'t make sense',
      'Pray for wisdom to see His hand at work in your current situations',
      'Request strength to love Him even in difficult times'
    ],
    language: 'en',
    created_at: new Date().toISOString()
  },

  // Topic-based study guides
  'faith': {
    id: 'mock-guide-3',
    summary: 'Faith is trusting in God\'s character and promises even when we cannot see the outcome. It is the foundation of our relationship with God and the means by which we please Him.',
    interpretation: 'Faith in the biblical sense is more than intellectual assent; it is a deep-seated trust in God that leads to action. It involves believing in God\'s existence, His goodness, and His promises as revealed in Scripture. Faith is not static but grows through experiences, trials, and the work of the Holy Spirit in our lives.',
    context: 'Biblical faith is not blind belief, but confident trust based on God\'s revealed character and proven faithfulness throughout history. Faith involves both belief and action, trust and obedience. It is a gift from God that enables us to see beyond our circumstances to His eternal purposes.',
    related_verses: [
      'Hebrews 11:1 - Now faith is confidence in what we hope for and assurance about what we do not see.',
      'Hebrews 11:6 - And without faith it is impossible to please God, because anyone who comes to him must believe that he exists and that he rewards those who earnestly seek him.',
      'Romans 10:17 - Consequently, faith comes from hearing the message, and the message is heard through the word about Christ.',
      'Mark 9:24 - Immediately the boy\'s father exclaimed, "I do believe; help me overcome my unbelief!"',
      'Matthew 17:20 - Truly I tell you, if you have faith as small as a mustard seed, you can say to this mountain, "Move from here to there," and it will move. Nothing will be impossible for you.',
      'Ephesians 2:8-9 - For it is by grace you have been saved, through faith—and this is not from yourselves, it is the gift of God—not by works, so that no one can boast.',
      'James 2:17 - In the same way, faith by itself, if it is not accompanied by action, is dead.'
    ],
    reflection_questions: [
      'How would you describe your faith journey - where did it begin and how has it grown?',
      'What areas of your life require more faith and trust in God right now?',
      'How do you distinguish between biblical faith and mere wishful thinking?',
      'What role does God\'s Word play in building and strengthening your faith?',
      'How does your faith influence your daily decisions and relationships?',
      'In what ways can you demonstrate your faith through your actions this week?'
    ],
    prayer_points: [
      'Ask God to increase your faith and help you trust Him more completely',
      'Thank Him for being faithful even when your faith wavers',
      'Pray for wisdom to know how to act on your faith in practical ways',
      'Request courage to step out in faith even when the path is unclear'
    ],
    language: 'en',
    created_at: new Date().toISOString()
  },

  'love': {
    id: 'mock-guide-4',
    summary: 'Love is the greatest commandment and the defining characteristic of followers of Christ. God\'s love for us motivates and empowers our love for Him and others.',
    interpretation: 'Biblical love (agape) is selfless, sacrificial, and unconditional. It is not merely an emotion but a choice to seek the highest good of others. This love reflects God\'s nature and is demonstrated supremely in Christ\'s sacrifice on the cross. Love is foundational to the Christian life and should permeate all relationships.',
    context: 'Biblical love (agape) is sacrificial, unconditional, and action-oriented. It is not primarily an emotion but a choice to seek the highest good of others. This love originates from God\'s nature and is demonstrated supremely in Christ\'s sacrifice on the cross.',
    related_verses: [
      '1 John 4:8 - Whoever does not love does not know God, because God is love.',
      '1 Corinthians 13:4-8 - Love is patient, love is kind. It does not envy, it does not boast, it is not proud. It does not dishonor others, it is not self-seeking, it is not easily angered, it keeps no record of wrongs.',
      'John 13:34-35 - A new command I give you: Love one another. As I have loved you, so you must love one another. By this everyone will know that you are my disciples, if you love one another.',
      'Matthew 22:37-39 - Jesus replied: "Love the Lord your God with all your heart and with all your soul and with all your mind. This is the first and greatest commandment. And the second is like it: Love your neighbor as yourself."',
      'Romans 5:8 - But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.',
      '1 John 4:19 - We love because he first loved us.',
      'Galatians 5:22-23 - But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control.'
    ],
    reflection_questions: [
      'How has experiencing God\'s love changed the way you love others?',
      'Which aspects of love from 1 Corinthians 13 do you struggle with most?',
      'Who in your life is difficult to love, and how can you show Christ\'s love to them?',
      'How do you practically love God with all your heart, soul, and mind?',
      'What does it mean to love your neighbor as yourself in your daily life?',
      'How can your love for others be a witness to those who don\'t know Christ?'
    ],
    prayer_points: [
      'Thank God for His perfect and unconditional love for you',
      'Ask for the Holy Spirit to fill you with His love for difficult people',
      'Pray for opportunities to demonstrate Christ\'s love in practical ways',
      'Request forgiveness for times when you have failed to love as Christ loved'
    ],
    language: 'en',
    created_at: new Date().toISOString()
  },

  'forgiveness': {
    id: 'mock-guide-5',
    summary: 'Forgiveness is both a gift we receive from God and a choice we make toward others. It frees us from bitterness and reflects the heart of God toward humanity.',
    interpretation: 'Biblical forgiveness is not merely forgetting or excusing wrongs, but a conscious decision to release someone from the debt of their offense. It mirrors God\'s forgiveness toward us through Christ and is essential for spiritual health and relational harmony. Forgiveness does not mean we condone or enable harmful behavior, but we choose to respond with grace rather than revenge.',
    context: 'Forgiveness is central to the Gospel message and the Christian life. It involves releasing others from the debt of their wrongdoing against us, just as God has released us from our debt of sin. Forgiveness doesn\'t excuse wrong behavior but chooses to respond with grace rather than revenge.',
    related_verses: [
      'Ephesians 4:32 - Be kind and compassionate to one another, forgiving each other, just as in Christ God forgave you.',
      'Matthew 6:14-15 - For if you forgive other people when they sin against you, your heavenly Father will also forgive you. But if you do not forgive others their sins, your Father will not forgive your sins.',
      'Colossians 3:13 - Bear with each other and forgive one another if any of you has a grievance against someone. Forgive as the Lord forgave you.',
      'Luke 23:34 - Jesus said, "Father, forgive them, for they do not know what they are doing."',
      'Matthew 18:21-22 - Then Peter came to Jesus and asked, "Lord, how many times shall I forgive my brother or sister who sins against me? Up to seven times?" Jesus answered, "Not seven times, but seventy-seven times."',
      '1 John 1:9 - If we confess our sins, he is faithful and just and will forgive us our sins and purify us from all unrighteousness.',
      '2 Corinthians 2:10-11 - Anyone you forgive, I also forgive. And what I have forgiven—if there was anything to forgive—I have forgiven in the sight of Christ for your sake, in order that Satan might not outwit us.'
    ],
    reflection_questions: [
      'How has receiving God\'s forgiveness impacted your life and worldview?',
      'Is there anyone you need to forgive? What is holding you back?',
      'How do you distinguish between forgiveness and enabling unhealthy behavior?',
      'What does it mean to forgive someone who hasn\'t asked for forgiveness?',
      'How can you show forgiveness to yourself for past mistakes and failures?',
      'In what ways can your practice of forgiveness point others to Christ?'
    ],
    prayer_points: [
      'Thank God for the complete forgiveness you have received through Christ',
      'Ask for strength to forgive those who have hurt you deeply',
      'Pray for healing from the wounds that make forgiveness difficult',
      'Request wisdom to know how to rebuild trust where appropriate after forgiveness'
    ],
    language: 'en',
    created_at: new Date().toISOString()
  }
}

// Function to get mock data based on input
export function getMockStudyGuide(inputType: string, inputValue: string): MockStudyGuide | null {
  const normalizedInput = inputValue.toLowerCase().replace(/\s+/g, '_')
  
  // Map common inputs to mock data keys
  const inputMap: { [key: string]: string } = {
    'john_3:16': 'john_3_16',
    'john_3_16': 'john_3_16',
    'romans_8:28': 'romans_8_28',
    'romans_8_28': 'romans_8_28',
    'faith': 'faith',
    'love': 'love',
    'forgiveness': 'forgiveness',
  }
  
  const key = inputMap[normalizedInput]
  return key ? MOCK_STUDY_GUIDES[key] : null
}

// Default fallback study guide for any unmatched input
export const DEFAULT_MOCK_GUIDE: MockStudyGuide = {
  id: 'mock-guide-default',
  summary: 'This is a sample study guide generated in offline mode. Your actual study guide will be more detailed and specific to your input.',
  interpretation: 'This is a placeholder interpretation. In live mode, this would provide insights into the meaning and application of the selected scripture or topic.',
  context: 'This placeholder content demonstrates the structure of a Bible study guide following structured methodology. In live mode, this content would be generated based on your specific Bible verse or topic.',
  related_verses: [
    'Psalm 119:105 - Your word is a lamp for my feet, a light on my path.',
    '2 Timothy 3:16 - All Scripture is God-breathed and is useful for teaching, rebuking, correcting and training in righteousness.',
    'Joshua 1:8 - Keep this Book of the Law always on your lips; meditate on it day and night.'
  ],
  reflection_questions: [
    'How can you apply God\'s Word more faithfully in your daily life?',
    'What is one truth from Scripture that has impacted you recently?',
    'How can you grow in your understanding of biblical truth?',
    'What steps can you take to meditate on God\'s Word more consistently?'
  ],
  prayer_points: [
    'Thank God for the gift of His Word and its guidance in your life',
    'Ask for wisdom and understanding as you study Scripture',
    'Pray for a heart that is open and responsive to God\'s truth',
    'Request strength to apply biblical principles in practical ways'
  ],
  language: 'en',
  created_at: new Date().toISOString()
}