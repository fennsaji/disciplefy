# Learning Paths Inventory

**Source**: Backend Supabase migrations
**Total**: 36 active learning paths across 8 categories
**Total Study Guide Topic Assignments**: 335

**Migration Files**:
1. `20260119001000_learning_paths.sql` — Paths 1-10 (original)
2. `20260223000001_new_learning_paths.sql` — Paths 11, 13-29
3. `20260313000001_new_learning_paths_v2.sql` — Path 30
4. `20260316000002_fix_learning_paths_uuid_collision.sql` — Paths 31-34 (collision fixes)
5. `20260412000001_merge_overlapping_learning_paths.sql` — Merge P3→deactivated, P21→P4, P23→P5, P29→P10
6. `20260413000001_epistle_learning_paths.sql` — Paths 35-41 (Epistles), P30+P33 recategorised
7. `20260413000002_fix_learning_paths_review_issues.sql` — Display order, milestone, description, and topic fixes

> Path 12 was skipped due to UUID collision (topics exist but not seeded via learning_path_topics).
> Paths 3, 21, 23, 29 were deactivated in migration 5 (merged into surviving paths).

---

## Summary by Category

| Category | Count | Paths |
|----------|-------|-------|
| Foundations | 5 | New Believer Essentials, Rooted in Christ, Understanding the Bible, Baptism & Lord's Supper, Who Is the Holy Spirit? |
| Epistles | 9 | Romans, Philippians, James, Ephesians, Peter's Letters, Galatians, John's Letters, Corinthians, Hebrews |
| Growth | 5 | Growing in Discipleship, Deepening Your Walk, Theology of Suffering, Money & Generosity, Spiritual Warfare |
| Service & Mission | 4 | Heart for the World, The Local Church, Evangelism in Everyday Life, Work & Vocation |
| Apologetics | 3 | Defending Your Faith, Historical Reliability, Christianity & Culture |
| Life & Relationships | 3 | Faith & Family, Mental Health & Emotions, Friendship & Community |
| Theology | 5 | Eternal Perspective, Faith & Reason, Attributes of God, Law/Grace/Covenants, Sin/Repentance/Grace |
| Book Studies | 2 | Sermon on the Mount, Crucifixion & Resurrection |

---

## PATH 1: New Believer Essentials

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000001` |
| Slug | `new-believer-essentials` |
| Category | Foundations |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 14 |
| Featured | Yes |

**Description**: Begin your faith journey with these foundational topics. Learn about Jesus, the Gospel, and how to grow in your relationship with God.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Who is Jesus Christ? | |
| 1 | What is the Gospel? | |
| 2 | Assurance of Salvation | * |
| 3 | Why Read the Bible? | |
| 4 | Importance of Prayer | |
| 5 | The Role of the Holy Spirit | * |
| 6 | Baptism and Communion | * |

---

## PATH 2: Growing in Discipleship

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000002` |
| Slug | `growing-in-discipleship` |
| Category | Growth |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 21 |
| Featured | Yes |

**Description**: Deepen your faith and learn what it means to be a true disciple of Jesus. Explore spiritual disciplines, Christian living, and personal growth.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | What is Discipleship? | |
| 1 | Walking with God Daily | |
| 2 | Daily Devotions | * |
| 3 | The Cost of Following Jesus | |
| 4 | Overcoming Temptation | |
| 5 | Fasting and Prayer | |
| 6 | Bearing Fruit | * |
| 7 | Meditation on God's Word | |
| 8 | Living a Holy Life | * |
| 9 | How to Study the Bible | |
| 10 | Discerning God's Will | * |

---

## ~~PATH 3: Serving & Mission~~ (DEACTIVATED)

> Soft-deleted in migration 5. All 9 topics already exist in P17 + P18 + P19.

---

## PATH 4: Defending Your Faith

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000004` |
| Slug | `defending-your-faith` |
| Category | Apologetics |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 28 |
| Featured | Yes |

**Description**: Build confidence in sharing and defending your beliefs. Learn to identify false teaching, recognize cultic patterns, and respond to tough questions with wisdom, grace, and biblical understanding.

> Updated in migration 5: merged with P21 (Responding to Cults). Now 9 topics (was 6).

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Why We Believe in One God | |
| 1 | The Uniqueness of Jesus | |
| 2 | Is the Bible Reliable? | * |
| 3 | What Makes a Teaching False? | |
| 4 | Recognizing Cultic Patterns | |
| 5 | Responding to Common Questions | |
| 6 | Grace vs. Works-Based Religion | * |
| 7 | Standing Firm | * |
| 8 | Faith and Science | * |

---

## PATH 5: Faith & Family

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000005` |
| Slug | `faith-and-family` |
| Category | Life & Relationships |
| Difficulty | beginner |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 35 |
| Featured | Yes |

**Description**: Strengthen your relationships and build a Christ-centered home. From singleness and purity to marriage, parenting, and friendships — learn God's design for every season of life.

