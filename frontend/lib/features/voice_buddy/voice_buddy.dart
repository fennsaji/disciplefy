// Domain - Entities
export 'domain/entities/voice_conversation_entity.dart';
export 'domain/entities/voice_preferences_entity.dart';

// Domain - Repository Interface
export 'domain/repositories/voice_buddy_repository.dart';

// Data - Models
export 'data/models/voice_conversation_model.dart';
export 'data/models/voice_preferences_model.dart';

// Data - Services
export 'data/services/speech_service.dart';
export 'data/services/tts_service.dart';

// Data - Data Sources
export 'data/datasources/voice_buddy_remote_data_source.dart';

// Data - Repository Implementation
export 'data/repositories/voice_buddy_repository_impl.dart';

// Presentation - BLoC
export 'presentation/bloc/voice_preferences_bloc.dart';
export 'presentation/bloc/voice_preferences_event.dart';
export 'presentation/bloc/voice_preferences_state.dart';

// Presentation - Widgets
export 'presentation/widgets/voice_button.dart';
export 'presentation/widgets/conversation_bubble.dart';
export 'presentation/widgets/language_selector.dart';

// Presentation - Pages
export 'presentation/pages/voice_preferences_page.dart';
