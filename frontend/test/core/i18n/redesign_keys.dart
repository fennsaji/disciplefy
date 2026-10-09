import 'package:flutter/painting.dart';

/// A user-visible string on a redesigned screen and the slot it renders in at
/// a 360px-wide phone.
///
/// [key] is a `context.tr` key, or `l10n:<getter>` for a string that lives in
/// `AppLocalizations` (the dock labels).
class AuditKey {
  final String key;
  final double fontSize;
  final FontWeight weight;

  /// Width of the slot at 360px.
  final double maxWidth;

  /// True for labels that must stay on one line (dock, buttons, chips, links,
  /// eyebrows, row labels). Those must fit [maxWidth] and stay within ~1.3x
  /// the English width. Wrapping lines only need to fit in [lines] lines.
  final bool singleLine;

  /// Lines a wrapping string may use.
  final int lines;

  const AuditKey(
    this.key, {
    required this.fontSize,
    required this.weight,
    required this.maxWidth,
    this.singleLine = true,
    this.lines = 1,
  });

  /// Bottom dock label (five items share 360px).
  const AuditKey.dock(this.key)
      : fontSize = 12,
        weight = FontWeight.w600,
        maxWidth = 64,
        singleLine = true,
        lines = 1;

  /// Full-width button: 360 - 2x16 page gutter - 2x16 card padding.
  const AuditKey.button(this.key, {this.fontSize = 14})
      : weight = FontWeight.w600,
        maxWidth = 296,
        singleLine = true,
        lines = 1;

  /// "See path" / "See all" style text links.
  const AuditKey.link(this.key, {this.maxWidth = 140, this.fontSize = 13})
      : weight = FontWeight.w600,
        singleLine = true,
        lines = 1;

  /// Chips, tags and segmented-switch halves.
  const AuditKey.chip(this.key, {this.maxWidth = 120, this.fontSize = 13})
      : weight = FontWeight.w600,
        singleLine = true,
        lines = 1;

  /// Upper-case eyebrows and short row labels on one line.
  const AuditKey.label(
    this.key, {
    this.maxWidth = 230,
    this.fontSize = 13,
    this.weight = FontWeight.w500,
  })  : singleLine = true,
        lines = 1;

  /// Headings that may wrap.
  const AuditKey.title(
    this.key, {
    this.fontSize = 20,
    this.maxWidth = 296,
    this.lines = 2,
  })  : weight = FontWeight.w700,
        singleLine = false;

  /// Body and subtitle lines that may wrap.
  const AuditKey.body(
    this.key, {
    this.fontSize = 14,
    this.maxWidth = 296,
    this.lines = 2,
  })  : weight = FontWeight.w400,
        singleLine = false;

  /// Banner title on the New-for-you photo card.
  const AuditKey.banner(this.key)
      : fontSize = 15,
        weight = FontWeight.w700,
        maxWidth = 230,
        singleLine = false,
        lines = 2;
}

const _nfyKinds = ['paths', 'memory', 'generate', 'discipler', 'fellowships'];