> Updated in migration 5: merged with P23 (Singleness/Dating/Marriage). Now 10 topics (was 6).

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Singleness and Contentment | |
| 1 | God's Design for Marriage | |
| 2 | Purity Before Marriage | * |
| 3 | Choosing a Spouse Wisely | |
| 4 | Marriage and Faith | |
| 5 | When Marriage Is Hard | * |
| 6 | Raising Children | * |
| 7 | Honoring Parents | |
| 8 | Healthy Friendships | |
| 9 | Resolving Conflicts | * |

---

## PATH 6: Deepening Your Walk

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000006` |
| Slug | `deepening-your-walk` |
| Category | Growth |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 28 |
| Featured | No |

**Description**: Go deeper in your relationship with God through spiritual disciplines, fellowship, and generous living. Transform your daily habits into acts of worship.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Worship as Lifestyle | |
| 1 | Journaling | |
| 2 | Fellowship | * |
| 3 | Forgiveness | |
| 4 | Generosity | |
| 5 | Unity | * |

---

## PATH 7: Heart for the World

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000007` |
| Slug | `heart-for-the-world` |
| Category | Service & Mission |
| Difficulty | intermediate |
| Disciple Level | leader |
| Mode | standard |
| Est. Days | 21 |
| Featured | No |

**Description**: Develop a global perspective on missions and learn to impact your community and the nations for Christ. Become a multiplying disciple.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Serving Poor | |
| 1 | Praying for Nations | * |
| 2 | Mentoring | |
| 3 | Great Commission | * |

---

## PATH 8: Rooted in Christ

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000008` |
| Slug | `rooted-in-christ` |
| Category | Foundations |
| Difficulty | beginner |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 21 |
| Featured | Yes |

**Description**: Establish your foundation by understanding your identity in Christ, living by grace, and building unshakeable faith.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Your Identity in Christ | |
| 1 | Understanding God's Grace | * |
| 2 | Dealing with Doubt and Fear | |
| 3 | Living by Faith, Not Feelings | |
| 4 | Spiritual Warfare | * |

---

## PATH 9: Eternal Perspective

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000009` |
| Slug | `eternal-perspective` |
| Category | Theology |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | standard |
| Est. Days | 14 |
| Featured | No |

**Description**: Gain hope and purpose by understanding God's eternal plan - the return of Christ, heaven, and our glorious future.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | The Return of Christ | |
| 1 | Heaven and Eternal Life | * |
| 2 | Standing Firm in Persecution | |
| 3 | Living by Faith, Not Feelings | * |

---

## PATH 10: Faith & Reason

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000010` |
| Slug | `faith-and-reason` |
| Category | Theology |
| Difficulty | advanced |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 35 |
| Featured | Yes |

**Description**: Explore Christianity's toughest questions with biblical wisdom and historical evidence. From the existence of God and the historicity of Jesus to the problem of evil and the purpose of life — build confident, well-reasoned faith.

> Updated in migration 5: merged with P29 (The Big Questions). Now 14 topics (was 12).

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Does God Exist? | |
| 1 | Why Evil and Suffering? | * |
| 2 | Did Jesus Actually Exist? | |
| 3 | Jesus Only Way? | |
| 4 | Is Bible Reliable? | |
| 5 | The Resurrection as Historical Fact | * |
| 6 | Those Who Never Hear? | |
| 7 | Faith and Science | * |
| 8 | What is Trinity? | |
| 9 | Unanswered Prayers? | |
| 10 | Predestination vs Free Will | * |
| 11 | Heaven and Eternal Life | |
| 12 | Many Denominations? | |
| 13 | Purpose in Life? | * |

---

## PATH 11: Understanding the Bible

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000011` |
| Slug | `understanding-the-bible` |
| Category | Foundations |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 21 |
| Featured | Yes |

**Description**: Learn how the Bible was written, preserved, and organized — and develop the skills to read it with confidence. Trace the grand story of Scripture from Genesis to Revelation and discover how every part points to Jesus Christ.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Why Read the Bible? | |
| 1 | How We Got the Bible | |
| 2 | Is the Bible Reliable? | * |
| 3 | Understanding Biblical Genres | |
| 4 | The Old Testament Story | |
| 5 | The New Testament Story | |
| 6 | How to Study the Bible | * |
| 7 | Meditation on God's Word | |

---

## PATH 12: Baptism & the Lord's Supper

> **Note**: ID collision — handled in later migration. Topics may not have been seeded.

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000012` |
| Slug | `baptism-and-lords-supper` |
| Category | Foundations |
| Difficulty | beginner |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 14 |
| Featured | No |

**Description**: Understand the two ordinances Jesus commanded His church to practice. Explore the meaning of baptism and communion, why they matter, and how they connect you to Christ and His body.

*Topics not seeded in migrations due to UUID collision.*

---

## PATH 13: Who Is the Holy Spirit?

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000013` |
| Slug | `who-is-the-holy-spirit` |
| Category | Foundations |
| Difficulty | beginner |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 14 |
| Featured | No |

