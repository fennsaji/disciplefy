export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      achievements: {
        Row: {
          category: string
          created_at: string | null
          description_en: string
          description_hi: string
          description_ml: string
          icon: string
          id: string
          name_en: string
          name_hi: string
          name_ml: string
          sort_order: number | null
          threshold: number | null
          xp_reward: number | null
        }
        Insert: {
          category: string
          created_at?: string | null
          description_en: string
          description_hi: string
          description_ml: string
          icon: string
          id: string
          name_en: string
          name_hi: string
          name_ml: string
          sort_order?: number | null
          threshold?: number | null
          xp_reward?: number | null
        }
        Update: {
          category?: string
          created_at?: string | null
          description_en?: string
          description_hi?: string
          description_ml?: string
          icon?: string
          id?: string
          name_en?: string
          name_hi?: string
          name_ml?: string
          sort_order?: number | null
          threshold?: number | null
          xp_reward?: number | null
        }
        Relationships: []
      }
      analytics_events: {
        Row: {
          created_at: string | null
          event_data: Json | null
          event_type: string
          id: string
          ip_address: unknown | null
          session_id: string | null
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          event_data?: Json | null
          event_type: string
          id?: string
          ip_address?: unknown | null
          session_id?: string | null
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          event_data?: Json | null
          event_type?: string
          id?: string
          ip_address?: unknown | null
          session_id?: string | null
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      bible_books: {
        Row: {
          abbrev: string
          chapters: number
          id: number
          name: string
          search_terms: string[]
          testament: string
        }
        Insert: {
          abbrev: string
          chapters: number
          id: number
          name: string
          search_terms?: string[]
          testament: string
        }
        Update: {
          abbrev?: string
          chapters?: number
          id?: number
          name?: string
          search_terms?: string[]
          testament?: string
        }
        Relationships: []
      }
      conversation_messages: {
        Row: {
          content: string
          conversation_id: string
          created_at: string
          id: string
          role: string
          tokens_consumed: number | null
        }
        Insert: {
          content: string
          conversation_id: string
          created_at?: string
          id?: string
          role: string
          tokens_consumed?: number | null
        }
        Update: {
          content?: string
          conversation_id?: string
          created_at?: string
          id?: string
          role?: string
          tokens_consumed?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "conversation_messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "study_guide_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_verse_streaks: {
        Row: {
          created_at: string
          current_streak: number
          id: number
          last_viewed_at: string | null
          longest_streak: number
          total_views: number
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          current_streak?: number
          id?: number
          last_viewed_at?: string | null
          longest_streak?: number
          total_views?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          current_streak?: number
          id?: number
          last_viewed_at?: string | null
          longest_streak?: number
          total_views?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      daily_verses_cache: {
        Row: {
          created_at: string
          date_key: string
          expires_at: string
          id: number
          is_active: boolean | null
          updated_at: string
          uuid: string
          verse_data: Json
        }
        Insert: {
          created_at?: string
          date_key: string
          expires_at: string
          id?: number
          is_active?: boolean | null
          updated_at?: string
          uuid?: string
          verse_data: Json
        }
        Update: {
          created_at?: string
          date_key?: string
          expires_at?: string
          id?: number
          is_active?: boolean | null
          updated_at?: string
          uuid?: string
          verse_data?: Json
        }
        Relationships: []
      }
      feedback: {
        Row: {
          category: string | null
          created_at: string | null
          id: string
          message: string | null
          sentiment_score: number | null
          study_guide_id: string | null
          user_id: string | null
          was_helpful: boolean
        }
        Insert: {
          category?: string | null
          created_at?: string | null
          id?: string
          message?: string | null
          sentiment_score?: number | null
          study_guide_id?: string | null
          user_id?: string | null
          was_helpful: boolean
        }
        Update: {
          category?: string | null
          created_at?: string | null
          id?: string
          message?: string | null
          sentiment_score?: number | null
          study_guide_id?: string | null
          user_id?: string | null
          was_helpful?: boolean
        }
        Relationships: []
      }
      learning_path_topics: {
        Row: {
          created_at: string | null
          id: string
          is_milestone: boolean | null
          learning_path_id: string
          position: number
          topic_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          is_milestone?: boolean | null
          learning_path_id: string
          position?: number
          topic_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          is_milestone?: boolean | null
          learning_path_id?: string
          position?: number
          topic_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "learning_path_topics_learning_path_id_fkey"
            columns: ["learning_path_id"]
            isOneToOne: false
            referencedRelation: "learning_paths"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "learning_path_topics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "learning_path_topics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      learning_path_translations: {
        Row: {
          created_at: string | null
          description: string
          lang_code: string
          learning_path_id: string
          title: string
        }
        Insert: {
          created_at?: string | null
          description: string
          lang_code: string
          learning_path_id: string
          title: string
        }
        Update: {
          created_at?: string | null
          description?: string
          lang_code?: string
          learning_path_id?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "learning_path_translations_learning_path_id_fkey"
            columns: ["learning_path_id"]
            isOneToOne: false
            referencedRelation: "learning_paths"
            referencedColumns: ["id"]
          },
        ]
      }
      learning_paths: {
        Row: {
          color: string | null
          created_at: string | null
          description: string
          disciple_level: string
          display_order: number | null
          estimated_days: number | null
          icon_name: string | null
          id: string
          is_active: boolean | null
          is_featured: boolean | null
          slug: string
          title: string
          total_xp: number | null
          updated_at: string | null
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          description: string
          disciple_level?: string
          display_order?: number | null
          estimated_days?: number | null
          icon_name?: string | null
          id?: string
          is_active?: boolean | null
          is_featured?: boolean | null
          slug: string
          title: string
          total_xp?: number | null
          updated_at?: string | null
        }
        Update: {
          color?: string | null
          created_at?: string | null
          description?: string
          disciple_level?: string
          display_order?: number | null
          estimated_days?: number | null
          icon_name?: string | null
          id?: string
          is_active?: boolean | null
          is_featured?: boolean | null
          slug?: string
          title?: string
          total_xp?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      life_situation_topics: {
        Row: {
          created_at: string | null
          display_order: number | null
          id: string
          life_situation_id: string
          relevance_score: number | null
          topic_id: string
        }
        Insert: {
          created_at?: string | null
          display_order?: number | null
          id?: string
          life_situation_id: string
          relevance_score?: number | null
          topic_id: string
        }
        Update: {
          created_at?: string | null
          display_order?: number | null
          id?: string
          life_situation_id?: string
          relevance_score?: number | null
          topic_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "life_situation_topics_life_situation_id_fkey"
            columns: ["life_situation_id"]
            isOneToOne: false
            referencedRelation: "life_situations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "life_situation_topics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "life_situation_topics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      life_situation_translations: {
        Row: {
          created_at: string | null
          description: string | null
          id: string
          language_code: string
          life_situation_id: string
          subtitle: string | null
          title: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: string
          language_code?: string
          life_situation_id: string
          subtitle?: string | null
          title: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: string
          language_code?: string
          life_situation_id?: string
          subtitle?: string | null
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "life_situation_translations_life_situation_id_fkey"
            columns: ["life_situation_id"]
            isOneToOne: false
            referencedRelation: "life_situations"
            referencedColumns: ["id"]
          },
        ]
      }
      life_situations: {
        Row: {
          color_hex: string | null
          created_at: string | null
          display_order: number | null
          icon_name: string
          id: string
          is_active: boolean | null
          slug: string
          updated_at: string | null
        }
        Insert: {
          color_hex?: string | null
          created_at?: string | null
          display_order?: number | null
          icon_name?: string
          id?: string
          is_active?: boolean | null
          slug: string
          updated_at?: string | null
        }
        Update: {
          color_hex?: string | null
          created_at?: string | null
          display_order?: number | null
          icon_name?: string
          id?: string
          is_active?: boolean | null
          slug?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      llm_security_events: {
        Row: {
          action_taken: string | null
          created_at: string | null
          detection_details: Json | null
          event_type: string
          id: string
          input_text: string | null
          ip_address: unknown | null
          risk_score: number | null
          session_id: string | null
          user_id: string | null
        }
        Insert: {
          action_taken?: string | null
          created_at?: string | null
          detection_details?: Json | null
          event_type: string
          id?: string
          input_text?: string | null
          ip_address?: unknown | null
          risk_score?: number | null
          session_id?: string | null
          user_id?: string | null
        }
        Update: {
          action_taken?: string | null
          created_at?: string | null
          detection_details?: Json | null
          event_type?: string
          id?: string
          input_text?: string | null
          ip_address?: unknown | null
          risk_score?: number | null
          session_id?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      memory_challenges: {
        Row: {
          badge_icon: string | null
          challenge_type: string
          created_at: string
          end_date: string
          id: string
          is_active: boolean | null
          start_date: string
          target_type: string
          target_value: number
          xp_reward: number
        }
        Insert: {
          badge_icon?: string | null
          challenge_type: string
          created_at?: string
          end_date: string
          id?: string
          is_active?: boolean | null
          start_date: string
          target_type: string
          target_value: number
          xp_reward: number
        }
        Update: {
          badge_icon?: string | null
          challenge_type?: string
          created_at?: string
          end_date?: string
          id?: string
          is_active?: boolean | null
          start_date?: string
          target_type?: string
          target_value?: number
          xp_reward?: number
        }
        Relationships: []
      }
      memory_daily_goals: {
        Row: {
          added_new_verses: number | null
          bonus_xp_awarded: number | null
          completed_reviews: number | null
          created_at: string
          goal_achieved: boolean | null
          goal_date: string
          id: string
          target_new_verses: number | null
          target_reviews: number | null
          user_id: string
        }
        Insert: {
          added_new_verses?: number | null
          bonus_xp_awarded?: number | null
          completed_reviews?: number | null
          created_at?: string
          goal_achieved?: boolean | null
          goal_date: string
          id?: string
          target_new_verses?: number | null
          target_reviews?: number | null
          user_id: string
        }
        Update: {
          added_new_verses?: number | null
          bonus_xp_awarded?: number | null
          completed_reviews?: number | null
          created_at?: string
          goal_achieved?: boolean | null
          goal_date?: string
          id?: string
          target_new_verses?: number | null
          target_reviews?: number | null
          user_id?: string
        }
        Relationships: []
      }
      memory_practice_modes: {
        Row: {
          average_time_seconds: number | null
          created_at: string
          id: string
          is_favorite: boolean | null
          memory_verse_id: string
          mode_type: string
          success_rate: number | null
          times_practiced: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          average_time_seconds?: number | null
          created_at?: string
          id?: string
          is_favorite?: boolean | null
          memory_verse_id: string
          mode_type: string
          success_rate?: number | null
          times_practiced?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          average_time_seconds?: number | null
          created_at?: string
          id?: string
          is_favorite?: boolean | null
          memory_verse_id?: string
          mode_type?: string
          success_rate?: number | null
          times_practiced?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "memory_practice_modes_memory_verse_id_fkey"
            columns: ["memory_verse_id"]
            isOneToOne: false
            referencedRelation: "memory_verses"
            referencedColumns: ["id"]
          },
        ]
      }
      memory_verse_collection_items: {
        Row: {
          added_at: string
          collection_id: string
          memory_verse_id: string
        }
        Insert: {
          added_at?: string
          collection_id: string
          memory_verse_id: string
        }
        Update: {
          added_at?: string
          collection_id?: string
          memory_verse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "memory_verse_collection_items_collection_id_fkey"
            columns: ["collection_id"]
            isOneToOne: false
            referencedRelation: "memory_verse_collections"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memory_verse_collection_items_memory_verse_id_fkey"
            columns: ["memory_verse_id"]
            isOneToOne: false
            referencedRelation: "memory_verses"
            referencedColumns: ["id"]
          },
        ]
      }
      memory_verse_collections: {
        Row: {
          category: string | null
          color: string | null
          created_at: string
          description: string | null
          icon: string | null
          id: string
          name: string
          updated_at: string
          user_id: string
          verse_count: number | null
        }
        Insert: {
          category?: string | null
          color?: string | null
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          name: string
          updated_at?: string
          user_id: string
          verse_count?: number | null
        }
        Update: {
          category?: string | null
          color?: string | null
          created_at?: string
          description?: string | null
          icon?: string | null
          id?: string
          name?: string
          updated_at?: string
          user_id?: string
          verse_count?: number | null
        }
        Relationships: []
      }
      memory_verse_mastery: {
        Row: {
          confidence_rating: number | null
          id: string
          mastery_level: string
          mastery_percentage: number | null
          memory_verse_id: string
          modes_mastered: number | null
          perfect_recalls: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          confidence_rating?: number | null
          id?: string
          mastery_level?: string
          mastery_percentage?: number | null
          memory_verse_id: string
          modes_mastered?: number | null
          perfect_recalls?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          confidence_rating?: number | null
          id?: string
          mastery_level?: string
          mastery_percentage?: number | null
          memory_verse_id?: string
          modes_mastered?: number | null
          perfect_recalls?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "memory_verse_mastery_memory_verse_id_fkey"
            columns: ["memory_verse_id"]
            isOneToOne: false
            referencedRelation: "memory_verses"
            referencedColumns: ["id"]
          },
        ]
      }
      memory_verse_streaks: {
        Row: {
          created_at: string
          current_streak: number | null
          freeze_days_available: number | null
          freeze_days_used: number | null
          last_practice_date: string | null
          longest_streak: number | null
          milestone_10_date: string | null
          milestone_100_date: string | null
          milestone_30_date: string | null
          milestone_365_date: string | null
          total_practice_days: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          current_streak?: number | null
          freeze_days_available?: number | null
          freeze_days_used?: number | null
          last_practice_date?: string | null
          longest_streak?: number | null
          milestone_10_date?: string | null
          milestone_100_date?: string | null
          milestone_30_date?: string | null
          milestone_365_date?: string | null
          total_practice_days?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          current_streak?: number | null
          freeze_days_available?: number | null
          freeze_days_used?: number | null
          last_practice_date?: string | null
          longest_streak?: number | null
          milestone_10_date?: string | null
          milestone_100_date?: string | null
          milestone_30_date?: string | null
          milestone_365_date?: string | null
          total_practice_days?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      memory_verses: {
        Row: {
          added_date: string
          created_at: string
          ease_factor: number
          id: string
          interval_days: number
          is_fully_mastered: boolean
          language: string
          last_reviewed: string | null
          mastery_level: string | null
          next_review_date: string
          preferred_practice_mode: string | null
          repetitions: number
          source_id: string | null
          source_type: string
          times_perfectly_recalled: number | null
          total_reviews: number
          updated_at: string
          user_id: string
          verse_reference: string
          verse_text: string
        }
        Insert: {
          added_date?: string
          created_at?: string
          ease_factor?: number
          id?: string
          interval_days?: number
          is_fully_mastered?: boolean
          language?: string
          last_reviewed?: string | null
          mastery_level?: string | null
          next_review_date?: string
          preferred_practice_mode?: string | null
          repetitions?: number
          source_id?: string | null
          source_type: string
          times_perfectly_recalled?: number | null
          total_reviews?: number
          updated_at?: string
          user_id: string
          verse_reference: string
          verse_text: string
        }
        Update: {
          added_date?: string
          created_at?: string
          ease_factor?: number
          id?: string
          interval_days?: number
          is_fully_mastered?: boolean
          language?: string
          last_reviewed?: string | null
          mastery_level?: string | null
          next_review_date?: string
          preferred_practice_mode?: string | null
          repetitions?: number
          source_id?: string | null
          source_type?: string
          times_perfectly_recalled?: number | null
          total_reviews?: number
          updated_at?: string
          user_id?: string
          verse_reference?: string
          verse_text?: string
        }
        Relationships: [
          {
            foreignKeyName: "memory_verses_source_id_fkey"
            columns: ["source_id"]
            isOneToOne: false
            referencedRelation: "daily_verses_cache"
            referencedColumns: ["uuid"]
          },
        ]
      }
      notification_logs: {
        Row: {
          body: string
          created_at: string | null
          delivery_status: string | null
          error_message: string | null
          fcm_message_id: string | null
          id: string
          language: string | null
          notification_type: string
          sent_at: string | null
          title: string
          topic_id: string | null
          user_id: string | null
          verse_reference: string | null
        }
        Insert: {
          body: string
          created_at?: string | null
          delivery_status?: string | null
          error_message?: string | null
          fcm_message_id?: string | null
          id?: string
          language?: string | null
          notification_type: string
          sent_at?: string | null
          title: string
          topic_id?: string | null
          user_id?: string | null
          verse_reference?: string | null
        }
        Update: {
          body?: string
          created_at?: string | null
          delivery_status?: string | null
          error_message?: string | null
          fcm_message_id?: string | null
          id?: string
          language?: string | null
          notification_type?: string
          sent_at?: string | null
          title?: string
          topic_id?: string | null
          user_id?: string | null
          verse_reference?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notification_logs_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_logs_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      otp_requests: {
        Row: {
          attempts: number | null
          created_at: string | null
          expires_at: string | null
          id: string
          ip_address: unknown | null
          is_verified: boolean | null
          otp_code: string
          phone_number: string
        }
        Insert: {
          attempts?: number | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          ip_address?: unknown | null
          is_verified?: boolean | null
          otp_code: string
          phone_number: string
        }
        Update: {
          attempts?: number | null
          created_at?: string | null
          expires_at?: string | null
          id?: string
          ip_address?: unknown | null
          is_verified?: boolean | null
          otp_code?: string
          phone_number?: string
        }
        Relationships: []
      }
      payment_method_usage_history: {
        Row: {
          created_at: string | null
          id: string
          metadata: Json | null
          payment_method_id: string
          transaction_amount: number
          transaction_id: string | null
          transaction_type: string
          used_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          id?: string
          metadata?: Json | null
          payment_method_id: string
          transaction_amount: number
          transaction_id?: string | null
          transaction_type: string
          used_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          id?: string
          metadata?: Json | null
          payment_method_id?: string
          transaction_amount?: number
          transaction_id?: string | null
          transaction_type?: string
          used_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_method_usage_history_payment_method_id_fkey"
            columns: ["payment_method_id"]
            isOneToOne: false
            referencedRelation: "saved_payment_methods"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_preferences: {
        Row: {
          auto_save_methods: boolean | null
          created_at: string | null
          default_payment_type: string | null
          enable_one_click_purchase: boolean | null
          enable_upi_autopay: boolean | null
          id: string
          prefer_mobile_wallets: boolean | null
          preferred_method_type: string | null
          preferred_wallet: string | null
          require_cvv_for_saved_cards: boolean | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          auto_save_methods?: boolean | null
          created_at?: string | null
          default_payment_type?: string | null
          enable_one_click_purchase?: boolean | null
          enable_upi_autopay?: boolean | null
          id?: string
          prefer_mobile_wallets?: boolean | null
          preferred_method_type?: string | null
          preferred_wallet?: string | null
          require_cvv_for_saved_cards?: boolean | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          auto_save_methods?: boolean | null
          created_at?: string | null
          default_payment_type?: string | null
          enable_one_click_purchase?: boolean | null
          enable_upi_autopay?: boolean | null
          id?: string
          prefer_mobile_wallets?: boolean | null
          preferred_method_type?: string | null
          preferred_wallet?: string | null
          require_cvv_for_saved_cards?: boolean | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      pending_token_purchases: {
        Row: {
          amount_paise: number
          created_at: string | null
          error_message: string | null
          expires_at: string | null
          id: string
          order_id: string
          payment_id: string | null
          status: string | null
          token_amount: number
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          amount_paise: number
          created_at?: string | null
          error_message?: string | null
          expires_at?: string | null
          id?: string
          order_id: string
          payment_id?: string | null
          status?: string | null
          token_amount: number
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          amount_paise?: number
          created_at?: string | null
          error_message?: string | null
          expires_at?: string | null
          id?: string
          order_id?: string
          payment_id?: string | null
          status?: string | null
          token_amount?: number
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      purchase_history: {
        Row: {
          cost_paise: number
          cost_rupees: number
          created_at: string | null
          id: string
          order_id: string
          payment_id: string
          payment_method: string | null
          payment_provider: string | null
          purchased_at: string | null
          receipt_number: string | null
          receipt_url: string | null
          saved_payment_method_id: string | null
          status: string
          token_amount: number
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          cost_paise: number
          cost_rupees: number
          created_at?: string | null
          id?: string
          order_id: string
          payment_id: string
          payment_method?: string | null
          payment_provider?: string | null
          purchased_at?: string | null
          receipt_number?: string | null
          receipt_url?: string | null
          saved_payment_method_id?: string | null
          status?: string
          token_amount: number
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          cost_paise?: number
          cost_rupees?: number
          created_at?: string | null
          id?: string
          order_id?: string
          payment_id?: string
          payment_method?: string | null
          payment_provider?: string | null
          purchased_at?: string | null
          receipt_number?: string | null
          receipt_url?: string | null
          saved_payment_method_id?: string | null
          status?: string
          token_amount?: number
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "purchase_history_saved_payment_method_id_fkey"
            columns: ["saved_payment_method_id"]
            isOneToOne: false
            referencedRelation: "saved_payment_methods"
            referencedColumns: ["id"]
          },
        ]
      }
      purchase_issue_reports: {
        Row: {
          admin_notes: string | null
          cost_rupees: number
          created_at: string | null
          description: string
          id: string
          issue_type: string
          order_id: string
          payment_id: string
          purchase_id: string
          purchased_at: string
          resolved_at: string | null
          resolved_by: string | null
          screenshot_urls: string[] | null
          status: string | null
          token_amount: number
          updated_at: string | null
          user_email: string
          user_id: string
        }
        Insert: {
          admin_notes?: string | null
          cost_rupees: number
          created_at?: string | null
          description: string
          id?: string
          issue_type: string
          order_id: string
          payment_id: string
          purchase_id: string
          purchased_at: string
          resolved_at?: string | null
          resolved_by?: string | null
          screenshot_urls?: string[] | null
          status?: string | null
          token_amount: number
          updated_at?: string | null
          user_email: string
          user_id: string
        }
        Update: {
          admin_notes?: string | null
          cost_rupees?: number
          created_at?: string | null
          description?: string
          id?: string
          issue_type?: string
          order_id?: string
          payment_id?: string
          purchase_id?: string
          purchased_at?: string
          resolved_at?: string | null
          resolved_by?: string | null
          screenshot_urls?: string[] | null
          status?: string | null
          token_amount?: number
          updated_at?: string | null
          user_email?: string
          user_id?: string
        }
        Relationships: []
      }
      rate_limit_usage: {
        Row: {
          count: number
          created_at: string
          id: string
          identifier: string
          last_activity: string
          updated_at: string
          user_type: string
          window_start: string
        }
        Insert: {
          count?: number
          created_at?: string
          id?: string
          identifier: string
          last_activity?: string
          updated_at?: string
          user_type: string
          window_start: string
        }
        Update: {
          count?: number
          created_at?: string
          id?: string
          identifier?: string
          last_activity?: string
          updated_at?: string
          user_type?: string
          window_start?: string
        }
        Relationships: []
      }
      receipt_counters: {
        Row: {
          created_at: string | null
          last_seq: number
          updated_at: string | null
          year_month: string
        }
        Insert: {
          created_at?: string | null
          last_seq?: number
          updated_at?: string | null
          year_month: string
        }
        Update: {
          created_at?: string | null
          last_seq?: number
          updated_at?: string | null
          year_month?: string
        }
        Relationships: []
      }
      recommended_topics: {
        Row: {
          category: string
          created_at: string | null
          description: string | null
          display_order: number | null
          id: string
          is_active: boolean | null
          study_guide_id: string | null
          tags: string[]
          title: string | null
          updated_at: string | null
          xp_value: number | null
        }
        Insert: {
          category: string
          created_at?: string | null
          description?: string | null
          display_order?: number | null
          id?: string
          is_active?: boolean | null
          study_guide_id?: string | null
          tags?: string[]
          title?: string | null
          updated_at?: string | null
          xp_value?: number | null
        }
        Update: {
          category?: string
          created_at?: string | null
          description?: string | null
          display_order?: number | null
          id?: string
          is_active?: boolean | null
          study_guide_id?: string | null
          tags?: string[]
          title?: string | null
          updated_at?: string | null
          xp_value?: number | null
        }
        Relationships: []
      }
      recommended_topics_translations: {
        Row: {
          category: string
          description: string
          lang_code: string
          title: string
          topic_id: string
        }
        Insert: {
          category: string
          description: string
          lang_code: string
          title: string
          topic_id: string
        }
        Update: {
          category?: string
          description?: string
          lang_code?: string
          title?: string
          topic_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recommended_topics_translations_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recommended_topics_translations_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      review_history: {
        Row: {
          average_quality: number | null
          created_at: string
          id: string
          memory_verse_id: string
          review_date: string
          reviews_count: number
          user_id: string
        }
        Insert: {
          average_quality?: number | null
          created_at?: string
          id?: string
          memory_verse_id: string
          review_date: string
          reviews_count?: number
          user_id: string
        }
        Update: {
          average_quality?: number | null
          created_at?: string
          id?: string
          memory_verse_id?: string
          review_date?: string
          reviews_count?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "review_history_memory_verse_id_fkey"
            columns: ["memory_verse_id"]
            isOneToOne: false
            referencedRelation: "memory_verses"
            referencedColumns: ["id"]
          },
        ]
      }
      review_sessions: {
        Row: {
          accuracy_percentage: number | null
          confidence_rating: number | null
          created_at: string
          hints_used: number | null
          id: string
          memory_verse_id: string
          new_ease_factor: number
          new_interval_days: number
          new_repetitions: number
          practice_mode: string | null
          quality_rating: number
          review_date: string
          time_spent_seconds: number | null
          user_id: string
        }
        Insert: {
          accuracy_percentage?: number | null
          confidence_rating?: number | null
          created_at?: string
          hints_used?: number | null
          id?: string
          memory_verse_id: string
          new_ease_factor: number
          new_interval_days: number
          new_repetitions: number
          practice_mode?: string | null
          quality_rating: number
          review_date?: string
          time_spent_seconds?: number | null
          user_id: string
        }
        Update: {
          accuracy_percentage?: number | null
          confidence_rating?: number | null
          created_at?: string
          hints_used?: number | null
          id?: string
          memory_verse_id?: string
          new_ease_factor?: number
          new_interval_days?: number
          new_repetitions?: number
          practice_mode?: string | null
          quality_rating?: number
          review_date?: string
          time_spent_seconds?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "review_sessions_memory_verse_id_fkey"
            columns: ["memory_verse_id"]
            isOneToOne: false
            referencedRelation: "memory_verses"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_payment_methods: {
        Row: {
          brand: string | null
          created_at: string | null
          deleted_at: string | null
          display_name: string | null
          encrypted_token: string | null
          encryption_key_id: string | null
          expiry_month: number | null
          expiry_year: number | null
          id: string
          is_active: boolean | null
          is_default: boolean | null
          last_four: string | null
          last_used_at: string | null
          method_type: string
          provider: string
          security_metadata: Json | null
          token_hash: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          brand?: string | null
          created_at?: string | null
          deleted_at?: string | null
          display_name?: string | null
          encrypted_token?: string | null
          encryption_key_id?: string | null
          expiry_month?: number | null
          expiry_year?: number | null
          id?: string
          is_active?: boolean | null
          is_default?: boolean | null
          last_four?: string | null
          last_used_at?: string | null
          method_type: string
          provider: string
          security_metadata?: Json | null
          token_hash?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          brand?: string | null
          created_at?: string | null
          deleted_at?: string | null
          display_name?: string | null
          encrypted_token?: string | null
          encryption_key_id?: string | null
          expiry_month?: number | null
          expiry_year?: number | null
          id?: string
          is_active?: boolean | null
          is_default?: boolean | null
          last_four?: string | null
          last_used_at?: string | null
          method_type?: string
          provider?: string
          security_metadata?: Json | null
          token_hash?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      seasonal_topics: {
        Row: {
          created_at: string | null
          end_day: number | null
          end_month: number | null
          id: string
          is_active: boolean | null
          priority: number | null
          season: Database["public"]["Enums"]["season_type"]
          start_day: number | null
          start_month: number | null
          topic_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          end_day?: number | null
          end_month?: number | null
          id?: string
          is_active?: boolean | null
          priority?: number | null
          season: Database["public"]["Enums"]["season_type"]
          start_day?: number | null
          start_month?: number | null
          topic_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          end_day?: number | null
          end_month?: number | null
          id?: string
          is_active?: boolean | null
          priority?: number | null
          season?: Database["public"]["Enums"]["season_type"]
          start_day?: number | null
          start_month?: number | null
          topic_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "seasonal_topics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seasonal_topics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      seasonal_translations: {
        Row: {
          created_at: string | null
          description: string | null
          icon_name: string | null
          id: string
          language_code: string
          season: Database["public"]["Enums"]["season_type"]
          subtitle: string | null
          title: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          icon_name?: string | null
          id?: string
          language_code?: string
          season: Database["public"]["Enums"]["season_type"]
          subtitle?: string | null
          title: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          icon_name?: string | null
          id?: string
          language_code?: string
          season?: Database["public"]["Enums"]["season_type"]
          subtitle?: string | null
          title?: string
        }
        Relationships: []
      }
      study_guide_conversations: {
        Row: {
          created_at: string
          id: string
          session_id: string | null
          study_guide_id: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          session_id?: string | null
          study_guide_id: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          session_id?: string | null
          study_guide_id?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "study_guide_conversations_study_guide_id_fkey"
            columns: ["study_guide_id"]
            isOneToOne: false
            referencedRelation: "study_guides"
            referencedColumns: ["id"]
          },
        ]
      }
      study_guides: {
        Row: {
          context: string
          context_question: string | null
          created_at: string | null
          creator_session_id: string | null
          creator_user_id: string | null
          extended_content: Json | null
          id: string
          input_type: string
          input_value: string
          input_value_hash: string
          interpretation: string
          interpretation_insights: string[] | null
          language: string
          prayer_points: string[]
          prayer_question: string | null
          reflection_answers: string[] | null
          reflection_question: string | null
          reflection_questions: string[]
          related_verses: string[]
          related_verses_question: string | null
          study_mode: string | null
          summary: string
          summary_insights: string[] | null
          summary_question: string | null
          topic_id: string | null
          updated_at: string | null
        }
        Insert: {
          context: string
          context_question?: string | null
          created_at?: string | null
          creator_session_id?: string | null
          creator_user_id?: string | null
          extended_content?: Json | null
          id?: string
          input_type: string
          input_value: string
          input_value_hash: string
          interpretation: string
          interpretation_insights?: string[] | null
          language: string
          prayer_points: string[]
          prayer_question?: string | null
          reflection_answers?: string[] | null
          reflection_question?: string | null
          reflection_questions: string[]
          related_verses: string[]
          related_verses_question?: string | null
          study_mode?: string | null
          summary: string
          summary_insights?: string[] | null
          summary_question?: string | null
          topic_id?: string | null
          updated_at?: string | null
        }
        Update: {
          context?: string
          context_question?: string | null
          created_at?: string | null
          creator_session_id?: string | null
          creator_user_id?: string | null
          extended_content?: Json | null
          id?: string
          input_type?: string
          input_value?: string
          input_value_hash?: string
          interpretation?: string
          interpretation_insights?: string[] | null
          language?: string
          prayer_points?: string[]
          prayer_question?: string | null
          reflection_answers?: string[] | null
          reflection_question?: string | null
          reflection_questions?: string[]
          related_verses?: string[]
          related_verses_question?: string | null
          study_mode?: string | null
          summary?: string
          summary_insights?: string[] | null
          summary_question?: string | null
          topic_id?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "study_guides_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "study_guides_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      study_reflections: {
        Row: {
          completed_at: string | null
          created_at: string | null
          id: string
          responses: Json
          study_guide_id: string
          study_mode: string
          time_spent_seconds: number | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string | null
          id?: string
          responses?: Json
          study_guide_id: string
          study_mode: string
          time_spent_seconds?: number | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string | null
          id?: string
          responses?: Json
          study_guide_id?: string
          study_mode?: string
          time_spent_seconds?: number | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "study_reflections_study_guide_id_fkey"
            columns: ["study_guide_id"]
            isOneToOne: false
            referencedRelation: "study_guides"
            referencedColumns: ["id"]
          },
        ]
      }
      subscription_config: {
        Row: {
          created_at: string | null
          description: string | null
          key: string
          updated_at: string | null
          value: string
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          key: string
          updated_at?: string | null
          value: string
        }
        Update: {
          created_at?: string | null
          description?: string | null
          key?: string
          updated_at?: string | null
          value?: string
        }
        Relationships: []
      }
      subscription_history: {
        Row: {
          created_at: string
          event_data: Json | null
          event_type: string
          id: string
          new_status: string
          notes: string | null
          payment_amount: number | null
          payment_id: string | null
          payment_status: string | null
          previous_status: string | null
          subscription_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          event_data?: Json | null
          event_type: string
          id?: string
          new_status: string
          notes?: string | null
          payment_amount?: number | null
          payment_id?: string | null
          payment_status?: string | null
          previous_status?: string | null
          subscription_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          event_data?: Json | null
          event_type?: string
          id?: string
          new_status?: string
          notes?: string | null
          payment_amount?: number | null
          payment_id?: string | null
          payment_status?: string | null
          previous_status?: string | null
          subscription_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscription_history_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "subscriptions"
            referencedColumns: ["id"]
          },
        ]
      }
      subscription_invoices: {
        Row: {
          amount_paise: number
          billing_period_end: string
          billing_period_start: string
          created_at: string
          currency: string
          id: string
          invoice_number: string | null
          paid_at: string | null
          payment_method: string | null
          razorpay_invoice_id: string | null
          razorpay_payment_id: string
          status: string
          subscription_id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          amount_paise: number
          billing_period_end: string
          billing_period_start: string
          created_at?: string
          currency?: string
          id?: string
          invoice_number?: string | null
          paid_at?: string | null
          payment_method?: string | null
          razorpay_invoice_id?: string | null
          razorpay_payment_id: string
          status: string
          subscription_id: string
          updated_at?: string
          user_id: string
        }
        Update: {
          amount_paise?: number
          billing_period_end?: string
          billing_period_start?: string
          created_at?: string
          currency?: string
          id?: string
          invoice_number?: string | null
          paid_at?: string | null
          payment_method?: string | null
          razorpay_invoice_id?: string | null
          razorpay_payment_id?: string
          status?: string
          subscription_id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscription_invoices_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "subscriptions"
            referencedColumns: ["id"]
          },
        ]
      }
      subscriptions: {
        Row: {
          amount_paise: number
          cancel_at_cycle_end: boolean | null
          cancellation_reason: string | null
          cancelled_at: string | null
          created_at: string
          currency: string
          current_period_end: string | null
          current_period_start: string | null
          id: string
          next_billing_at: string | null
          paid_count: number | null
          plan_type: string
          razorpay_customer_id: string | null
          razorpay_plan_id: string
          razorpay_subscription_id: string
          remaining_count: number | null
          status: string
          subscription_plan: string | null
          total_count: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          amount_paise: number
          cancel_at_cycle_end?: boolean | null
          cancellation_reason?: string | null
          cancelled_at?: string | null
          created_at?: string
          currency?: string
          current_period_end?: string | null
          current_period_start?: string | null
          id?: string
          next_billing_at?: string | null
          paid_count?: number | null
          plan_type?: string
          razorpay_customer_id?: string | null
          razorpay_plan_id: string
          razorpay_subscription_id: string
          remaining_count?: number | null
          status: string
          subscription_plan?: string | null
          total_count?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          amount_paise?: number
          cancel_at_cycle_end?: boolean | null
          cancellation_reason?: string | null
          cancelled_at?: string | null
          created_at?: string
          currency?: string
          current_period_end?: string | null
          current_period_start?: string | null
          id?: string
          next_billing_at?: string | null
          paid_count?: number | null
          plan_type?: string
          razorpay_customer_id?: string | null
          razorpay_plan_id?: string
          razorpay_subscription_id?: string
          remaining_count?: number | null
          status?: string
          subscription_plan?: string | null
          total_count?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      suggested_verse_translations: {
        Row: {
          created_at: string
          id: string
          language_code: string
          localized_reference: string
          suggested_verse_id: string
          verse_text: string
        }
        Insert: {
          created_at?: string
          id?: string
          language_code: string
          localized_reference: string
          suggested_verse_id: string
          verse_text: string
        }
        Update: {
          created_at?: string
          id?: string
          language_code?: string
          localized_reference?: string
          suggested_verse_id?: string
          verse_text?: string
        }
        Relationships: [
          {
            foreignKeyName: "suggested_verse_translations_suggested_verse_id_fkey"
            columns: ["suggested_verse_id"]
            isOneToOne: false
            referencedRelation: "suggested_verses"
            referencedColumns: ["id"]
          },
        ]
      }
      suggested_verses: {
        Row: {
          book: string
          category: string
          chapter: number
          created_at: string
          display_order: number | null
          id: string
          is_active: boolean | null
          reference: string
          tags: string[] | null
          verse_end: number | null
          verse_start: number
        }
        Insert: {
          book: string
          category: string
          chapter: number
          created_at?: string
          display_order?: number | null
          id?: string
          is_active?: boolean | null
          reference: string
          tags?: string[] | null
          verse_end?: number | null
          verse_start: number
        }
        Update: {
          book?: string
          category?: string
          chapter?: number
          created_at?: string
          display_order?: number | null
          id?: string
          is_active?: boolean | null
          reference?: string
          tags?: string[] | null
          verse_end?: number | null
          verse_start?: number
        }
        Relationships: []
      }
      token_pricing_packages: {
        Row: {
          base_price_rupees: number
          created_at: string
          discount_percentage: number
          discounted_price_rupees: number
          display_order: number
          id: number
          is_active: boolean
          is_popular: boolean
          token_amount: number
          updated_at: string
        }
        Insert: {
          base_price_rupees: number
          created_at?: string
          discount_percentage?: number
          discounted_price_rupees: number
          display_order?: number
          id?: number
          is_active?: boolean
          is_popular?: boolean
          token_amount: number
          updated_at?: string
        }
        Update: {
          base_price_rupees?: number
          created_at?: string
          discount_percentage?: number
          discounted_price_rupees?: number
          display_order?: number
          id?: number
          is_active?: boolean
          is_popular?: boolean
          token_amount?: number
          updated_at?: string
        }
        Relationships: []
      }
      topic_engagement_metrics: {
        Row: {
          completion_count: number | null
          created_at: string | null
          date: string
          id: string
          save_count: number | null
          share_count: number | null
          study_count: number | null
          topic_id: string
          updated_at: string | null
        }
        Insert: {
          completion_count?: number | null
          created_at?: string | null
          date?: string
          id?: string
          save_count?: number | null
          share_count?: number | null
          study_count?: number | null
          topic_id: string
          updated_at?: string | null
        }
        Update: {
          completion_count?: number | null
          created_at?: string | null
          date?: string
          id?: string
          save_count?: number | null
          share_count?: number | null
          study_count?: number | null
          topic_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "topic_engagement_metrics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "topic_engagement_metrics_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      topic_scripture_references: {
        Row: {
          book_abbrev: string
          book_name: string
          book_number: number
          chapter_end: number | null
          chapter_start: number | null
          created_at: string | null
          id: string
          is_primary_reference: boolean | null
          reference_text: string
          relevance_score: number | null
          topic_id: string
          updated_at: string | null
          verse_end: number | null
          verse_start: number | null
        }
        Insert: {
          book_abbrev: string
          book_name: string
          book_number: number
          chapter_end?: number | null
          chapter_start?: number | null
          created_at?: string | null
          id?: string
          is_primary_reference?: boolean | null
          reference_text: string
          relevance_score?: number | null
          topic_id: string
          updated_at?: string | null
          verse_end?: number | null
          verse_start?: number | null
        }
        Update: {
          book_abbrev?: string
          book_name?: string
          book_number?: number
          chapter_end?: number | null
          chapter_start?: number | null
          created_at?: string | null
          id?: string
          is_primary_reference?: boolean | null
          reference_text?: string
          relevance_score?: number | null
          topic_id?: string
          updated_at?: string | null
          verse_end?: number | null
          verse_start?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "topic_scripture_references_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "topic_scripture_references_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      user_achievements: {
        Row: {
          achievement_id: string
          id: string
          notified: boolean | null
          unlocked_at: string
          user_id: string
        }
        Insert: {
          achievement_id: string
          id?: string
          notified?: boolean | null
          unlocked_at?: string
          user_id: string
        }
        Update: {
          achievement_id?: string
          id?: string
          notified?: boolean | null
          unlocked_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_achievements_achievement_id_fkey"
            columns: ["achievement_id"]
            isOneToOne: false
            referencedRelation: "achievements"
            referencedColumns: ["id"]
          },
        ]
      }
      user_challenge_progress: {
        Row: {
          challenge_id: string
          completed_at: string | null
          current_progress: number | null
          is_completed: boolean | null
          user_id: string
          xp_claimed: boolean | null
        }
        Insert: {
          challenge_id: string
          completed_at?: string | null
          current_progress?: number | null
          is_completed?: boolean | null
          user_id: string
          xp_claimed?: boolean | null
        }
        Update: {
          challenge_id?: string
          completed_at?: string | null
          current_progress?: number | null
          is_completed?: boolean | null
          user_id?: string
          xp_claimed?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "user_challenge_progress_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "memory_challenges"
            referencedColumns: ["id"]
          },
        ]
      }
      user_learning_path_progress: {
        Row: {
          completed_at: string | null
          created_at: string | null
          current_topic_position: number | null
          enrolled_at: string | null
          id: string
          last_activity_at: string | null
          learning_path_id: string
          started_at: string | null
          topics_completed: number | null
          total_xp_earned: number | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string | null
          current_topic_position?: number | null
          enrolled_at?: string | null
          id?: string
          last_activity_at?: string | null
          learning_path_id: string
          started_at?: string | null
          topics_completed?: number | null
          total_xp_earned?: number | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string | null
          current_topic_position?: number | null
          enrolled_at?: string | null
          id?: string
          last_activity_at?: string | null
          learning_path_id?: string
          started_at?: string | null
          topics_completed?: number | null
          total_xp_earned?: number | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_learning_path_progress_learning_path_id_fkey"
            columns: ["learning_path_id"]
            isOneToOne: false
            referencedRelation: "learning_paths"
            referencedColumns: ["id"]
          },
        ]
      }
      user_notification_preferences: {
        Row: {
          created_at: string | null
          daily_verse_enabled: boolean | null
          id: string
          memory_verse_reminder_enabled: boolean
          memory_verse_reminder_time: string
          recommended_topic_enabled: boolean | null
          streak_lost_enabled: boolean
          streak_milestone_enabled: boolean
          streak_reminder_enabled: boolean
          streak_reminder_time: string
          timezone_offset_minutes: number | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          daily_verse_enabled?: boolean | null
          id?: string
          memory_verse_reminder_enabled?: boolean
          memory_verse_reminder_time?: string
          recommended_topic_enabled?: boolean | null
          streak_lost_enabled?: boolean
          streak_milestone_enabled?: boolean
          streak_reminder_enabled?: boolean
          streak_reminder_time?: string
          timezone_offset_minutes?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          daily_verse_enabled?: boolean | null
          id?: string
          memory_verse_reminder_enabled?: boolean
          memory_verse_reminder_time?: string
          recommended_topic_enabled?: boolean | null
          streak_lost_enabled?: boolean
          streak_milestone_enabled?: boolean
          streak_reminder_enabled?: boolean
          streak_reminder_time?: string
          timezone_offset_minutes?: number | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      user_notification_tokens: {
        Row: {
          created_at: string | null
          fcm_token: string
          id: string
          platform: string
          token_updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          fcm_token: string
          id?: string
          platform: string
          token_updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          fcm_token?: string
          id?: string
          platform?: string
          token_updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      user_personalization: {
        Row: {
          created_at: string | null
          faith_journey: string | null
          id: string
          questionnaire_completed: boolean | null
          questionnaire_skipped: boolean | null
          seeking: string[] | null
          time_commitment: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          faith_journey?: string | null
          id?: string
          questionnaire_completed?: boolean | null
          questionnaire_skipped?: boolean | null
          seeking?: string[] | null
          time_commitment?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          faith_journey?: string | null
          id?: string
          questionnaire_completed?: boolean | null
          questionnaire_skipped?: boolean | null
          seeking?: string[] | null
          time_commitment?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      user_preferences: {
        Row: {
          created_at: string | null
          default_study_mode: string | null
          id: string
          preferred_plan: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          default_study_mode?: string | null
          id?: string
          preferred_plan?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          default_study_mode?: string | null
          id?: string
          preferred_plan?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      user_profiles: {
        Row: {
          age_group: string | null
          auto_renew: boolean | null
          created_at: string | null
          default_study_mode: string | null
          email_verification_token: string | null
          email_verification_token_expires_at: string | null
          email_verified: boolean | null
          first_name: string | null
          has_used_premium_trial: boolean | null
          id: string
          interests: string[] | null
          is_admin: boolean | null
          language_preference: string | null
          last_name: string | null
          onboarding_status: string | null
          phone_country_code: string | null
          phone_number: string | null
          phone_verified: boolean | null
          premium_trial_end_at: string | null
          premium_trial_started_at: string | null
          profile_image_url: string | null
          profile_picture: string | null
          razorpay_customer_id: string | null
          subscription_ends_at: string | null
          subscription_started_at: string | null
          subscription_status: string | null
          theme_preference: string | null
          updated_at: string | null
        }
        Insert: {
          age_group?: string | null
          auto_renew?: boolean | null
          created_at?: string | null
          default_study_mode?: string | null
          email_verification_token?: string | null
          email_verification_token_expires_at?: string | null
          email_verified?: boolean | null
          first_name?: string | null
          has_used_premium_trial?: boolean | null
          id: string
          interests?: string[] | null
          is_admin?: boolean | null
          language_preference?: string | null
          last_name?: string | null
          onboarding_status?: string | null
          phone_country_code?: string | null
          phone_number?: string | null
          phone_verified?: boolean | null
          premium_trial_end_at?: string | null
          premium_trial_started_at?: string | null
          profile_image_url?: string | null
          profile_picture?: string | null
          razorpay_customer_id?: string | null
          subscription_ends_at?: string | null
          subscription_started_at?: string | null
          subscription_status?: string | null
          theme_preference?: string | null
          updated_at?: string | null
        }
        Update: {
          age_group?: string | null
          auto_renew?: boolean | null
          created_at?: string | null
          default_study_mode?: string | null
          email_verification_token?: string | null
          email_verification_token_expires_at?: string | null
          email_verified?: boolean | null
          first_name?: string | null
          has_used_premium_trial?: boolean | null
          id?: string
          interests?: string[] | null
          is_admin?: boolean | null
          language_preference?: string | null
          last_name?: string | null
          onboarding_status?: string | null
          phone_country_code?: string | null
          phone_number?: string | null
          phone_verified?: boolean | null
          premium_trial_end_at?: string | null
          premium_trial_started_at?: string | null
          profile_image_url?: string | null
          profile_picture?: string | null
          razorpay_customer_id?: string | null
          subscription_ends_at?: string | null
          subscription_started_at?: string | null
          subscription_status?: string | null
          theme_preference?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      user_study_guides: {
        Row: {
          completed_at: string | null
          created_at: string | null
          id: string
          is_saved: boolean | null
          personal_notes: string | null
          scrolled_to_bottom: boolean | null
          study_guide_id: string
          time_spent_seconds: number | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          created_at?: string | null
          id?: string
          is_saved?: boolean | null
          personal_notes?: string | null
          scrolled_to_bottom?: boolean | null
          study_guide_id: string
          time_spent_seconds?: number | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          created_at?: string | null
          id?: string
          is_saved?: boolean | null
          personal_notes?: string | null
          scrolled_to_bottom?: boolean | null
          study_guide_id?: string
          time_spent_seconds?: number | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_study_guides_new_study_guide_id_fkey"
            columns: ["study_guide_id"]
            isOneToOne: false
            referencedRelation: "study_guides"
            referencedColumns: ["id"]
          },
        ]
      }
      user_study_streaks: {
        Row: {
          achievement_xp: number
          created_at: string
          current_streak: number
          id: string
          last_study_date: string | null
          longest_streak: number
          total_study_days: number
          updated_at: string
          user_id: string
        }
        Insert: {
          achievement_xp?: number
          created_at?: string
          current_streak?: number
          id?: string
          last_study_date?: string | null
          longest_streak?: number
          total_study_days?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          achievement_xp?: number
          created_at?: string
          current_streak?: number
          id?: string
          last_study_date?: string | null
          longest_streak?: number
          total_study_days?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      user_tokens: {
        Row: {
          available_tokens: number
          created_at: string | null
          daily_limit: number
          id: string
          identifier: string
          last_reset: string
          purchased_tokens: number
          total_consumed_today: number
          updated_at: string | null
          user_plan: string
        }
        Insert: {
          available_tokens?: number
          created_at?: string | null
          daily_limit: number
          id?: string
          identifier: string
          last_reset?: string
          purchased_tokens?: number
          total_consumed_today?: number
          updated_at?: string | null
          user_plan: string
        }
        Update: {
          available_tokens?: number
          created_at?: string | null
          daily_limit?: number
          id?: string
          identifier?: string
          last_reset?: string
          purchased_tokens?: number
          total_consumed_today?: number
          updated_at?: string | null
          user_plan?: string
        }
        Relationships: []
      }
      user_topic_progress: {
        Row: {
          completed_at: string | null
          created_at: string | null
          id: string
          started_at: string | null
          time_spent_seconds: number | null
          topic_id: string
          updated_at: string | null
          user_id: string
          xp_earned: number | null
        }
        Insert: {
          completed_at?: string | null
          created_at?: string | null
          id?: string
          started_at?: string | null
          time_spent_seconds?: number | null
          topic_id: string
          updated_at?: string | null
          user_id: string
          xp_earned?: number | null
        }
        Update: {
          completed_at?: string | null
          created_at?: string | null
          id?: string
          started_at?: string | null
          time_spent_seconds?: number | null
          topic_id?: string
          updated_at?: string | null
          user_id?: string
          xp_earned?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "user_topic_progress_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_topic_progress_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "trending_topics_view"
            referencedColumns: ["id"]
          },
        ]
      }
      voice_conversation_messages: {
        Row: {
          audio_duration_seconds: number | null
          audio_url: string | null
          book_names_corrected: boolean | null
          content_language: string
          content_text: string
          conversation_id: string
          corrections_made: Json | null
          created_at: string | null
          id: string
          llm_model_used: string | null
          llm_tokens_used: number | null
          message_order: number
          role: string
          scripture_references: string[] | null
          transcription_confidence: number | null
          user_id: string
        }
        Insert: {
          audio_duration_seconds?: number | null
          audio_url?: string | null
          book_names_corrected?: boolean | null
          content_language?: string
          content_text: string
          conversation_id: string
          corrections_made?: Json | null
          created_at?: string | null
          id?: string
          llm_model_used?: string | null
          llm_tokens_used?: number | null
          message_order: number
          role: string
          scripture_references?: string[] | null
          transcription_confidence?: number | null
          user_id: string
        }
        Update: {
          audio_duration_seconds?: number | null
          audio_url?: string | null
          book_names_corrected?: boolean | null
          content_language?: string
          content_text?: string
          conversation_id?: string
          corrections_made?: Json | null
          created_at?: string | null
          id?: string
          llm_model_used?: string | null
          llm_tokens_used?: number | null
          message_order?: number
          role?: string
          scripture_references?: string[] | null
          transcription_confidence?: number | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "voice_conversation_messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "voice_conversations"
            referencedColumns: ["id"]
          },
        ]
      }
      voice_conversations: {
        Row: {
          conversation_type: string
          created_at: string | null
          ended_at: string | null
          feedback_text: string | null
          id: string
          language_code: string
          rating: number | null
          related_scripture: string | null
          related_study_guide_id: string | null
          session_id: string
          started_at: string | null
          status: string
          total_duration_seconds: number | null
          total_messages: number | null
          updated_at: string | null
          user_id: string
          user_rating: number | null
          was_helpful: boolean | null
        }
        Insert: {
          conversation_type?: string
          created_at?: string | null
          ended_at?: string | null
          feedback_text?: string | null
          id?: string
          language_code?: string
          rating?: number | null
          related_scripture?: string | null
          related_study_guide_id?: string | null
          session_id: string
          started_at?: string | null
          status?: string
          total_duration_seconds?: number | null
          total_messages?: number | null
          updated_at?: string | null
          user_id: string
          user_rating?: number | null
          was_helpful?: boolean | null
        }
        Update: {
          conversation_type?: string
          created_at?: string | null
          ended_at?: string | null
          feedback_text?: string | null
          id?: string
          language_code?: string
          rating?: number | null
          related_scripture?: string | null
          related_study_guide_id?: string | null
          session_id?: string
          started_at?: string | null
          status?: string
          total_duration_seconds?: number | null
          total_messages?: number | null
          updated_at?: string | null
          user_id?: string
          user_rating?: number | null
          was_helpful?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "voice_conversations_related_study_guide_id_fkey"
            columns: ["related_study_guide_id"]
            isOneToOne: false
            referencedRelation: "study_guides"
            referencedColumns: ["id"]
          },
        ]
      }
      voice_preferences: {
        Row: {
          auto_detect_language: boolean | null
          auto_play_response: boolean | null
          cite_scripture_references: boolean | null
          continuous_mode: boolean | null
          created_at: string | null
          id: string
          notify_daily_quota_reached: boolean | null
          pitch: number | null
          preferred_language: string
          show_transcription: boolean | null
          speaking_rate: number | null
          tts_voice_gender: string | null
          updated_at: string | null
          use_study_context: boolean | null
          user_id: string
        }
        Insert: {
          auto_detect_language?: boolean | null
          auto_play_response?: boolean | null
          cite_scripture_references?: boolean | null
          continuous_mode?: boolean | null
          created_at?: string | null
          id?: string
          notify_daily_quota_reached?: boolean | null
          pitch?: number | null
          preferred_language?: string
          show_transcription?: boolean | null
          speaking_rate?: number | null
          tts_voice_gender?: string | null
          updated_at?: string | null
          use_study_context?: boolean | null
          user_id: string
        }
        Update: {
          auto_detect_language?: boolean | null
          auto_play_response?: boolean | null
          cite_scripture_references?: boolean | null
          continuous_mode?: boolean | null
          created_at?: string | null
          id?: string
          notify_daily_quota_reached?: boolean | null
          pitch?: number | null
          preferred_language?: string
          show_transcription?: boolean | null
          speaking_rate?: number | null
          tts_voice_gender?: string | null
          updated_at?: string | null
          use_study_context?: boolean | null
          user_id?: string
        }
        Relationships: []
      }
      voice_usage_tracking: {
        Row: {
          conversations_completed: number | null
          conversations_started: number | null
          created_at: string | null
          daily_quota_limit: number | null
          daily_quota_used: number | null
          id: string
          language_usage: Json | null
          quota_exceeded: boolean | null
          tier_at_time: string
          total_audio_seconds: number | null
          total_conversation_seconds: number | null
          total_messages_received: number | null
          total_messages_sent: number | null
          updated_at: string | null
          usage_date: string
          user_id: string
        }
        Insert: {
          conversations_completed?: number | null
          conversations_started?: number | null
          created_at?: string | null
          daily_quota_limit?: number | null
          daily_quota_used?: number | null
          id?: string
          language_usage?: Json | null
          quota_exceeded?: boolean | null
          tier_at_time: string
          total_audio_seconds?: number | null
          total_conversation_seconds?: number | null
          total_messages_received?: number | null
          total_messages_sent?: number | null
          updated_at?: string | null
          usage_date?: string
          user_id: string
        }
        Update: {
          conversations_completed?: number | null
          conversations_started?: number | null
          created_at?: string | null
          daily_quota_limit?: number | null
          daily_quota_used?: number | null
          id?: string
          language_usage?: Json | null
          quota_exceeded?: boolean | null
          tier_at_time?: string
          total_audio_seconds?: number | null
          total_conversation_seconds?: number | null
          total_messages_received?: number | null
          total_messages_sent?: number | null
          updated_at?: string | null
          usage_date?: string
          user_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      trending_topics_view: {
        Row: {
          category: string | null
          description: string | null
          id: string | null
          popularity_score: number | null
          tags: string[] | null
          title: string | null
          total_completions: number | null
          total_saves: number | null
          total_studies: number | null
        }
        Relationships: []
      }
    }
    Functions: {
      add_purchased_tokens: {
        Args: {
          p_identifier: string
          p_token_amount: number
          p_user_plan: string
        }
        Returns: {
          error_message: string
          new_purchased_balance: number
          success: boolean
        }[]
      }
      calculate_comprehensive_mastery: {
        Args: { verse_id_param: string }
        Returns: boolean
      }
      can_start_premium_trial: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      check_memory_achievements: {
        Args: { p_user_id: string }
        Returns: {
          out_achievement_id: string
          out_achievement_name: string
          out_is_new: boolean
          out_xp_reward: number
        }[]
      }
      check_saved_achievements: {
        Args: { p_user_id: string }
        Returns: {
          achievement_id: string
          achievement_name: string
          is_new: boolean
          xp_reward: number
        }[]
      }
      check_streak_achievements: {
        Args: { p_user_id: string }
        Returns: {
          achievement_id: string
          achievement_name: string
          is_new: boolean
          xp_reward: number
        }[]
      }
      check_streak_milestones: {
        Args: { p_user_id: string }
        Returns: {
          days_until_next: number
          milestone_10_reached: boolean
          milestone_100_reached: boolean
          milestone_30_reached: boolean
          milestone_365_reached: boolean
          next_milestone: number
        }[]
      }
      check_study_achievements: {
        Args: { p_user_id: string }
        Returns: {
          achievement_id: string
          achievement_name: string
          is_new: boolean
          xp_reward: number
        }[]
      }
      check_voice_achievements: {
        Args: { p_user_id: string }
        Returns: {
          achievement_id: string
          achievement_name: string
          is_new: boolean
          xp_reward: number
        }[]
      }
      check_voice_quota: {
        Args: Record<PropertyKey, never> | { p_tier: string; p_user_id: string }
        Returns: Json
      }
      claim_challenge_reward: {
        Args: { p_challenge_id: string; p_user_id: string }
        Returns: {
          message: string
          success: boolean
          xp_awarded: number
        }[]
      }
      cleanup_expired_daily_verses: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      cleanup_expired_otp_requests: {
        Args: Record<PropertyKey, never>
        Returns: undefined
      }
      cleanup_expired_pending_purchases: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      cleanup_old_rate_limit_records: {
        Args: Record<PropertyKey, never>
        Returns: undefined
      }
      complete_topic_progress: {
        Args: {
          p_time_spent_seconds?: number
          p_topic_id: string
          p_user_id: string
        }
        Returns: {
          is_first_completion: boolean
          progress_id: string
          topic_title: string
          xp_earned: number
        }[]
      }
      complete_voice_conversation: {
        Args: {
          p_conversation_id: string
          p_feedback_text?: string
          p_rating?: number
          p_was_helpful?: boolean
        }
        Returns: undefined
      }
      compute_learning_path_total_xp: {
        Args: { p_path_id: string }
        Returns: number
      }
      consume_user_tokens: {
        Args: {
          p_identifier: string
          p_token_cost: number
          p_user_plan: string
        }
        Returns: {
          available_tokens: number
          daily_limit: number
          error_message: string
          purchased_tokens: number
          success: boolean
        }[]
      }
      create_otp_request: {
        Args: { user_ip_address?: unknown; user_phone_number: string }
        Returns: Json
      }
      create_weekly_memory_challenges: {
        Args: Record<PropertyKey, never>
        Returns: undefined
      }
      decrypt_payment_token: {
        Args: { p_encrypted_token: string; p_key_id?: string }
        Returns: string
      }
      delete_payment_method: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: boolean
      }
      encrypt_payment_token: {
        Args: { p_key_id?: string; p_token: string }
        Returns: string
      }
      enroll_in_learning_path: {
        Args: { p_learning_path_id: string; p_user_id: string }
        Returns: {
          completed_at: string | null
          created_at: string | null
          current_topic_position: number | null
          enrolled_at: string | null
          id: string
          last_activity_at: string | null
          learning_path_id: string
          started_at: string | null
          topics_completed: number | null
          total_xp_earned: number | null
          updated_at: string | null
          user_id: string
        }
      }
      finalize_migration: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      generate_input_hash: {
        Args: { input_value: string }
        Returns: string
      }
      generate_invoice_number: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      generate_receipt_number: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      generate_token_hash: {
        Args: { p_token: string }
        Returns: string
      }
      get_all_token_pricing_packages: {
        Args: Record<PropertyKey, never>
        Returns: {
          base_price_rupees: number
          discount_percentage: number
          discounted_price_rupees: number
          is_popular: boolean
          token_amount: number
        }[]
      }
      get_available_learning_paths: {
        Args: {
          p_include_enrolled?: boolean
          p_language?: string
          p_user_id?: string
        }
        Returns: {
          color: string
          description: string
          disciple_level: string
          estimated_days: number
          icon_name: string
          is_enrolled: boolean
          is_featured: boolean
          path_id: string
          progress_percentage: number
          slug: string
          title: string
          topics_count: number
          total_xp: number
        }[]
      }
      get_daily_verse_notification_users: {
        Args: { offset_max: number; offset_min: number }
        Returns: {
          fcm_token: string
          platform: string
          timezone_offset_minutes: number
          user_id: string
        }[]
      }
      get_days_until_trial_end: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      get_grace_days_remaining: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      get_grace_period_end_date: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      get_in_progress_topics: {
        Args: { p_limit?: number; p_user_id: string }
        Returns: {
          learning_path_id: string
          learning_path_name: string
          position_in_path: number
          started_at: string
          time_spent_seconds: number
          topic_category: string
          topic_description: string
          topic_id: string
          topic_title: string
          topics_completed_in_path: number
          total_topics_in_path: number
          xp_value: number
        }[]
      }
      get_leaderboard: {
        Args: { limit_count?: number }
        Returns: {
          display_name: string
          rank: number
          total_xp: number
          user_id: string
        }[]
      }
      get_learning_path_details: {
        Args: { p_language?: string; p_path_id: string; p_user_id?: string }
        Returns: {
          color: string
          description: string
          disciple_level: string
          enrolled_at: string
          estimated_days: number
          icon_name: string
          is_enrolled: boolean
          path_id: string
          progress_percentage: number
          slug: string
          title: string
          topics: Json
          topics_completed: number
          total_xp: number
        }[]
      }
      get_memory_verse_reminder_notification_users: {
        Args: { target_hour: number; target_minute: number }
        Returns: {
          due_verse_count: number
          fcm_token: string
          platform: string
          timezone_offset_minutes: number
          user_id: string
        }[]
      }
      get_next_topic_in_learning_path: {
        Args: {
          p_language?: string
          p_learning_path_id: string
          p_user_id: string
        }
        Returns: {
          category: string
          description: string
          is_completed: boolean
          is_in_progress: boolean
          title: string
          topic_id: string
          topic_position: number
          total_topics: number
          xp_value: number
        }[]
      }
      get_or_create_memory_streak: {
        Args: { p_user_id: string }
        Returns: {
          created_at: string
          current_streak: number
          freeze_days_available: number
          freeze_days_used: number
          last_practice_date: string
          longest_streak: number
          milestone_10_date: string
          milestone_100_date: string
          milestone_30_date: string
          milestone_365_date: string
          total_practice_days: number
          updated_at: string
          user_id: string
        }[]
      }
      get_or_create_payment_preferences: {
        Args: Record<PropertyKey, never> | { p_user_id?: string }
        Returns: {
          auto_save_methods: boolean | null
          created_at: string | null
          default_payment_type: string | null
          enable_one_click_purchase: boolean | null
          enable_upi_autopay: boolean | null
          id: string
          prefer_mobile_wallets: boolean | null
          preferred_method_type: string | null
          preferred_wallet: string | null
          require_cvv_for_saved_cards: boolean | null
          updated_at: string | null
          user_id: string | null
        }
      }
      get_or_create_rate_limit_usage: {
        Args: {
          p_identifier: string
          p_user_type: string
          p_window_start: string
        }
        Returns: {
          count: number
          id: string
          identifier: string
          last_activity: string
          user_type: string
          window_start: string
        }[]
      }
      get_or_create_study_streak: {
        Args: { p_user_id: string }
        Returns: {
          created_at: string
          current_streak: number
          last_study_date: string
          longest_streak: number
          streak_id: string
          streak_user_id: string
          total_study_days: number
          updated_at: string
        }[]
      }
      get_or_create_user_streak: {
        Args: { p_user_id: string }
        Returns: {
          created_at: string
          current_streak: number
          id: number
          last_viewed_at: string
          longest_streak: number
          total_views: number
          updated_at: string
          user_id: string
        }[]
      }
      get_or_create_user_tokens: {
        Args: { p_identifier: string; p_user_plan: string }
        Returns: {
          available_tokens: number
          daily_limit: number
          id: string
          identifier: string
          last_reset: string
          purchased_tokens: number
          total_consumed_today: number
          user_plan: string
        }[]
      }
      get_payment_method_recommendations: {
        Args: { p_transaction_type?: string; p_user_id?: string }
        Returns: {
          display_name: string
          method_type: string
          payment_method_id: string
          provider: string
          recommendation_reason: string
          recommendation_score: number
        }[]
      }
      get_payment_method_token: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: string
      }
      get_payment_method_usage_analytics: {
        Args: { p_days_back?: number; p_user_id?: string }
        Returns: {
          display_name: string
          last_used_at: string
          method_type: string
          payment_method_id: string
          preferred_transaction_types: Json
          provider: string
          total_transaction_amount: number
          total_usage_count: number
          usage_frequency_score: number
        }[]
      }
      get_payment_preferences_for_user: {
        Args: { p_user_id?: string }
        Returns: {
          auto_save_payment_methods: boolean
          created_at: string
          default_payment_type: string
          enable_one_click_purchase: boolean
          id: string
          preferred_wallet: string
          updated_at: string
          user_id: string
        }[]
      }
      get_pending_purchase: {
        Args: { p_order_id: string }
        Returns: {
          amount_paise: number
          created_at: string
          error_message: string
          expires_at: string
          id: string
          order_id: string
          payment_id: string
          status: string
          token_amount: number
          updated_at: string
          user_id: string
        }[]
      }
      get_premium_trial_status: {
        Args: { p_user_id: string }
        Returns: Json
      }
      get_recommended_topic_notification_users: {
        Args: { offset_max: number; offset_min: number }
        Returns: {
          fcm_token: string
          platform: string
          timezone_offset_minutes: number
          user_id: string
        }[]
      }
      get_recommended_topics: {
        Args: {
          p_category?: string
          p_difficulty?: string
          p_limit?: number
          p_offset?: number
        }
        Returns: {
          category: string
          created_at: string
          description: string
          display_order: number
          id: string
          tags: string[]
          title: string
        }[]
      }
      get_recommended_topics_by_categories: {
        Args: { p_categories: string[]; p_limit?: number; p_offset?: number }
        Returns: {
          category: string
          created_at: string
          description: string
          display_order: number
          id: string
          tags: string[]
          title: string
        }[]
      }
      get_recommended_topics_categories: {
        Args: Record<PropertyKey, never>
        Returns: {
          category: string
        }[]
      }
      get_recommended_topics_count: {
        Args: { p_category?: string }
        Returns: number
      }
      get_recommended_topics_count_by_categories: {
        Args: { p_categories: string[] }
        Returns: number
      }
      get_scripture_suggestions: {
        Args: { p_limit?: number; p_query: string }
        Returns: {
          book_abbrev: string
          book_name: string
          testament: string
          topic_count: number
        }[]
      }
      get_standard_trial_end_date: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      get_streak_reminder_notification_users: {
        Args: { target_hour: number; target_minute: number }
        Returns: {
          current_streak: number
          fcm_token: string
          platform: string
          timezone_offset_minutes: number
          user_id: string
        }[]
      }
      get_subscription_status: {
        Args: { p_user_id: string }
        Returns: Json
      }
      get_token_price: {
        Args: { p_token_amount: number }
        Returns: {
          base_price: number
          discount_percentage: number
          discounted_price: number
        }[]
      }
      get_user_achievements: {
        Args: { p_language?: string; p_user_id: string }
        Returns: {
          achievement_id: string
          category: string
          description: string
          icon: string
          is_unlocked: boolean
          name: string
          threshold: number
          unlocked_at: string
          xp_reward: number
        }[]
      }
      get_user_completed_topics_by_category: {
        Args: { p_user_id: string }
        Returns: {
          category: string
          completed_count: number
          total_count: number
        }[]
      }
      get_user_created_at: {
        Args: { p_user_id: string }
        Returns: string
      }
      get_user_due_verses_count: {
        Args: { p_user_id: string }
        Returns: number
      }
      get_user_gamification_stats: {
        Args: { p_user_id: string }
        Returns: {
          achievements_total: number
          achievements_unlocked: number
          leaderboard_rank: number
          study_current_streak: number
          study_last_date: string
          study_longest_streak: number
          total_memory_verses: number
          total_saved_guides: number
          total_studies_completed: number
          total_study_days: number
          total_time_spent_seconds: number
          total_voice_sessions: number
          total_xp: number
          verse_current_streak: number
          verse_longest_streak: number
        }[]
      }
      get_user_learning_paths: {
        Args: { p_language?: string; p_user_id: string }
        Returns: {
          color: string
          completed_at: string
          current_topic_position: number
          description: string
          disciple_level: string
          enrolled_at: string
          estimated_days: number
          icon_name: string
          is_featured: boolean
          path_id: string
          progress_percentage: number
          slug: string
          started_at: string
          title: string
          topics_completed: number
          topics_count: number
          total_xp: number
        }[]
      }
      get_user_memory_verses_count: {
        Args: { p_user_id: string }
        Returns: number
      }
      get_user_onboarding_status: {
        Args: { user_id: string }
        Returns: string
      }
      get_user_payment_methods: {
        Args: { p_user_id?: string }
        Returns: {
          brand: string
          created_at: string
          display_name: string
          expiry_month: number
          expiry_year: number
          id: string
          is_default: boolean
          is_expired: boolean
          last_four: string
          last_used: string
          method_type: string
          provider: string
          usage_count: number
        }[]
      }
      get_user_plan_with_subscription: {
        Args: { p_user_id: string }
        Returns: string
      }
      get_user_purchase_history: {
        Args: { p_limit?: number; p_offset?: number; p_user_id: string }
        Returns: {
          cost_rupees: number
          id: string
          order_id: string
          payment_id: string
          payment_method: string
          purchased_at: string
          receipt_number: string
          status: string
          token_amount: number
        }[]
      }
      get_user_purchase_stats: {
        Args: { p_user_id: string }
        Returns: {
          average_purchase: number
          last_purchase_date: string
          most_used_payment_method: string
          total_purchases: number
          total_spent: number
          total_tokens: number
        }[]
      }
      get_user_reviews_today_count: {
        Args: { p_user_id: string }
        Returns: number
      }
      get_user_subscription_tier: {
        Args: { p_user_id: string }
        Returns: string
      }
      get_user_topic_progress: {
        Args: { p_topic_ids?: string[]; p_user_id: string }
        Returns: {
          completed_at: string
          is_completed: boolean
          started_at: string
          time_spent_seconds: number
          topic_id: string
          xp_earned: number
        }[]
      }
      get_user_xp_rank: {
        Args: { p_user_id: string }
        Returns: {
          rank: number
          total_xp: number
        }[]
      }
      get_valid_payment_methods: {
        Args: { p_user_id?: string }
        Returns: {
          brand: string
          created_at: string
          display_name: string
          expiry_month: number
          expiry_year: number
          id: string
          is_active: boolean
          is_default: boolean
          is_expired: boolean
          last_four: string
          last_used_at: string
          method_type: string
          provider: string
          token: string
        }[]
      }
      get_voice_conversation_history: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: Json
      }
      get_voice_preferences: {
        Args: Record<PropertyKey, never> | { p_user_id: string }
        Returns: Json
      }
      has_active_subscription: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      increment_rate_limit_usage: {
        Args: {
          p_identifier: string
          p_user_type: string
          p_window_start: string
        }
        Returns: number
      }
      increment_topic_engagement: {
        Args: { p_metric_type?: string; p_topic_id: string }
        Returns: undefined
      }
      increment_voice_usage: {
        Args:
          | Record<PropertyKey, never>
          | { p_language: string; p_tier: string; p_user_id: string }
        Returns: undefined
      }
      is_admin: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      is_in_grace_period: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      is_in_premium_trial: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      is_standard_trial_active: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      log_subscription_event: {
        Args: {
          p_event_data?: Json
          p_event_type: string
          p_new_status: string
          p_notes?: string
          p_payment_amount?: number
          p_payment_id?: string
          p_payment_status?: string
          p_previous_status: string
          p_subscription_id: string
          p_user_id: string
        }
        Returns: string
      }
      log_token_event: {
        Args: {
          p_event_data: Json
          p_event_type: string
          p_session_id?: string
          p_user_id: string
        }
        Returns: string
      }
      migrate_anonymous_data: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      migrate_authenticated_data: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      normalize_text_for_matching: {
        Args: { text_input: string }
        Returns: string
      }
      recalculate_learning_path_progress: {
        Args: { p_learning_path_id: string; p_user_id: string }
        Returns: undefined
      }
      record_payment_method_usage: {
        Args: {
          p_metadata?: Json
          p_method_id: string
          p_transaction_amount: number
          p_transaction_type: string
          p_user_id: string
        }
        Returns: boolean
      }
      record_purchase_history: {
        Args: {
          p_cost_paise: number
          p_cost_rupees: number
          p_order_id: string
          p_payment_id: string
          p_payment_method?: string
          p_status?: string
          p_token_amount: number
          p_user_id: string
        }
        Returns: string
      }
      rollback_migration: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      rotate_payment_method_encryption_key: {
        Args: { p_new_key_id: string; p_old_key_id: string }
        Returns: number
      }
      save_payment_method: {
        Args:
          | {
              p_brand?: string
              p_display_name?: string
              p_expiry_month?: number
              p_expiry_year?: number
              p_is_default?: boolean
              p_last_four?: string
              p_method_type: string
              p_provider: string
              p_token: string
              p_user_id: string
            }
          | {
              p_brand?: string
              p_display_name?: string
              p_expiry_month?: number
              p_expiry_year?: number
              p_is_default?: boolean
              p_last_four?: string
              p_method_type: string
              p_provider: string
              p_user_id: string
            }
        Returns: string
      }
      search_topics_by_scripture: {
        Args: {
          p_book_name?: string
          p_chapter?: number
          p_limit?: number
          p_search_query: string
          p_verse?: number
        }
        Returns: {
          book_name: string
          category: string
          chapter_start: number
          description: string
          is_primary_reference: boolean
          reference_text: string
          relevance_score: number
          tags: string[]
          title: string
          topic_id: string
          verse_start: number
        }[]
      }
      set_default_payment_method: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: boolean
      }
      start_premium_trial: {
        Args: { p_user_id: string }
        Returns: Json
      }
      start_topic_progress: {
        Args: { p_topic_id: string; p_user_id: string }
        Returns: {
          completed_at: string | null
          created_at: string | null
          id: string
          started_at: string | null
          time_spent_seconds: number | null
          topic_id: string
          updated_at: string | null
          user_id: string
          xp_earned: number | null
        }
      }
      store_pending_purchase: {
        Args: {
          p_amount_paise: number
          p_order_id: string
          p_status?: string
          p_token_amount: number
          p_user_id: string
        }
        Returns: string
      }
      test_token_rls_policies: {
        Args: Record<PropertyKey, never>
        Returns: {
          message: string
          result: boolean
          test_name: string
        }[]
      }
      update_challenge_progress: {
        Args: { p_increment?: number; p_target_type: string; p_user_id: string }
        Returns: {
          challenge_id: string
          is_newly_completed: boolean
          new_progress: number
          xp_reward: number
        }[]
      }
      update_memory_streak: {
        Args: { p_user_id: string }
        Returns: {
          current_streak: number
          is_new_record: boolean
          longest_streak: number
          milestone_reached: number
          streak_increased: boolean
        }[]
      }
      update_onboarding_status: {
        Args: { new_status: string; user_id: string }
        Returns: Json
      }
      update_payment_method_usage: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: boolean
      }
      update_payment_preferences: {
        Args:
          | {
              p_auto_save_methods?: boolean
              p_enable_one_click_purchase?: boolean
              p_enable_upi_autopay?: boolean
              p_prefer_mobile_wallets?: boolean
              p_preferred_method_type?: string
              p_require_cvv_for_saved_cards?: boolean
              p_user_id: string
            }
          | {
              p_auto_save_payment_methods?: boolean
              p_default_payment_type?: string
              p_enable_one_click_purchase?: boolean
              p_preferred_wallet?: string
              p_user_id: string
            }
        Returns: {
          auto_save_methods: boolean | null
          created_at: string | null
          default_payment_type: string | null
          enable_one_click_purchase: boolean | null
          enable_upi_autopay: boolean | null
          id: string
          prefer_mobile_wallets: boolean | null
          preferred_method_type: string | null
          preferred_wallet: string | null
          require_cvv_for_saved_cards: boolean | null
          updated_at: string | null
          user_id: string | null
        }
      }
      update_pending_purchase_status: {
        Args: {
          p_error_message?: string
          p_order_id: string
          p_payment_id?: string
          p_status: string
        }
        Returns: boolean
      }
      update_study_streak: {
        Args: { p_user_id: string }
        Returns: {
          current_streak: number
          is_new_record: boolean
          longest_streak: number
          streak_increased: boolean
        }[]
      }
      upsert_topic_time: {
        Args: {
          p_time_spent_seconds: number
          p_topic_id: string
          p_user_id: string
        }
        Returns: {
          id: string
          time_spent_seconds: number
          topic_id: string
          updated_at: string
        }[]
      }
      use_streak_freeze: {
        Args: { p_freeze_date: string; p_user_id: string }
        Returns: {
          freeze_days_remaining: number
          message: string
          success: boolean
        }[]
      }
      user_needs_standard_subscription: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      uuid_generate_v4: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      validate_payment_method_ownership: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: boolean
      }
      validate_sm2_quality_rating: {
        Args: { rating: number }
        Returns: boolean
      }
      validate_token_operation_context: {
        Args: Record<PropertyKey, never>
        Returns: boolean
      }
      verify_user_otp: {
        Args: { provided_otp_code: string; user_phone_number: string }
        Returns: Json
      }
      was_eligible_for_trial: {
        Args: { p_user_id: string }
        Returns: boolean
      }
    }
    Enums: {
      season_type:
        | "advent"
        | "christmas"
        | "lent"
        | "easter"
        | "pentecost"
        | "ordinary_time"
        | "new_year"
        | "thanksgiving"
        | "back_to_school"
        | "summer"
        | "fall"
        | "winter"
        | "spring"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      season_type: [
        "advent",
        "christmas",
        "lent",
        "easter",
        "pentecost",
        "ordinary_time",
        "new_year",
        "thanksgiving",
        "back_to_school",
        "summer",
        "fall",
        "winter",
        "spring",
      ],
    },
  },
} as const
