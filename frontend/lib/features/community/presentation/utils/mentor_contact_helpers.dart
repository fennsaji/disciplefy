import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';

/// Strips `+ - ( ) space` from a raw WhatsApp number, leaving digits only.
///
/// Matches the backend contract: `mentor_contact_value` is digits only (no
/// leading `+`) for `whatsapp` contacts.
String normalizeWhatsAppDigits(String raw) =>
    raw.replaceAll(RegExp(r'[+\-() ]'), '');

/// True when [rawValue] is a plausible WhatsApp number: 8-15 digits after
/// stripping `+ - ( ) space`.
bool isValidWhatsAppValue(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return false;
  final digits = normalizeWhatsAppDigits(trimmed);
  return RegExp(r'^\d{8,15}$').hasMatch(digits);
}

/// True when [rawValue] is a plausible email address: a simple
/// `local@domain.tld` shape.
bool isValidEmailValue(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed);
}

/// Builds the `wa.me` deep link for [digits] (WhatsApp number, digits only,
/// no leading `+`) with a prefilled [text].
Uri buildWhatsAppUri({required String digits, required String text}) {
  return Uri.parse('https://wa.me/$digits')
      .replace(queryParameters: {'text': text});
}

/// Builds a `mailto:` link to [address] with a prefilled [subject] and
/// [body].
Uri buildEmailUri({
  required String address,
  required String subject,
  required String body,
}) {
  return Uri(
    scheme: 'mailto',
    path: address,
    queryParameters: {'subject': subject, 'body': body},
  );
}

/// Substitutes the `{fellowship}` placeholder in [template] with
/// [fellowshipName]. Kept as a plain string op so the substitution never
/// leaks into the translated template itself.
String substituteFellowshipName(String template, String fellowshipName) =>
    template.replaceAll('{fellowship}', fellowshipName);

/// Opens WhatsApp or the mail app to message a mentor at [contactValue],
/// prefilled with the standard "question from my fellowship" message.
///
/// Shows [AppLocalizations.messageMentorFailed] via a snackbar when the
/// target app can't be opened.
Future<void> launchMentorContact(
  BuildContext context, {
  required String contactType,
  required String contactValue,
  required String fellowshipName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final body = substituteFellowshipName(l10n.mentorMessageBody, fellowshipName);

  final uri = contactType == 'whatsapp'
      ? buildWhatsAppUri(
          digits: normalizeWhatsAppDigits(contactValue), text: body)
      : buildEmailUri(
          address: contactValue,
          subject: l10n.mentorMessageSubject,
          body: body,
        );

  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }

  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.messageMentorFailed)));
  }
}