**Description**: Move beyond vague ideas about the Spirit and discover who He truly is — the third person of the Trinity who convicts, regenerates, fills, and transforms believers. Learn what it means to walk in the Spirit daily.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | The Role of the Holy Spirit | |
| 1 | Holy Spirit in the OT | |
| 2 | Holy Spirit and Salvation | * |
| 3 | Spiritual Gifts | |
| 4 | Fruit of the Spirit | |
| 5 | Being Filled with the Spirit | * |
| 6 | Living a Holy Life | |

---

## PATH 14: The Theology of Suffering

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000014` |
| Slug | `theology-of-suffering` |
| Category | Growth |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 21 |
| Featured | No |

**Description**: Wrestle honestly with one of life's hardest questions: why does a good God allow suffering? Journey through Job, the Psalms, the cross, and Romans 8 to find not easy answers but deep, sustaining hope rooted in the character of God.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Suffering in the Psalms | |
| 1 | Job | * |
| 2 | The Cross and Suffering | |
| 3 | Dealing with Doubt and Fear | |
| 4 | Standing Firm | |
| 5 | Hope in Suffering | * |

---

## PATH 15: Money, Generosity & the Gospel

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000015` |
| Slug | `money-generosity-gospel` |
| Category | Growth |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 18 |
| Featured | No |

**Description**: Jesus spoke about money more than almost any other topic — because how we handle wealth reveals the state of our heart. Develop a biblical theology of money, contentment, stewardship, and radical generosity rooted in the gospel.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | What Does the Bible Say About Money? | |
| 1 | Contentment vs. Greed | |
| 2 | Biblical Stewardship | * |
| 3 | Tithing and Giving | |
| 4 | Generosity | |
| 5 | Work, Earning, and Provision | |
| 6 | Eternal Investments | * |

---

## PATH 16: Spiritual Warfare

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000016` |
| Slug | `spiritual-warfare` |
| Category | Growth |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 18 |
| Featured | No |

**Description**: The Christian life is not a playground but a battleground. Learn who your enemy is, how he operates, and how to stand firm using the full armor of God. Live from the victory Christ has already won at the cross.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Spiritual Warfare | |
| 1 | Who Is Satan? | |
| 2 | Overcoming Temptation | |
| 3 | Armor of God | * |
| 4 | Fasting and Prayer | |
| 5 | Standing Firm | |
| 6 | Victory in Christ | * |

---

## PATH 17: The Local Church

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000017` |
| Slug | `the-local-church` |
| Category | Service & Mission |
| Difficulty | beginner |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 21 |
| Featured | No |

**Description**: Discover why the local church is not optional for the Christian life but central to God's redemptive plan. Understand its purpose, leadership, ordinances, and how belonging and contributing to a local church is a mark of mature discipleship.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | What is the Church? | |
| 1 | Why Fellowship Matters | |
| 2 | Church Leadership | |
| 3 | Spiritual Gifts | * |
| 4 | Serving in the Church | |
| 5 | Unity | |
| 6 | Baptism and Communion | |
| 7 | Church Discipline | * |

---

## PATH 18: Evangelism in Everyday Life

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000018` |
| Slug | `evangelism-everyday-life` |
| Category | Service & Mission |
| Difficulty | beginner |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 14 |
| Featured | Yes |

**Description**: Sharing the gospel is not just for pastors and missionaries — it is the calling of every believer. Overcome fear, learn to share your story and the gospel clearly, and discover how ordinary conversations can become eternal conversations.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | What is the Gospel? | |
| 1 | The Great Commission | |
| 2 | Overcoming Fear | |
| 3 | Being the Light | |
| 4 | Sharing Your Testimony | * |
| 5 | Evangelism Made Simple | |
| 6 | Answering Common Objections | |
| 7 | Role of Holy Spirit in Evangelism | * |

---

## PATH 19: Work & Vocation as Worship

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000019` |
| Slug | `work-and-vocation-as-worship` |
| Category | Service & Mission |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 18 |
| Featured | No |

**Description**: Your Monday matters as much as your Sunday. Explore the biblical theology of work — from creation to the new creation — and learn how your daily vocation is a God-given calling to serve others, glorify God, and advance His kingdom.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Work Before and After the Fall | |
| 1 | Your Calling: More Than a Job | |
| 2 | Excellence and Integrity | * |
| 3 | Workplace as Mission | |
| 4 | Being a Witness at Work | |
| 5 | Biblical Stewardship | |
| 6 | Rest, Sabbath, and Rhythm | * |

---

## PATH 20: Historical Reliability of the Bible

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000020` |
| Slug | `historical-reliability-bible` |
| Category | Apologetics |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 21 |
| Featured | No |

**Description**: Build a well-reasoned confidence in Scripture's trustworthiness. Examine manuscript evidence, archaeology, fulfilled prophecy, and the historical evidence for the resurrection.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Is the Bible Reliable? | |
| 1 | Manuscript Evidence | |
| 2 | Archaeology | * |
| 3 | OT Prophecies Fulfilled in Christ | |
| 4 | Resurrection as History | * |
| 5 | How the Canon Was Formed | |

---

## ~~PATH 21: Responding to Cults & False Teaching~~ (DEACTIVATED)

> Merged into P4 (Defending Your Faith) in migration 5. 3 unique topics added to P4.

---

## PATH 22: Christianity & Culture

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000022` |
| Slug | `christianity-and-culture` |
| Category | Apologetics |
| Difficulty | advanced |
| Disciple Level | leader |
| Mode | deep |
| Est. Days | 21 |
| Featured | No |

