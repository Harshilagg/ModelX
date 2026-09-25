/// The shared widget layer.
///
/// Onboarding and the main app are built from these, which is the point:
/// before this, the signup screens and the board screens had separate
/// buttons, inputs and status indicators that had drifted apart.
///
/// The board-era widgets in `../board_widgets.dart` are still in use by
/// screens that have not been retyped yet, and are retired as those
/// screens migrate rather than all at once.
library;

export 'app_chip.dart';
export 'app_empty_state.dart';
export 'app_field.dart';
export 'app_metrics.dart';
export 'app_pill_button.dart';
export 'app_status_badge.dart';
export 'app_step_shell.dart';
export 'greyscale_reveal.dart';
export 'up_next_card.dart';
export 'google_mark.dart';
export 'app_nav_bar.dart';
export 'aperture_button.dart';
export 'nav_glyphs.dart';
export 'copilot_surface.dart';
export 'answer_text.dart';