/// Every string on the redesigned surfaces (Home today layout, first run,
/// account sheet, New for you, intros, lesson complete, Generate, credits,
/// My Plan, Topics, All paths, Memory verses, Settings, Community, dock).
final redesignKeys = <AuditKey>[
  // Dock
  for (final k in [
    'navHome',
    'navGenerate',
    'navTopics',
    'navCommunity',
    'navDiscipler',
  ])
    AuditKey.dock('l10n:$k'),

  // Home today layout
  // Header pill: 200 max minus icon and padding.
  const AuditKey.label('home.memory_verses',
      maxWidth: 150, weight: FontWeight.w600),
  const AuditKey.chip('home_today.today_label', maxWidth: 80, fontSize: 12),
  const AuditKey.label('home_today.lesson_eyebrow',
      fontSize: 12, weight: FontWeight.w700),
  const AuditKey.button('home_today.start_lesson'),
  const AuditKey.chip('home_today.mode_quick', maxWidth: 170, fontSize: 12),
  const AuditKey.chip('home_today.mode_standard', maxWidth: 170, fontSize: 12),
  const AuditKey.title('home_today.path_finished', fontSize: 18),
  const AuditKey.button('home_today.choose_next_path'),
  const AuditKey.link('home_today.see_path'),
  const AuditKey.label('home_today.lesson_of', maxWidth: 200),
  const AuditKey.label('home_today.to_go', maxWidth: 120),
  const AuditKey.title('home_today.choose_first_path', fontSize: 18),
  const AuditKey.body('home_today.choose_first_path_sub'),
  const AuditKey.label('home_today.lessons_days', maxWidth: 200),
  const AuditKey.link('home_today.see_all_paths'),
  const AuditKey.label('home_today.save_progress',
      maxWidth: 260, weight: FontWeight.w600),
  const AuditKey.link('home_today.reflect', maxWidth: 230),
  const AuditKey.body('home_today.loading_path', lines: 1),
  const AuditKey.body('home_today.paths_unavailable', lines: 1),

  // New for you
  const AuditKey.label('nfy.eyebrow',
      maxWidth: 140, fontSize: 12, weight: FontWeight.w700),
  for (final kind in _nfyKinds) ...[
    AuditKey.banner('nfy.$kind.banner_title'),
    AuditKey.body('nfy.$kind.banner_sub', fontSize: 12, maxWidth: 230),
    AuditKey.chip('nfy.$kind.banner_cta', maxWidth: 160, fontSize: 12),
  ],
  const AuditKey.body('nfy.memory.banner_sub_any', fontSize: 12, maxWidth: 230),
  const AuditKey.body('nfy.fellowships.banner_sub_any',
      fontSize: 12, maxWidth: 230),

  // Feature intros
  const AuditKey.label('intro.start_with', fontSize: 12),
  for (final kind in _nfyKinds) ...[
    AuditKey.label('intro.$kind.eyebrow',
        fontSize: 12, weight: FontWeight.w700),
    AuditKey.title('intro.$kind.title', fontSize: 22, lines: 3),
    for (final step in ['step1', 'step2', 'step3']) ...[
      AuditKey.label('intro.$kind.${step}_title',
          maxWidth: 280, fontSize: 14, weight: FontWeight.w600),
      AuditKey.body('intro.$kind.${step}_body', fontSize: 13, maxWidth: 240),
    ],
    AuditKey.button('intro.$kind.primary'),
    AuditKey.button('intro.$kind.secondary'),
  ],
  const AuditKey.body('intro.memory.saved'),
  const AuditKey.body('intro.discipler.question'),
  for (final chip in ['chip1', 'chip2', 'chip3'])
    AuditKey.chip('intro.generate.$chip', maxWidth: 160),
  const AuditKey.chip('intro.fellowships.join', fontSize: 12),
  const AuditKey.label('intro.fellowships.member_one', maxWidth: 160),
  const AuditKey.label('intro.fellowships.members', maxWidth: 160),
  const AuditKey.label('intro.fellowships.members_open', maxWidth: 200),
  const AuditKey.chip('intro.fellowships.official', fontSize: 12),
  const AuditKey.chip('intro.fellowships.studying', fontSize: 12),
  const AuditKey.body('intro.fellowships.join_failed'),

  // Lesson (guide footer + Lesson complete page)
  const AuditKey.label('lesson.eyebrow', fontSize: 12, weight: FontWeight.w700),
  const AuditKey.button('lesson.mark_complete'),
  const AuditKey.title('lesson.complete_title', fontSize: 24),
  const AuditKey.label('lesson.up_next', fontSize: 12, weight: FontWeight.w700),
  const AuditKey.button('lesson.continue_to'),
  const AuditKey.button('lesson.back_home'),
  const AuditKey.title('lesson.path_finished', fontSize: 24),
  const AuditKey.body('lesson.full_guide_link', fontSize: 13),
  const AuditKey.chip('lesson.quick_read', maxWidth: 140),
  const AuditKey.chip('lesson.full_guide', maxWidth: 140),

  // First run
  const AuditKey.label('first_run.welcome_eyebrow',
      fontSize: 12, weight: FontWeight.w700),
  const AuditKey.title('first_run.welcome_title', fontSize: 26),
  const AuditKey.body('first_run.welcome_subtitle', fontSize: 15),
  const AuditKey.label('first_run.english_bible'),
  const AuditKey.button('first_run.continue'),
  const AuditKey.link('first_run.log_in'),
  const AuditKey.label('first_run.have_account'),
  const AuditKey.title('first_run.goal_title', fontSize: 24),
  const AuditKey.link('first_run.skip', fontSize: 14),
  const AuditKey.button('first_run.start_lesson_one'),
  const AuditKey.body('first_run.terms', fontSize: 12),
  const AuditKey.label('first_run.path_meta', maxWidth: 260),
  const AuditKey.body('first_run.pick_one'),
  const AuditKey.body('first_run.pick_one_guest', lines: 3),
  const AuditKey.body('first_run.pick_one_guest_plain', lines: 3),
  const AuditKey.body('first_run.error', lines: 3),
  const AuditKey.body('first_run.error_has_path'),
  const AuditKey.button('first_run.retry'),
  const AuditKey.button('first_run.go_home'),
  const AuditKey.link('first_run.back'),
  const AuditKey.label('first_run.step', maxWidth: 140, fontSize: 12),
  for (final goal in [
    'new_to_faith',
    'fresh_start',
    'walk_with_god',
    'hope_hard_times',
    'read_gospel',
    'understand_gospel',
  ])
    AuditKey.label('goal.$goal', fontSize: 15, weight: FontWeight.w600),

  // Account sheet and save-progress block
  for (final title in [
    'save_progress_title',
    'path_finished_title',
    'groups_title',
    'discipler_title',
    'second_path_title',
    'generate_title',
    'memory_verses_title',
    'generic_title',
  ])
    AuditKey.title('account.$title'),
  const AuditKey.button('account.continue_google'),
  const AuditKey.button('account.continue_apple'),
  const AuditKey.button('account.continue_email'),
  const AuditKey.link('account.not_now'),
  const AuditKey.link('account.continue_guest', maxWidth: 200),
  const AuditKey.body('account.body'),
  const AuditKey.body('account.benefit_moves', fontSize: 13, lines: 1),
  const AuditKey.body('account.benefit_paths', fontSize: 13, lines: 1),
  const AuditKey.body('account.benefit_groups', fontSize: 13, lines: 1),
  const AuditKey.body('account.check_email'),
  const AuditKey.label('account.keep_days_safe', weight: FontWeight.w600),
  const AuditKey.link('account.keep_cta', maxWidth: 200),
  const AuditKey.label('account.next_paths',
      fontSize: 12, weight: FontWeight.w700),
  const AuditKey.link('account.sign_up_to_start', fontSize: 12),
  const AuditKey.label('account.lessons_count', maxWidth: 120),
  const AuditKey.body('account.merge_pending'),
  const AuditKey.body('account.link_failed'),
  const AuditKey.body('account.email_exists'),

  // Generate
  const AuditKey.label('generate_simple.eyebrow',
      fontSize: 12, weight: FontWeight.w700),
  const AuditKey.title('generate_simple.title', fontSize: 28),
  const AuditKey.body('generate_simple.hint', fontSize: 16, maxWidth: 264),
  const AuditKey.chip('generate_simple.type_scripture', fontSize: 12),
  const AuditKey.chip('generate_simple.type_topic', fontSize: 12),
  const AuditKey.chip('generate_simple.type_question', fontSize: 12),
  const AuditKey.label('generate_simple.choose_depth',
      fontSize: 16, weight: FontWeight.w700),
  const AuditKey.link('generate_simple.all_depths'),
  const AuditKey.button('generate_simple.generate', fontSize: 15),
  const AuditKey.label('generate_simple.using_credits',
      maxWidth: 296, fontSize: 12),
  const AuditKey.label('generate_simple.verse_of_day',
      fontSize: 12, weight: FontWeight.w700),

  // Credits
  const AuditKey.label('credits.out_eyebrow',
      fontSize: 12, weight: FontWeight.w700),
  const AuditKey.title('credits.out_title'),
  const AuditKey.body('credits.out_body', lines: 3),
  const AuditKey.body('credits.out_need'),
  const AuditKey.button('credits.get'),
  const AuditKey.button('credits.view_saved'),
  const AuditKey.button('credits.maybe_later'),
  const AuditKey.label('credits.study_costs', weight: FontWeight.w700),
  const AuditKey.label('credits.follow_up', maxWidth: 160),
  const AuditKey.body('credits.exact_cost_note', fontSize: 13),

  // My Plan
  const AuditKey.label('plan.trial_until', maxWidth: 260),
  const AuditKey.label('plan.left_today',
      maxWidth: 140, fontSize: 16, weight: FontWeight.w700),
  const AuditKey.label('plan.resets_at', maxWidth: 140),
  const AuditKey.label('plan.billed_via'),
  const AuditKey.label('plan.renews_on'),
  const AuditKey.button('plan.view_plans'),

  // Topics and All paths
  const AuditKey.label('topics.title', fontSize: 26, weight: FontWeight.w700),
  const AuditKey.button('topics.browse_all'),
  const AuditKey.button('topics.continue'),
  const AuditKey.button('topics.start_a_path'),
  const AuditKey.link('topics.see_all'),
  const AuditKey.label('all_paths.title',
      fontSize: 24, weight: FontWeight.w700),
  const AuditKey.label('all_paths.count', maxWidth: 120),
  const AuditKey.chip('all_paths.all'),
  const AuditKey.chip('all_paths.current', maxWidth: 90, fontSize: 12),
  const AuditKey.label('all_paths.lesson_of', maxWidth: 200),

  // Learning path lesson strings
  const AuditKey.button('learning_paths.start_lesson'),
  const AuditKey.button('learning_paths.continue_lesson'),
  const AuditKey.button('learning_paths.review_lesson'),
  const AuditKey.label('learning_paths.lessons_days', maxWidth: 200),

  // Memory verses
  const AuditKey.button('memory.save_todays_verse'),
  const AuditKey.button('memory.add_verse'),
  const AuditKey.label('memory.header_line', maxWidth: 296),
  const AuditKey.label('memory.header_line_one', maxWidth: 296),
  const AuditKey.body('memory.footnote', fontSize: 13),
  const AuditKey.label('memory.statistics', fontSize: 15),
  const AuditKey.label('memory.champions', fontSize: 15),
  const AuditKey.chip('memory.due', maxWidth: 64, fontSize: 12),

  // Settings
  // Settings rows: 360 - 2x16 gutter - icon - chevron.
  const AuditKey.label('settings.more',
      maxWidth: 260, fontSize: 15, weight: FontWeight.w600),
  const AuditKey.label('settings.more_subtitle', maxWidth: 260),
  const AuditKey.label('settings.save_progress',
      maxWidth: 260, fontSize: 15, weight: FontWeight.w600),
  const AuditKey.label('settings.save_progress_subtitle', maxWidth: 260),
  const AuditKey.body('settings.guest_note', lines: 3),

  // Community
  const AuditKey.label('community.guided_by_discipler',
      maxWidth: 200, fontSize: 12),
  const AuditKey.body('community.joined'),
];