**Description**: Christians are called to be in the world but not of it. Develop a thoughtful, gospel-centered framework for engaging contemporary culture — including media, sexuality, justice, and pluralism — with both conviction and compassion.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | How Christians Engage Culture | |
| 1 | Media and Discernment | |
| 2 | Faith and Science | * |
| 3 | Sexuality and Biblical Ethics | |
| 4 | Justice, Mercy, and the Gospel | |
| 5 | Responding to Common Questions | |
| 6 | Speaking Truth in Love | * |

---

## ~~PATH 23: Singleness, Dating & Marriage~~ (DEACTIVATED)

> Merged into P5 (Faith & Family) in migration 5. 4 unique topics added to P5.

---

## PATH 24: Mental Health, Emotions & the Gospel

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000024` |
| Slug | `mental-health-emotions-gospel` |
| Category | Life & Relationships |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 21 |
| Featured | No |

**Description**: The gospel speaks to the whole person — body, mind, and soul. Learn what Scripture says about emotions, anxiety, depression, grief, and the journey toward wholeness.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Emotions in the Bible | |
| 1 | Anxiety and Peace of God | |
| 2 | Dealing with Doubt and Fear | * |
| 3 | Depression and the Soul | |
| 4 | Grief, Lament, and Healing | |
| 5 | Forgiveness | |
| 6 | The Hope That Does Not Disappoint | * |

---

## PATH 25: Friendship & Christian Community

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000025` |
| Slug | `friendship-and-christian-community` |
| Category | Life & Relationships |
| Difficulty | beginner |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 14 |
| Featured | No |

**Description**: God did not design the Christian life to be lived alone. Explore the biblical call to deep friendship, mutual accountability, and life-giving community.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Why Fellowship Matters | |
| 1 | Spiritual Friendship in Scripture | |
| 2 | Healthy Friendships | |
| 3 | Accountability | * |
| 4 | Fellowship | |
| 5 | Unity | |
| 6 | Resolving Conflicts | * |

---

## PATH 26: The Attributes of God

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000026` |
| Slug | `attributes-of-god` |
| Category | Theology |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 28 |
| Featured | Yes |

**Description**: Knowing God rightly is the foundation of all Christian living, worship, and service. Study His holiness, love, justice, sovereignty, omniscience, eternity, and unchangeableness.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Why We Believe in One God | |
| 1 | God Is Holy | |
| 2 | God Is Love and Just | * |
| 3 | God Is Sovereign | |
| 4 | God Is Eternal | |
| 5 | What is Trinity? | |
| 6 | Who is Jesus Christ? | |
| 7 | Role of the Holy Spirit | * |

---

## PATH 27: Law, Grace & the Covenants

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000027` |
| Slug | `law-grace-and-covenants` |
| Category | Theology |
| Difficulty | advanced |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 28 |
| Featured | No |

**Description**: Understand the grand structure of God's redemptive plan through the covenants — from Abraham to the New Covenant in Christ. See how the law and grace work together rather than against each other, and how every covenant points to Jesus.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Purpose of the Law | |
| 1 | The Covenants of God | |
| 2 | What is the Gospel? | * |
| 3 | Christ Fulfills the Law | |
| 4 | The New Covenant in Christ | |
| 5 | Understanding God's Grace | |
| 6 | Your Identity in Christ | * |

---

## PATH 28: Sin, Repentance & the Grace of God

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000028` |
| Slug | `sin-repentance-and-grace` |
| Category | Theology |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 21 |
| Featured | No |

**Description**: A clear understanding of sin and repentance is not meant to crush us but to drive us into the arms of a gracious God. Study the nature of sin, what true repentance looks like, and how God's transforming grace exceeds every failure.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | The Nature and Wages of Sin | |
| 1 | What is the Gospel? | |
| 2 | True Repentance | * |
| 3 | Forgiveness | |
| 4 | Assurance of Salvation | |
| 5 | Understanding God's Grace | |
| 6 | Overcoming Temptation | |
| 7 | Living a Holy Life | * |

---

## ~~PATH 29: The Big Questions~~ (DEACTIVATED)

> Merged into P10 (Faith & Reason) in migration 5. 2 unique topics added to P10.

---

## PATH 30: Hebrews: Jesus Our High Priest

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000030` |
| Slug | `hebrews-jesus-our-high-priest` |
| Category | Epistles |
| Difficulty | intermediate |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 42 |
| Featured | Yes |
| Display Order | 9 |

> Recategorised from Book Studies → Epistles in migration 6. Display order swapped with P41 (Corinthians) in migration 7.

