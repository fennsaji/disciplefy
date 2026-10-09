import 'package:disciplefy_bible_study/core/error/failures.dart';

/// Server code for "a guest needs an account first" (HTTP 403).
const String accountRequiredCode = 'ACCOUNT_REQUIRED';

/// True when [failure] means the user is a guest and needs an account.
///
/// Covers both the typed [AccountRequiredFailure] and datasources that still
/// wrap the server's 403 in a generic failure carrying the code. Callers
/// answer with the account-needed sheet, never an error message.
bool isAccountRequired(Failure failure) =>
    failure is AccountRequiredFailure || failure.code == accountRequiredCode;
