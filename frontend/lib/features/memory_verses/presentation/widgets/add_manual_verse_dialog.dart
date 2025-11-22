import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../../core/constants/bible_data.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/extensions/translation_extension.dart';
import '../../../daily_verse/domain/entities/daily_verse_entity.dart';

/// Dialog for adding a Bible verse to memory deck using structured selection.
///
/// Features:
/// - Cascading dropdowns for Book, Chapter, Verse selection
/// - Support for verse ranges (e.g., John 3:16-17)
/// - Auto-fetches verse text from API
/// - Allows user to edit fetched text
/// - Language selection
class AddManualVerseDialog extends StatefulWidget {
  final Function({
    required String verseReference,
    required String verseText,
    required String language,
  }) onSubmit;

  /// Optional default language to pre-select
  final VerseLanguage defaultLanguage;

  const AddManualVerseDialog({
    super.key,
    required this.onSubmit,
    this.defaultLanguage = VerseLanguage.english,
  });

  /// Shows the add manual verse dialog.
  static void show(
    BuildContext context, {
    required Function({
      required String verseReference,
      required String verseText,
      required String language,
    }) onSubmit,
    VerseLanguage defaultLanguage = VerseLanguage.english,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddManualVerseDialog(
        onSubmit: onSubmit,
        defaultLanguage: defaultLanguage,
      ),
    );
  }

  @override
  State<AddManualVerseDialog> createState() => _AddManualVerseDialogState();
}

class _AddManualVerseDialogState extends State<AddManualVerseDialog> {
  final _textController = TextEditingController();

  // Selection state
  String? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerseStart; // null means "All" (whole chapter)
  int? _selectedVerseEnd;
  late VerseLanguage _selectedLanguage;
  bool _selectWholeChapter = false;

  // UI state
  final bool _isLoading = false;
  bool _isFetchingVerse = false;
  String? _errorMessage;
  String? _fetchedReference;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.defaultLanguage;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Get available chapters for selected book
  List<int> get _availableChapters {
    if (_selectedBook == null) return [];
    final book = BibleData.findBook(_selectedBook!);
    if (book == null) return [];
    return List.generate(book.chapterCount, (i) => i + 1);
  }

  /// Get available verses for selected chapter
  List<int> get _availableVerses {
    if (_selectedBook == null || _selectedChapter == null) return [];
    final book = BibleData.findBook(_selectedBook!);
    if (book == null) return [];
    final verseCount = book.getVerseCount(_selectedChapter!);
    return List.generate(verseCount, (i) => i + 1);
  }

  /// Get available end verses (for range selection)
  List<int> get _availableEndVerses {
    if (_selectedVerseStart == null) return [];
    return _availableVerses.where((v) => v > _selectedVerseStart!).toList();
  }

  /// Fetch verse text from backend
  Future<void> _fetchVerseText() async {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerseStart == null) {
      return;
    }

    setState(() {
      _isFetchingVerse = true;
      _errorMessage = null;
    });