**Description**: Walk through the book of Hebrews chapter by chapter. Discover the supremacy of Christ over angels, Moses, and the Levitical priesthood — and learn what it means to live by faith under a better covenant.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Hebrews 1: The Supremacy of Christ | |
| 1 | Hebrews 2: A Great Salvation | |
| 2 | Hebrews 3: Jesus Greater Than Moses | |
| 3 | Hebrews 4: Entering God's Rest | |
| 4 | Hebrews 5: Our Great High Priest | |
| 5 | Hebrews 6: Press On to Maturity | |
| 6 | Hebrews 7: The Priesthood of Melchizedek | * |
| 7 | Hebrews 8: A Better Covenant | |
| 8 | Hebrews 9: The Heavenly Sanctuary | |
| 9 | Hebrews 10: Once and for All | |
| 10 | Hebrews 11: The Hall of Faith | |
| 11 | Hebrews 12: Running the Race | |
| 12 | Hebrews 13: Final Instructions | * |

---

## PATH 31: Jesus's Parables

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000031` |
| Slug | `jesus-parables` |
| Category | Theology |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 42 |
| Featured | No |
| Display Order | 9 |

> Created in migration 4 (collision fix). Display order updated to 9 in migration 7.

**Description**: Jesus taught in parables — earthly stories with heavenly meanings. These 28 stories reveal the nature of God's kingdom, the scandal of grace, the weight of judgment, and the radical demands of discipleship. From the Prodigal Son to the Sower, each parable holds up a mirror to the human heart.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | The Sower and the Soils | |
| 1 | The Wheat and the Weeds | |
| 2 | The Mustard Seed | |
| 3 | The Yeast | |
| 4 | The Hidden Treasure | |
| 5 | The Pearl of Great Value | |
| 6 | The Net | * |
| 7 | The Lost Sheep | |
| 8 | The Unmerciful Servant | |
| 9 | The Workers in the Vineyard | |
| 10 | The Two Sons | |
| 11 | The Tenants | |
| 12 | The Wedding Banquet | |
| 13 | The Ten Virgins | * |
| 14 | The Talents | |
| 15 | The Sheep and the Goats | |
| 16 | The Growing Seed | |
| 17 | The Good Samaritan | |
| 18 | The Persistent Friend | |
| 19 | The Rich Fool | |
| 20 | The Barren Fig Tree | * |
| 21 | The Great Banquet | |
| 22 | The Lost Coin | |
| 23 | The Prodigal Son | |
| 24 | The Dishonest Manager | |
| 25 | The Rich Man and Lazarus | |
| 26 | The Persistent Widow | |
| 27 | The Pharisee and the Tax Collector | * |

---

## PATH 32: Sermon on the Mount

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000032` |
| Slug | `sermon-on-the-mount` |
| Category | Book Studies |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | deep |
| Est. Days | 60 |
| Featured | Yes |

**Description**: Study Jesus' most famous sermon verse by verse. The Sermon on the Mount (Matthew 5-7) lays out the ethics, values, and heart posture of the Kingdom of God.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | The Beatitudes | |
| 1 | Salt and Light | |
| 2 | Christ Fulfills the Law | |
| 3 | Anger and Reconciliation | |
| 4 | Purity of Heart | |
| 5 | Divorce | |
| 6 | Oaths and Integrity | |
| 7 | Nonresistance: The Ethic of the Kingdom | |
| 8 | Love Your Enemies | * |
| 9 | Giving in Secret | |
| 10 | The Lord's Prayer | |
| 11 | Fasting | |
| 12 | Treasures in Heaven | |
| 13 | Do Not Worry | |
| 14 | Do Not Judge | * |
| 15 | Ask, Seek, Knock | |
| 16 | The Narrow Gate | |
| 17 | A Tree and Its Fruit | |
| 18 | True and False Disciples | |
| 19 | The Wise and Foolish Builders | * |

---

## PATH 33: Romans: The Gospel Unfolded

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000033` |
| Slug | `romans-gospel-unfolded` |
| Category | Epistles |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 48 |
| Featured | Yes |
| Display Order | 2 |

> Recategorised from Book Studies → Epistles in migration 6. Changed to beginner/seeker.

**Description**: Walk through Paul's magnum opus chapter by chapter. Romans is the most systematic presentation of the gospel in Scripture — from universal guilt to justification, sanctification, and the hope of glory.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Romans 1: Power of the Gospel & Universal Guilt | |
| 1 | Romans 2: God's Impartial Judgment | |
| 2 | Romans 3: Righteousness Through Faith | |
| 3 | Romans 4: Abraham, Father of Faith | * |
| 4 | Romans 5: Peace with God Through Christ | |
| 5 | Romans 6: Dead to Sin, Alive in Christ | |
| 6 | Romans 7: The Struggle with Sin and the Law | |
| 7 | Romans 8: Life in the Spirit | * |
| 8 | Romans 9: God's Sovereign Election | |
| 9 | Romans 10: Salvation for All Who Call | |
| 10 | Romans 11: The Mystery of Israel's Future | |
| 11 | Romans 12: Living Sacrifices | * |
| 12 | Romans 13: Governing Authorities & Debt of Love | |
| 13 | Romans 14: Receiving One Another | |
| 14 | Romans 15: United in Christ's Mission | |
| 15 | Romans 16: Greetings & Community of Faith | * |

---

## PATH 34: The Crucifixion and Resurrection of Jesus

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000034` |
| Slug | `crucifixion-and-resurrection` |
| Category | Book Studies |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 48 |
| Featured | Yes |

