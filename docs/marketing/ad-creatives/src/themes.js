const S='../screenshots/', A='../../../../app-store-screenshots/ios-iphone-6.5/', M='../../../../marketing/public/screenshots/';
const THEMES={
 'study-guides':{tag:'Bible study guides',h1:'Open any verse.',h2:'Understand it deeply.',sub:'Summary, context and reflection questions for any passage or topic.',
  steps:['Type a verse','Get a guide','Grow'],back:A+'02-generate.png',front:A+'03-study-guide.png',
  card:['Guide ready','Forgiveness: context and prayer']},
 'daily-verse':{tag:'Daily verse',h1:'Read it today.',h2:'Keep it for life.',sub:'A fresh verse each morning, then simple reviews that help it stick.',
  steps:['Read','Memorise','Remember'],back:S+'home-en.png',front:A+'09-memory-verses.png',
  card:['Review due','Philippians 4:13 — 7 verses saved']},
 'fellowship':{tag:'Fellowship',h1:'Study the Bible',h2:'with your church.',sub:'Join your group, follow the same lessons and share what you learn.',
  steps:['Join a group','Study together','Grow together'],back:A+'07-community.png',front:A+'08-fellowship.png',
  card:['Lesson 4 of 8','Your group is studying together']},
 'learning-paths':{tag:'Learning paths',h1:'Grow step by step.',h2:'One path at a time.',sub:'Guided journeys like Romans, Attributes of God and New Believer Essentials, one topic at a time.',
  steps:['Choose a path','Study each topic','Finish strong'],back:A+'04-topics.png',front:A+'05-learning-path.png',
  card:['Topic 4 of 8 · +50 XP','New Believer Essentials']},
 'languages':{tag:'3 languages',h1:'God’s Word in',h2:'English, हिन्दी, മലയാളം.',sub:'Study guides, daily verses and memory practice in the language you pray in.',
  steps:['Choose a language','Read','Study'],back:S+'home-hi.png',front:S+'home-ml.png',
  card:['Language set','English · हिन्दी · മലയാളം']}
};
const t=THEMES[new URLSearchParams(location.search).get('t')||'study-guides'];
document.addEventListener('DOMContentLoaded',()=>{
 const $=s=>document.querySelector(s);
 $('.tag').textContent=t.tag;$('.l1').textContent=t.h1;$('.l2').textContent=t.h2;$('.sub').textContent=t.sub;
 $('.flow').innerHTML=t.steps.map((s,i)=>`<span class="pill p${i}">${s}</span>`).join('<span class="arr">→</span>');
 $('.back img').src=t.back;$('.front img').src=t.front;
 $('.card b').textContent=t.card[0];$('.card span').textContent=t.card[1];
});
