import 'package:arabic_reshaper/arabic_reshaper.dart';

/// Pre-shapes Urdu (Arabic-script) text into visual-order presentation forms.
///
/// The `pdf` package cannot perform OpenType shaping, so raw Urdu would
/// render as disconnected letters. Reshaped text is already in visual order,
/// therefore it must be rendered with a LTR direction and right alignment
/// (see [urdu] in pdf_assets.dart) — never with an additional RTL flip.
String ar(String text) {
  if (text.isEmpty) return text;
  try {
    return ArabicReshaper.instance.reshape(text);
  } catch (_) {
    return text;
  }
}

/// Urdu label for the payment method stored by the backend.
String urduPaymentMethod(String method) {
  switch (method) {
    case 'bank':
      return ar('بینک');
    case 'online':
      return ar('آن لائن');
    default:
      return ar('نقد');
  }
}