**Description**: Walk through the final week of Jesus' earthly life — from the Last Supper to the empty tomb and the Great Commission. This is the heart of the Christian faith: the death and resurrection of Jesus Christ.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | The Last Supper | |
| 1 | The Garden of Gethsemane | |
| 2 | Betrayal and Arrest | |
| 3 | Peter's Denial | |
| 4 | Jesus Before the Sanhedrin | |
| 5 | Jesus Before Pilate | |
| 6 | The Crucifixion | |
| 7 | The Death of Jesus | * |
| 8 | The Burial of Jesus | |
| 9 | The Empty Tomb | |
| 10 | Jesus Appears to Mary Magdalene | |
| 11 | The Road to Emmaus | |
| 12 | Jesus Appears to the Disciples | |
| 13 | Thomas: Doubt and Belief | |
| 14 | The Great Commission | |
| 15 | The Ascension | * |

---

## PATH 35: Ephesians: Riches in Christ

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000035` |
| Slug | `ephesians-riches-in-christ` |
| Category | Epistles |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 18 |
| Featured | No |
| Display Order | 5 |

> Added in migration 6.

**Description**: Paul's letter to the Ephesians starts with who God is and what he has done, then shows how that changes the way we live every day. In six chapters, discover the spiritual blessings that are yours in Christ, the grace that saved you, the mystery of the church, the call to walk worthy, the picture of marriage as gospel, and the armor of God for spiritual warfare.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Ephesians 1: Blessed in Christ | |
| 1 | Ephesians 2: From Death to Life | |
| 2 | Ephesians 3: The Mystery Revealed | * |
| 3 | Ephesians 4: Walking Worthy | |
| 4 | Ephesians 5: Children of Light | |
| 5 | Ephesians 6: The Armor of God | * |

---

## PATH 36: James: Faith That Works

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000036` |
| Slug | `james-faith-that-works` |
| Category | Epistles |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 15 |
| Featured | No |
| Display Order | 4 |

> Added in migration 6.

**Description**: James writes the most practical letter in the New Testament — a call to faith that proves itself in action. In five chapters, confront the testing of faith, the deadly power of the tongue, the danger of favoritism, the call to humility, and the power of patient, persistent prayer. Faith without works is dead.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | James 1: Trials and True Faith | |
| 1 | James 2: Faith and Works | |
| 2 | James 3: Taming the Tongue | * |
| 3 | James 4: Humility Before God | |
| 4 | James 5: Patient Endurance | * |

---

## PATH 37: John's Letters: Light, Love, and Truth

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000037` |
| Slug | `johns-letters-light-love-truth` |
| Category | Epistles |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 21 |
| Featured | No |
| Display Order | 8 |

> Added in migration 6. Covers 1 John (5 chapters), 2 John, and 3 John.

**Description**: The apostle John writes three letters that together paint the fullest picture of what it means to stay close to Jesus and live in him. In 1 John, discover the tests of genuine faith — walking in light, keeping his commandments, and loving one another. 2 John warns against deceivers who deny Christ come in the flesh. 3 John commends faithful hospitality and warns against self-exalting leadership. God is light and God is love — and those who abide in him will know it.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | 1 John 1: Walking in the Light | |
| 1 | 1 John 2: Knowing the True from the False | |
| 2 | 1 John 3: The Love of God | |
| 3 | 1 John 4: Testing the Spirits | * |
| 4 | 1 John 5: Assurance of Eternal Life | |
| 5 | 2 John: Truth and Love | |
| 6 | 3 John: Faithful Hospitality | * |

---

## PATH 38: Philippians: Joy in Christ

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000038` |
| Slug | `philippians-joy-in-christ` |
| Category | Epistles |
| Difficulty | beginner |
| Disciple Level | seeker |
| Mode | standard |
| Est. Days | 12 |
| Featured | No |
| Display Order | 3 |

> Added in migration 6.

**Description**: Written from a Roman prison, Philippians overflows with joy. In four chapters, Paul reveals the secret of contentment, the mind of Christ who emptied himself, the surpassing worth of knowing Jesus, and the peace that guards every heart. Learn to rejoice in every circumstance through the one who strengthens you.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Philippians 1: Joy in the Gospel | |
| 1 | Philippians 2: The Mind of Christ | * |
| 2 | Philippians 3: Pressing Toward the Goal | |
| 3 | Philippians 4: Rejoice Always | * |

---