    try {
      const baseUrl = AppConfig.supabaseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/functions/v1/fetch-verse'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
        body: jsonEncode({
          'book': _selectedBook,
          'chapter': _selectedChapter,
          'verse_start': _selectedVerseStart,
          if (_selectedVerseEnd != null) 'verse_end': _selectedVerseEnd,
          'language': _selectedLanguage.code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _textController.text = data['data']['text'];
          _fetchedReference = data['data']['localizedReference'];
        });
      } else {
        final error = jsonDecode(response.body);
        setState(() {
          _errorMessage = error['error']?['message'] ?? 'Failed to fetch verse';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isFetchingVerse = false;
      });
    }
  }

  void _handleSubmit() {
    if (_selectedBook == null ||
        _selectedChapter == null ||
        _selectedVerseStart == null) {
      setState(() =>
          _errorMessage = context.tr(TranslationKeys.addVerseSelectRequired));
      return;
    }

    final trimmedText = _textController.text.trim();
    if (trimmedText.isEmpty) {
      setState(() =>
          _errorMessage = context.tr(TranslationKeys.addVerseTextRequired));
      return;
    }

    // Build reference string
    String reference;
    if (_selectWholeChapter) {
      // Whole chapter: "Psalms 23" or "Psalms 23:1-6"
      final book = BibleData.findBook(_selectedBook!);
      final lastVerse =
          book?.getVerseCount(_selectedChapter!) ?? _selectedVerseEnd;
      reference = '$_selectedBook $_selectedChapter:1-$lastVerse';
    } else if (_selectedVerseEnd != null &&
        _selectedVerseEnd! > _selectedVerseStart!) {
      reference =
          '$_selectedBook $_selectedChapter:$_selectedVerseStart-$_selectedVerseEnd';
    } else {
      reference = '$_selectedBook $_selectedChapter:$_selectedVerseStart';
    }

    widget.onSubmit(
      verseReference: _fetchedReference ?? reference,
      verseText: trimmedText,
      language: _selectedLanguage.code,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    return AlertDialog(
      title: Text(context.tr(TranslationKeys.addVerseTitle)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      content: SizedBox(
        width: screenWidth > 400 ? 400 : screenWidth * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Book Dropdown
              DropdownButtonFormField<String>(
                value: _selectedBook,
                decoration: InputDecoration(
                  labelText: context.tr(TranslationKeys.addVerseBook),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                isExpanded: true,
                menuMaxHeight: 300,
                items: BibleData.bookNames.map((name) {
                  return DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBook = value;
                    _selectedChapter = null;
                    _selectedVerseStart = null;
                    _selectedVerseEnd = null;
                    _textController.clear();
                    _fetchedReference = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Chapter and Verse Row
              Row(
                children: [
                  // Chapter Dropdown
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedChapter,
                      decoration: InputDecoration(
                        labelText: context.tr(TranslationKeys.addVerseChapter),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      menuMaxHeight: 300,
                      items: _availableChapters.map((ch) {
                        return DropdownMenuItem(
                          value: ch,
                          child: Text('$ch'),
                        );
                      }).toList(),
                      onChanged: _selectedBook == null
                          ? null
                          : (value) {
                              setState(() {
                                _selectedChapter = value;
                                _selectedVerseStart = null;
                                _selectedVerseEnd = null;
                                _textController.clear();
                                _fetchedReference = null;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Verse Start Dropdown (with "All" option)
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      value: _selectWholeChapter ? -1 : _selectedVerseStart,
                      decoration: InputDecoration(
                        labelText: context.tr(TranslationKeys.addVerseVerse),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      menuMaxHeight: 300,
                      items: [
                        // "All" option for whole chapter
                        DropdownMenuItem<int?>(
                          value: -1,
                          child: Text(context.tr(TranslationKeys.addVerseAll)),
                        ),
                        ..._availableVerses.map((v) {
                          return DropdownMenuItem<int?>(
                            value: v,
                            child: Text('$v'),
                          );
                        }),
                      ],
                      onChanged: _selectedChapter == null
                          ? null
                          : (value) {
                              setState(() {
                                if (value == -1) {
                                  _selectWholeChapter = true;
                                  _selectedVerseStart = 1;
                                  // Set end to last verse of chapter
                                  final book =
                                      BibleData.findBook(_selectedBook!);
                                  if (book != null) {
                                    _selectedVerseEnd =
                                        book.getVerseCount(_selectedChapter!);
                                  }
                                } else {
                                  _selectWholeChapter = false;
                                  _selectedVerseStart = value;
                                  _selectedVerseEnd = null;
                                }
                                _textController.clear();
                                _fetchedReference = null;
                              });
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // End Verse (for range) and Language Row
              Row(
                children: [
                  // End Verse Dropdown (optional) - hidden when "All" is selected
                  if (!_selectWholeChapter) ...[
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _selectedVerseEnd,
                        decoration: InputDecoration(
                          labelText: context.tr(TranslationKeys.addVerseTo),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        menuMaxHeight: 300,
                        items: [
                          const DropdownMenuItem<int?>(
                            child: Text('-'),
                          ),
                          ..._availableEndVerses.map((v) {
                            return DropdownMenuItem<int?>(
                              value: v,
                              child: Text('$v'),
                            );
                          }),
                        ],
                        onChanged: _selectedVerseStart == null
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedVerseEnd = value;
                                  _textController.clear();
                                  _fetchedReference = null;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // Language Dropdown
                  Expanded(
                    flex: _selectWholeChapter ? 1 : 1,
                    child: DropdownButtonFormField<VerseLanguage>(
                      value: _selectedLanguage,
                      decoration: InputDecoration(
                        labelText: context.tr(TranslationKeys.addVerseLanguage),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      items: VerseLanguage.values.map((language) {
                        return DropdownMenuItem(
                          value: language,
                          child: Text(
                            language.code.toUpperCase(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLanguage = value;
                            _textController.clear();
                            _fetchedReference = null;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Fetch Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_selectedBook != null &&
                          _selectedChapter != null &&
                          _selectedVerseStart != null &&
                          !_isFetchingVerse)
                      ? _fetchVerseText
                      : null,
                  icon: _isFetchingVerse
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download, size: 18),
                  label: Text(_isFetchingVerse
                      ? context.tr(TranslationKeys.addVerseFetching)
                      : context.tr(TranslationKeys.addVerseFetch)),
                ),
              ),
              const SizedBox(height: 12),

              // Reference Display
              if (_fetchedReference != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _fetchedReference!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              // Verse Text Field
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  labelText: context.tr(TranslationKeys.addVerseText),
                  hintText: context.tr(TranslationKeys.addVerseTextHint),
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage,
                ),
                maxLines: 5,
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() => _errorMessage = null);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr(TranslationKeys.addVerseCancel)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr(TranslationKeys.addVerseAdd)),
        ),
      ],
    );
  }
}