## PATH 39: Galatians: Gospel Freedom

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000039` |
| Slug | `galatians-gospel-freedom` |
| Category | Epistles |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 18 |
| Featured | No |
| Display Order | 7 |

> Added in migration 6.

**Description**: Paul's most passionate letter defends the good news against those who say you need to follow religious rules on top of trusting in Jesus. In six chapters, discover why there is no other gospel, how we are made right with God by faith alone, the relationship between the promise and the law, what it means to be adopted as sons, and how to walk by the Spirit in true freedom.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | Galatians 1: No Other Gospel | |
| 1 | Galatians 2: Justified by Faith | |
| 2 | Galatians 3: The Promise and the Law | * |
| 3 | Galatians 4: Sons and Heirs | |
| 4 | Galatians 5: Freedom in Christ | |
| 5 | Galatians 6: Bearing One Another's Burdens | * |

---

## PATH 40: Peter's Letters: Hope and Endurance

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000040` |
| Slug | `peters-letters-hope-and-endurance` |
| Category | Epistles |
| Difficulty | intermediate |
| Disciple Level | follower |
| Mode | standard |
| Est. Days | 24 |
| Featured | No |
| Display Order | 6 |

> Added in migration 6. Covers 1 Peter (5 chapters) and 2 Peter (3 chapters).

**Description**: Peter writes two letters to scattered believers facing hostility and the threat of false teaching. In 1 Peter, discover the living hope of the resurrection, the identity of God's holy people, the example of Christ in suffering, and the humility that resists the devil. In 2 Peter, grow in godliness through precious promises, recognize false teachers, and look forward to the day of the Lord and the new heavens and new earth.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | 1 Peter 1: A Living Hope | |
| 1 | 1 Peter 2: A Holy People | |
| 2 | 1 Peter 3: Suffering for Righteousness | |
| 3 | 1 Peter 4: Stewards of Grace | * |
| 4 | 1 Peter 5: Stand Firm in Grace | |
| 5 | 2 Peter 1: Growing in Godliness | |
| 6 | 2 Peter 2: False Teachers Exposed | |
| 7 | 2 Peter 3: The Day of the Lord | * |

---

## PATH 41: Corinthians: Christ and His Church

| Field | Value |
|-------|-------|
| ID | `aaa00000-0000-0000-0000-000000000041` |
| Slug | `corinthians-christ-and-his-church` |
| Category | Epistles |
| Difficulty | advanced |
| Disciple Level | disciple |
| Mode | deep |
| Est. Days | 58 |
| Featured | No |
| Display Order | 9 |

> Added in migration 6. Covers 1 Corinthians (16 chapters) and 2 Corinthians (13 chapters).

**Description**: Paul writes two letters to a gifted but deeply divided church, tackling everything from fighting and lawsuits to marriage, spiritual gifts, the resurrection, suffering, giving, and true leadership. In twenty-nine chapters, discover how the gospel reshapes every area of life and community. At the center stands the way of love, the reality of the risen Christ, and the power made perfect in weakness.

| # | Study Guide Topic | Milestone |
|---|---|---|
| 0 | 1 Corinthians 1: Divisions in the Church | |
| 1 | 1 Corinthians 2: God's Wisdom vs. the World's | |
| 2 | 1 Corinthians 3: Servants of Christ | |
| 3 | 1 Corinthians 4: Fools for Christ | |
| 4 | 1 Corinthians 5: Church Discipline | |
| 5 | 1 Corinthians 6: Flee Sexual Immorality | |
| 6 | 1 Corinthians 7: Marriage and Singleness | |
| 7 | 1 Corinthians 8: Food, Idols, and Conscience | * |
| 8 | 1 Corinthians 9: Rights and Self-Discipline | |
| 9 | 1 Corinthians 10: Warnings from Israel | |
| 10 | 1 Corinthians 11: Order in Worship | |
| 11 | 1 Corinthians 12: Spiritual Gifts | |
| 12 | 1 Corinthians 13: The Way of Love | |
| 13 | 1 Corinthians 14: Orderly Worship | |
| 14 | 1 Corinthians 15: The Resurrection | |
| 15 | 1 Corinthians 16: Final Instructions | * |
| 16 | 2 Corinthians 1: Comfort in Affliction | |
| 17 | 2 Corinthians 2: Forgiveness and Triumph | |
| 18 | 2 Corinthians 3: The Glory of the New Covenant | |
| 19 | 2 Corinthians 4: Treasure in Jars of Clay | |
| 20 | 2 Corinthians 5: The Ministry of Reconciliation | |
| 21 | 2 Corinthians 6: Servants of God | |
| 22 | 2 Corinthians 7: Godly Sorrow and Repentance | * |
| 23 | 2 Corinthians 8: The Grace of Giving | |
| 24 | 2 Corinthians 9: Cheerful Giving | |
| 25 | 2 Corinthians 10: Spiritual Warfare | |
| 26 | 2 Corinthians 11: Paul's Sufferings | |
| 27 | 2 Corinthians 12: Power in Weakness | |
| 28 | 2 Corinthians 13: Final Warnings | * |

---

## Quick Reference Table

| # | Name | Category | Difficulty | Days | Topics | Featured | Mode |
|---|------|----------|------------|------|--------|----------|------|
| 1 | New Believer Essentials | Foundations | beginner | 14 | 7 | Yes | standard |
| 2 | Growing in Discipleship | Growth | intermediate | 21 | 11 | Yes | standard |
| ~~3~~ | ~~Serving & Mission~~ | ~~deactivated~~ | | | | | |
| 4 | Defending Your Faith | Apologetics | intermediate | 28 | 9 | Yes | deep |
| 5 | Faith & Family | Life & Relationships | beginner | 35 | 10 | Yes | standard |
| 6 | Deepening Your Walk | Growth | intermediate | 28 | 6 | No | deep |
| 7 | Heart for the World | Service & Mission | intermediate | 21 | 4 | No | standard |
| 8 | Rooted in Christ | Foundations | beginner | 21 | 5 | Yes | standard |
| 9 | Eternal Perspective | Theology | intermediate | 14 | 4 | No | standard |
| 10 | Faith & Reason | Theology | advanced | 35 | 14 | Yes | deep |
| 11 | Understanding the Bible | Foundations | beginner | 21 | 8 | Yes | standard |
| 12 | Baptism & Lord's Supper | Foundations | beginner | 14 | 0* | No | standard |
| 13 | Who Is the Holy Spirit? | Foundations | beginner | 14 | 7 | No | standard |
| 14 | Theology of Suffering | Growth | intermediate | 21 | 6 | No | deep |
| 15 | Money, Generosity & Gospel | Growth | intermediate | 18 | 7 | No | standard |
| 16 | Spiritual Warfare | Growth | intermediate | 18 | 7 | No | deep |
| 17 | The Local Church | Service & Mission | beginner | 21 | 8 | No | standard |
| 18 | Evangelism in Everyday Life | Service & Mission | beginner | 14 | 8 | Yes | standard |
| 19 | Work & Vocation as Worship | Service & Mission | intermediate | 18 | 7 | No | standard |
| 20 | Historical Reliability | Apologetics | intermediate | 21 | 6 | No | deep |
| ~~21~~ | ~~Responding to Cults~~ | ~~deactivated~~ | | | | | |
| 22 | Christianity & Culture | Apologetics | advanced | 21 | 6 | No | deep |
| ~~23~~ | ~~Singleness/Dating/Marriage~~ | ~~deactivated~~ | | | | | |
| 24 | Mental Health & Emotions | Life & Relationships | intermediate | 21 | 7 | No | standard |
| 25 | Friendship & Community | Life & Relationships | beginner | 14 | 7 | No | standard |
| 26 | The Attributes of God | Theology | intermediate | 28 | 8 | Yes | deep |
| 27 | Law, Grace & Covenants | Theology | advanced | 28 | 7 | No | deep |
| 28 | Sin, Repentance & Grace | Theology | beginner | 21 | 8 | No | standard |
| ~~29~~ | ~~The Big Questions~~ | ~~deactivated~~ | | | | | |
| 30 | Hebrews: Jesus Our High Priest | Epistles | intermediate | 42 | 13 | Yes | deep |
| 31 | Jesus's Parables | Theology | intermediate | 42 | 28 | No | standard |
| 32 | Sermon on the Mount | Book Studies | intermediate | 60 | 20 | Yes | deep |
| 33 | Romans: The Gospel Unfolded | Epistles | beginner | 48 | 16 | Yes | standard |
| 34 | Crucifixion & Resurrection | Book Studies | beginner | 48 | 16 | Yes | standard |
| 35 | Ephesians: Riches in Christ | Epistles | beginner | 18 | 6 | No | standard |
| 36 | James: Faith That Works | Epistles | beginner | 15 | 5 | No | standard |
| 37 | John's Letters: Light, Love, and Truth | Epistles | intermediate | 21 | 7 | No | standard |
| 38 | Philippians: Joy in Christ | Epistles | beginner | 12 | 4 | No | standard |
| 39 | Galatians: Gospel Freedom | Epistles | intermediate | 18 | 6 | No | standard |
| 40 | Peter's Letters: Hope and Endurance | Epistles | intermediate | 24 | 8 | No | standard |
| 41 | Corinthians: Christ and His Church | Epistles | advanced | 58 | 29 | No | deep |

> *Path 12 topics not seeded due to UUID collision
> ~~Strikethrough~~ paths are deactivated (soft-deleted)

## Statistics

- **Total active paths**: 36
- **Total topic assignments**: 335
- **Featured**: 13
- **Difficulty**: beginner (15), intermediate (17), advanced (4)
- **Disciple levels**: seeker (8), follower (16), disciple (10), leader (2)
- **Modes**: standard (24), deep (12)
- **Categories**: Foundations (5), Epistles (9), Growth (5), Service & Mission (4), Apologetics (3), Life & Relationships (3), Theology (5), Book Studies (2)
