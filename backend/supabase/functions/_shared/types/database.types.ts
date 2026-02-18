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
      admin_logs: {
        Row: {
          action: string
          admin_user_id: string | null
          created_at: string | null
          details: Json | null
          id: string
          ip_address: unknown | null
          target_id: string | null
          target_table: string | null
          user_agent: string | null
        }
        Insert: {
          action: string
          admin_user_id?: string | null
          created_at?: string | null
          details?: Json | null
          id?: string
          ip_address?: unknown | null
          target_id?: string | null
          target_table?: string | null
          user_agent?: string | null
        }
        Update: {
          action?: string
          admin_user_id?: string | null
          created_at?: string | null
          details?: Json | null
          id?: string
          ip_address?: unknown | null
          target_id?: string | null
          target_table?: string | null
          user_agent?: string | null
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
      anonymous_sessions: {
        Row: {
          created_at: string | null
          device_fingerprint_hash: string | null
          expires_at: string | null
          ip_address_hash: string | null
          is_migrated: boolean | null
          last_activity: string | null
          recommended_guide_sessions_count: number | null
          session_id: string
          study_guides_count: number | null
        }
        Insert: {
          created_at?: string | null
          device_fingerprint_hash?: string | null
          expires_at?: string | null
          ip_address_hash?: string | null
          is_migrated?: boolean | null
          last_activity?: string | null
          recommended_guide_sessions_count?: number | null
          session_id?: string
          study_guides_count?: number | null
        }
        Update: {
          created_at?: string | null
          device_fingerprint_hash?: string | null
          expires_at?: string | null
          ip_address_hash?: string | null
          is_migrated?: boolean | null
          last_activity?: string | null
          recommended_guide_sessions_count?: number | null
          session_id?: string
          study_guides_count?: number | null
        }
        Relationships: []
      }
      anonymous_study_guides: {
        Row: {
          created_at: string | null
          expires_at: string | null
          id: string
          is_saved: boolean | null
          session_id: string
          study_guide_id: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          expires_at?: string | null
          id?: string
          is_saved?: boolean | null
          session_id: string
          study_guide_id: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          expires_at?: string | null
          id?: string
          is_saved?: boolean | null
          session_id?: string
          study_guide_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "anonymous_study_guides_study_guide_id_fkey"
            columns: ["study_guide_id"]
            isOneToOne: false
            referencedRelation: "study_guides"
            referencedColumns: ["id"]
          },
        ]
      }
      conversation_messages: {
        Row: {
          content: string
          conversation_id: string
          created_at: string | null
          id: string
          role: string
          tokens_consumed: number | null
        }
        Insert: {
          content: string
          conversation_id: string
          created_at?: string | null
          id?: string
          role: string
          tokens_consumed?: number | null
        }
        Update: {
          content?: string
          conversation_id?: string
          created_at?: string | null
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
      daily_unlocked_modes: {
        Row: {
          created_at: string
          id: string
          memory_verse_id: string
          practice_date: string
          tier_at_time: string
          unlocked_modes: string[]
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          memory_verse_id: string
          practice_date?: string
          tier_at_time: string
          unlocked_modes?: string[]
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          memory_verse_id?: string
          practice_date?: string
          tier_at_time?: string
          unlocked_modes?: string[]
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "daily_unlocked_modes_memory_verse_id_fkey"
            columns: ["memory_verse_id"]
            isOneToOne: false
            referencedRelation: "memory_verses"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_verses_cache: {
        Row: {
          created_at: string | null
          date_key: string
          expires_at: string
          id: number
          is_active: boolean | null
          updated_at: string | null
          uuid: string
          verse_data: Json
        }
        Insert: {
          created_at?: string | null
          date_key: string
          expires_at: string
          id?: number
          is_active?: boolean | null
          updated_at?: string | null
          uuid?: string
          verse_data: Json
        }
        Update: {
          created_at?: string | null
          date_key?: string
          expires_at?: string
          id?: number
          is_active?: boolean | null
          updated_at?: string | null
          uuid?: string
          verse_data?: Json
        }
        Relationships: []
      }
      feedback: {
        Row: {
          category: string | null
          context_id: string | null
          context_type: string | null
          created_at: string | null
          id: string
          message: string | null
          sentiment_score: number | null
          user_id: string | null
          was_helpful: boolean
        }
        Insert: {
          category?: string | null
          context_id?: string | null
          context_type?: string | null
          created_at?: string | null
          id?: string
          message?: string | null
          sentiment_score?: number | null
          user_id?: string | null
          was_helpful: boolean
        }
        Update: {
          category?: string | null
          context_id?: string | null
          context_type?: string | null
          created_at?: string | null
          id?: string
          message?: string | null
          sentiment_score?: number | null
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
          position: number
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
        ]
      }
      learning_path_translations: {
        Row: {
          created_at: string | null
          description: string
          id: string
          lang_code: string
          learning_path_id: string
          title: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description: string
          id?: string
          lang_code: string
          learning_path_id: string
          title: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string
          id?: string
          lang_code?: string
          learning_path_id?: string
          title?: string
          updated_at?: string | null
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
          difficulty_level: string | null
          disciple_level: string | null
          display_order: number | null
          estimated_days: number | null
          icon_name: string | null
          id: string
          is_active: boolean | null
          is_featured: boolean | null
          recommended_mode: string | null
          slug: string
          title: string
          total_xp: number | null
          updated_at: string | null
        }
        Insert: {
          color?: string | null
          created_at?: string | null
          description: string
          difficulty_level?: string | null
          disciple_level?: string | null
          display_order?: number | null
          estimated_days?: number | null
          icon_name?: string | null
          id?: string
          is_active?: boolean | null
          is_featured?: boolean | null
          recommended_mode?: string | null
          slug: string
          title: string
          total_xp?: number | null
          updated_at?: string | null
        }
        Update: {
          color?: string | null
          created_at?: string | null
          description?: string
          difficulty_level?: string | null
          disciple_level?: string | null
          display_order?: number | null
          estimated_days?: number | null
          icon_name?: string | null
          id?: string
          is_active?: boolean | null
          is_featured?: boolean | null
          recommended_mode?: string | null
          slug?: string
          title?: string
          total_xp?: number | null
          updated_at?: string | null
        }
        Relationships: []
      }
      llm_api_costs: {
        Row: {
          cost_usd: number | null
          created_at: string
          id: string
          input_tokens: number | null
          model: string
          operation_id: string | null
          output_tokens: number | null
          provider: string
          request_id: string | null
        }
        Insert: {
          cost_usd?: number | null
          created_at?: string
          id?: string
          input_tokens?: number | null
          model: string
          operation_id?: string | null
          output_tokens?: number | null
          provider: string
          request_id?: string | null
        }
        Update: {
          cost_usd?: number | null
          created_at?: string
          id?: string
          input_tokens?: number | null
          model?: string
          operation_id?: string | null
          output_tokens?: number | null
          provider?: string
          request_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "llm_api_costs_operation_id_fkey"
            columns: ["operation_id"]
            isOneToOne: false
            referencedRelation: "usage_logs"
            referencedColumns: ["id"]
          },
        ]
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
          language: string
          last_reviewed: string | null
          next_review_date: string
          repetitions: number
          source_id: string | null
          source_type: string
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
          language?: string
          last_reviewed?: string | null
          next_review_date?: string
          repetitions?: number
          source_id?: string | null
          source_type: string
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
          language?: string
          last_reviewed?: string | null
          next_review_date?: string
          repetitions?: number
          source_id?: string | null
          source_type?: string
          total_reviews?: number
          updated_at?: string
          user_id?: string
          verse_reference?: string
          verse_text?: string
        }
        Relationships: []
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
        Relationships: []
      }
      oauth_states: {
        Row: {
          created_at: string | null
          expires_at: string | null
          id: string
          ip_address: unknown | null
          provider: string | null
          state: string
          used: boolean | null
          used_at: string | null
          user_agent: string | null
          user_session_id: string | null
        }
        Insert: {
          created_at?: string | null
          expires_at?: string | null
          id?: string
          ip_address?: unknown | null
          provider?: string | null
          state: string
          used?: boolean | null
          used_at?: string | null
          user_agent?: string | null
          user_session_id?: string | null
        }
        Update: {
          created_at?: string | null
          expires_at?: string | null
          id?: string
          ip_address?: unknown | null
          provider?: string | null
          state?: string
          used?: boolean | null
          used_at?: string | null
          user_agent?: string | null
          user_session_id?: string | null
        }
        Relationships: []
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
      review_sessions: {
        Row: {
          id: string
          user_id: string
          memory_verse_id: string
          practice_mode: string
          review_date: string
          quality_rating: number
          confidence_rating: number | null
          accuracy_percentage: number | null
          hints_used: number | null
          new_ease_factor: number
          new_interval_days: number
          new_repetitions: number
          time_spent_seconds: number | null
          created_at: string
        }
        Insert: {
          id?: string
          user_id: string
          memory_verse_id: string
          practice_mode: string
          review_date?: string
          quality_rating: number
          confidence_rating?: number | null
          accuracy_percentage?: number | null
          hints_used?: number | null
          new_ease_factor: number
          new_interval_days: number
          new_repetitions: number
          time_spent_seconds?: number | null
          created_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          memory_verse_id?: string
          practice_mode?: string
          review_date?: string
          quality_rating?: number
          confidence_rating?: number | null
          accuracy_percentage?: number | null
          hints_used?: number | null
          new_ease_factor?: number
          new_interval_days?: number
          new_repetitions?: number
          time_spent_seconds?: number | null
          created_at?: string
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
      promotional_campaigns: {
        Row: {
          applicable_plans: string[]
          applicable_providers: string[]
          campaign_code: string
          campaign_name: string
          created_at: string | null
          current_use_count: number | null
          description: string | null
          discount_type: string
          discount_value: number
          id: string
          is_active: boolean | null
          max_total_uses: number | null
          max_uses_per_user: number | null
          new_users_only: boolean | null
          updated_at: string | null
          valid_from: string
          valid_until: string
        }
        Insert: {
          applicable_plans: string[]
          applicable_providers: string[]
          campaign_code: string
          campaign_name: string
          created_at?: string | null
          current_use_count?: number | null
          description?: string | null
          discount_type: string
          discount_value: number
          id?: string
          is_active?: boolean | null
          max_total_uses?: number | null
          max_uses_per_user?: number | null
          new_users_only?: boolean | null
          updated_at?: string | null
          valid_from: string
          valid_until: string
        }
        Update: {
          applicable_plans?: string[]
          applicable_providers?: string[]
          campaign_code?: string
          campaign_name?: string
          created_at?: string | null
          current_use_count?: number | null
          description?: string | null
          discount_type?: string
          discount_value?: number
          id?: string
          is_active?: boolean | null
          max_total_uses?: number | null
          max_uses_per_user?: number | null
          new_users_only?: boolean | null
          updated_at?: string | null
          valid_from?: string
          valid_until?: string
        }
        Relationships: []
      }
      promotional_redemptions: {
        Row: {
          campaign_id: string
          discount_amount_minor: number
          final_price_minor: number
          id: string
          original_price_minor: number
          plan_code: string
          provider: string
          redeemed_at: string | null
          subscription_id: string
          user_id: string
        }
        Insert: {
          campaign_id: string
          discount_amount_minor: number
          final_price_minor: number
          id?: string
          original_price_minor: number
          plan_code: string
          provider: string
          redeemed_at?: string | null
          subscription_id: string
          user_id: string
        }
        Update: {
          campaign_id?: string
          discount_amount_minor?: number
          final_price_minor?: number
          id?: string
          original_price_minor?: number
          plan_code?: string
          provider?: string
          redeemed_at?: string | null
          subscription_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "promotional_redemptions_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "promotional_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "promotional_redemptions_subscription_id_fkey"
            columns: ["subscription_id"]
            isOneToOne: false
            referencedRelation: "subscriptions"
            referencedColumns: ["id"]
          },
        ]
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
      rate_limit_rules: {
        Row: {
          created_at: string
          feature_name: string
          id: string
          is_active: boolean | null
          max_cost_per_day_usd: number | null
          max_requests_per_day: number | null
          max_requests_per_hour: number | null
          tier: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          feature_name: string
          id?: string
          is_active?: boolean | null
          max_cost_per_day_usd?: number | null
          max_requests_per_day?: number | null
          max_requests_per_hour?: number | null
          tier: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          feature_name?: string
          id?: string
          is_active?: boolean | null
          max_cost_per_day_usd?: number | null
          max_requests_per_day?: number | null
          max_requests_per_hour?: number | null
          tier?: string
          updated_at?: string
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
      recommended_guide_sessions: {
        Row: {
          completion_status: boolean | null
          created_at: string | null
          current_step: number | null
          id: string
          language: string | null
          step_1_completed_at: string | null
          step_1_context: string | null
          step_2_completed_at: string | null
          step_2_scholar_guide: string | null
          step_3_completed_at: string | null
          step_3_group_discussion: string | null
          step_4_application: string | null
          step_4_completed_at: string | null
          topic: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          completion_status?: boolean | null
          created_at?: string | null
          current_step?: number | null
          id?: string
          language?: string | null
          step_1_completed_at?: string | null
          step_1_context?: string | null
          step_2_completed_at?: string | null
          step_2_scholar_guide?: string | null
          step_3_completed_at?: string | null
          step_3_group_discussion?: string | null
          step_4_application?: string | null
          step_4_completed_at?: string | null
          topic: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          completion_status?: boolean | null
          created_at?: string | null
          current_step?: number | null
          id?: string
          language?: string | null
          step_1_completed_at?: string | null
          step_1_context?: string | null
          step_2_completed_at?: string | null
          step_2_scholar_guide?: string | null
          step_3_completed_at?: string | null
          step_3_group_discussion?: string | null
          step_4_application?: string | null
          step_4_completed_at?: string | null
          topic?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      recommended_topics: {
        Row: {
          category: string
          created_at: string | null
          description: string
          display_order: number | null
          id: string
          input_type: string | null
          is_active: boolean | null
          tags: string[] | null
          title: string
          updated_at: string | null
          xp_value: number | null
        }
        Insert: {
          category: string
          created_at?: string | null
          description: string
          display_order?: number | null
          id?: string
          input_type?: string | null
          is_active?: boolean | null
          tags?: string[] | null
          title: string
          updated_at?: string | null
          xp_value?: number | null
        }
        Update: {
          category?: string
          created_at?: string | null
          description?: string
          display_order?: number | null
          id?: string
          input_type?: string | null
          is_active?: boolean | null
          tags?: string[] | null
          title?: string
          updated_at?: string | null
          xp_value?: number | null
        }
        Relationships: []
      }
      recommended_topics_translations: {
        Row: {
          category: string
          created_at: string | null
          description: string
          id: string
          language_code: string
          title: string
          topic_id: string
          updated_at: string | null
        }
        Insert: {
          category: string
          created_at?: string | null
          description: string
          id?: string
          language_code: string
          title: string
          topic_id: string
          updated_at?: string | null
        }
        Update: {
          category?: string
          created_at?: string | null
          description?: string
          id?: string
          language_code?: string
          title?: string
          topic_id?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "recommended_topics_translations_topic_id_fkey"
            columns: ["topic_id"]
            isOneToOne: false
            referencedRelation: "recommended_topics"
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
          last_used: string | null
          method_type: string
          provider: string
          security_metadata: Json | null
          token_hash: string | null
          updated_at: string | null
          usage_count: number | null
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
          last_used?: string | null
          method_type: string
          provider: string
          security_metadata?: Json | null
          token_hash?: string | null
          updated_at?: string | null
          usage_count?: number | null
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
          last_used?: string | null
          method_type?: string
          provider?: string
          security_metadata?: Json | null
          token_hash?: string | null
          updated_at?: string | null
          usage_count?: number | null
          user_id?: string | null
        }
        Relationships: []
      }
      study_guide_conversations: {
        Row: {
          created_at: string | null
          id: string
          session_id: string | null
          study_guide_id: string
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          session_id?: string | null
          study_guide_id: string
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          session_id?: string | null
          study_guide_id?: string
          updated_at?: string | null
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
          created_at: string | null
          creator_session_id: string | null
          creator_user_id: string | null
          extended_content: Json | null
          id: string
          input_type: string
          input_value: string
          input_value_hash: string
          interpretation: string
          language: string
          prayer_points: string[]
          reflection_questions: string[]
          related_verses: string[]
          study_mode: string | null
          summary: string
          topic_id: string | null
          updated_at: string | null
        }
        Insert: {
          context: string
          created_at?: string | null
          creator_session_id?: string | null
          creator_user_id?: string | null
          extended_content?: Json | null
          id?: string
          input_type: string
          input_value: string
          input_value_hash: string
          interpretation: string
          language?: string
          prayer_points: string[]
          reflection_questions: string[]
          related_verses: string[]
          study_mode?: string | null
          summary: string
          topic_id?: string | null
          updated_at?: string | null
        }
        Update: {
          context?: string
          created_at?: string | null
          creator_session_id?: string | null
          creator_user_id?: string | null
          extended_content?: Json | null
          id?: string
          input_type?: string
          input_value?: string
          input_value_hash?: string
          interpretation?: string
          language?: string
          prayer_points?: string[]
          reflection_questions?: string[]
          related_verses?: string[]
          study_mode?: string | null
          summary?: string
          topic_id?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      subscription_history: {
        Row: {
          amount_paise: number | null
          created_at: string | null
          currency: string | null
          event_timestamp: string | null
          event_type: string
          id: string
          new_status: string | null
          notes: string | null
          old_status: string | null
          payment_id: string | null
          provider: string
          provider_data: Json | null
          provider_event_id: string | null
          subscription_id: string
          user_id: string
        }
        Insert: {
          amount_paise?: number | null
          created_at?: string | null
          currency?: string | null
          event_timestamp?: string | null
          event_type: string
          id?: string
          new_status?: string | null
          notes?: string | null
          old_status?: string | null
          payment_id?: string | null
          provider: string
          provider_data?: Json | null
          provider_event_id?: string | null
          subscription_id: string
          user_id: string
        }
        Update: {
          amount_paise?: number | null
          created_at?: string | null
          currency?: string | null
          event_timestamp?: string | null
          event_type?: string
          id?: string
          new_status?: string | null
          notes?: string | null
          old_status?: string | null
          payment_id?: string | null
          provider?: string
          provider_data?: Json | null
          provider_event_id?: string | null
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
          created_at: string | null
          currency: string
          due_date: string | null
          id: string
          invoice_number: string
          issued_at: string | null
          paid_at: string | null
          payment_method: string | null
          provider: string
          provider_data: Json | null
          provider_invoice_id: string | null
          provider_payment_id: string | null
          status: string
          subscription_id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          amount_paise: number
          billing_period_end: string
          billing_period_start: string
          created_at?: string | null
          currency?: string
          due_date?: string | null
          id?: string
          invoice_number: string
          issued_at?: string | null
          paid_at?: string | null
          payment_method?: string | null
          provider: string
          provider_data?: Json | null
          provider_invoice_id?: string | null
          provider_payment_id?: string | null
          status?: string
          subscription_id: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          amount_paise?: number
          billing_period_end?: string
          billing_period_start?: string
          created_at?: string | null
          currency?: string
          due_date?: string | null
          id?: string
          invoice_number?: string
          issued_at?: string | null
          paid_at?: string | null
          payment_method?: string | null
          provider?: string
          provider_data?: Json | null
          provider_invoice_id?: string | null
          provider_payment_id?: string | null
          status?: string
          subscription_id?: string
          updated_at?: string | null
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
      subscription_plan_providers: {
        Row: {
          base_price_minor: number
          created_at: string | null
          currency: string
          id: string
          is_active: boolean | null
          plan_id: string
          provider: string
          provider_metadata: Json | null
          provider_plan_id: string
          region: string | null
          updated_at: string | null
        }
        Insert: {
          base_price_minor: number
          created_at?: string | null
          currency?: string
          id?: string
          is_active?: boolean | null
          plan_id: string
          provider: string
          provider_metadata?: Json | null
          provider_plan_id: string
          region?: string | null
          updated_at?: string | null
        }
        Update: {
          base_price_minor?: number
          created_at?: string | null
          currency?: string
          id?: string
          is_active?: boolean | null
          plan_id?: string
          provider?: string
          provider_metadata?: Json | null
          provider_plan_id?: string
          region?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "subscription_plan_providers_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "subscription_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      subscription_plans: {
        Row: {
          created_at: string | null
          description: string | null
          features: Json
          id: string
          interval: string
          is_active: boolean | null
          is_visible: boolean | null
          plan_code: string
          plan_name: string
          sort_order: number | null
          tier: number
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          features?: Json
          id?: string
          interval: string
          is_active?: boolean | null
          is_visible?: boolean | null
          plan_code: string
          plan_name: string
          sort_order?: number | null
          tier: number
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          features?: Json
          id?: string
          interval?: string
          is_active?: boolean | null
          is_visible?: boolean | null
          plan_code?: string
          plan_name?: string
          sort_order?: number | null
          tier?: number
          updated_at?: string | null
        }
        Relationships: []
      }
      subscriptions: {
        Row: {
          amount_paise: number | null
          cancel_at_cycle_end: boolean | null
          cancellation_reason: string | null
          cancelled_at: string | null
          created_at: string | null
          currency: string | null
          current_period_end: string | null
          current_period_start: string | null
          discounted_price_minor: number | null
          id: string
          metadata: Json | null
          next_billing_at: string | null
          paid_count: number | null
          plan_id: string | null
          plan_type: string | null
          promotional_campaign_id: string | null
          provider: string | null
          provider_customer_id: string | null
          provider_metadata: Json | null
          provider_plan_id: string | null
          provider_subscription_id: string | null
          razorpay_customer_id: string | null
          razorpay_plan_id: string | null
          razorpay_subscription_id: string | null
          remaining_count: number | null
          status: string
          subscription_plan: string | null
          total_count: number | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          amount_paise?: number | null
          cancel_at_cycle_end?: boolean | null
          cancellation_reason?: string | null
          cancelled_at?: string | null
          created_at?: string | null
          currency?: string | null
          current_period_end?: string | null
          current_period_start?: string | null
          discounted_price_minor?: number | null
          id?: string
          metadata?: Json | null
          next_billing_at?: string | null
          paid_count?: number | null
          plan_id?: string | null
          plan_type?: string | null
          promotional_campaign_id?: string | null
          provider?: string | null
          provider_customer_id?: string | null
          provider_metadata?: Json | null
          provider_plan_id?: string | null
          provider_subscription_id?: string | null
          razorpay_customer_id?: string | null
          razorpay_plan_id?: string | null
          razorpay_subscription_id?: string | null
          remaining_count?: number | null
          status?: string
          subscription_plan?: string | null
          total_count?: number | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          amount_paise?: number | null
          cancel_at_cycle_end?: boolean | null
          cancellation_reason?: string | null
          cancelled_at?: string | null
          created_at?: string | null
          currency?: string | null
          current_period_end?: string | null
          current_period_start?: string | null
          discounted_price_minor?: number | null
          id?: string
          metadata?: Json | null
          next_billing_at?: string | null
          paid_count?: number | null
          plan_id?: string | null
          plan_type?: string | null
          promotional_campaign_id?: string | null
          provider?: string | null
          provider_customer_id?: string | null
          provider_metadata?: Json | null
          provider_plan_id?: string | null
          provider_subscription_id?: string | null
          razorpay_customer_id?: string | null
          razorpay_plan_id?: string | null
          razorpay_subscription_id?: string | null
          remaining_count?: number | null
          status?: string
          subscription_plan?: string | null
          total_count?: number | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "subscriptions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "subscription_plans"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "subscriptions_promotional_campaign_id_fkey"
            columns: ["promotional_campaign_id"]
            isOneToOne: false
            referencedRelation: "promotional_campaigns"
            referencedColumns: ["id"]
          },
        ]
      }
      system_config: {
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
      token_usage_history: {
        Row: {
          content_reference: string | null
          content_title: string | null
          created_at: string
          daily_tokens_used: number
          feature_name: string
          id: string
          input_type: string | null
          language: string
          operation_type: string
          purchased_tokens_used: number
          session_id: string | null
          study_mode: string | null
          token_cost: number
          user_id: string
          user_plan: string
        }
        Insert: {
          content_reference?: string | null
          content_title?: string | null
          created_at?: string
          daily_tokens_used?: number
          feature_name: string
          id?: string
          input_type?: string | null
          language?: string
          operation_type: string
          purchased_tokens_used?: number
          session_id?: string | null
          study_mode?: string | null
          token_cost: number
          user_id: string
          user_plan: string
        }
        Update: {
          content_reference?: string | null
          content_title?: string | null
          created_at?: string
          daily_tokens_used?: number
          feature_name?: string
          id?: string
          input_type?: string | null
          language?: string
          operation_type?: string
          purchased_tokens_used?: number
          session_id?: string | null
          study_mode?: string | null
          token_cost?: number
          user_id?: string
          user_plan?: string
        }
        Relationships: []
      }
      usage_alerts: {
        Row: {
          alert_type: string
          created_at: string
          id: string
          is_active: boolean | null
          notification_channel: string | null
          threshold_value: number | null
          updated_at: string
        }
        Insert: {
          alert_type: string
          created_at?: string
          id?: string
          is_active?: boolean | null
          notification_channel?: string | null
          threshold_value?: number | null
          updated_at?: string
        }
        Update: {
          alert_type?: string
          created_at?: string
          id?: string
          is_active?: boolean | null
          notification_channel?: string | null
          threshold_value?: number | null
          updated_at?: string
        }
        Relationships: []
      }
      usage_logs: {
        Row: {
          created_at: string
          estimated_revenue_inr: number | null
          feature_name: string
          id: string
          llm_cost_usd: number | null
          llm_input_tokens: number | null
          llm_model: string | null
          llm_output_tokens: number | null
          llm_provider: string | null
          operation_type: string
          profit_margin_inr: number | null
          request_metadata: Json | null
          response_metadata: Json | null
          session_id: string | null
          tier: string
          tokens_consumed: number | null
          user_id: string | null
        }
        Insert: {
          created_at?: string
          estimated_revenue_inr?: number | null
          feature_name: string
          id?: string
          llm_cost_usd?: number | null
          llm_input_tokens?: number | null
          llm_model?: string | null
          llm_output_tokens?: number | null
          llm_provider?: string | null
          operation_type: string
          profit_margin_inr?: number | null
          request_metadata?: Json | null
          response_metadata?: Json | null
          session_id?: string | null
          tier: string
          tokens_consumed?: number | null
          user_id?: string | null
        }
        Update: {
          created_at?: string
          estimated_revenue_inr?: number | null
          feature_name?: string
          id?: string
          llm_cost_usd?: number | null
          llm_input_tokens?: number | null
          llm_model?: string | null
          llm_output_tokens?: number | null
          llm_provider?: string | null
          operation_type?: string
          profit_margin_inr?: number | null
          request_metadata?: Json | null
          response_metadata?: Json | null
          session_id?: string | null
          tier?: string
          tokens_consumed?: number | null
          user_id?: string | null
        }
        Relationships: []
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
          current_topic_position: number | null
          enrolled_at: string | null
          id: string
          last_activity_at: string | null
          learning_path_id: string
          topics_completed: number | null
          total_xp_earned: number | null
          user_id: string
        }
        Insert: {
          completed_at?: string | null
          current_topic_position?: number | null
          enrolled_at?: string | null
          id?: string
          last_activity_at?: string | null
          learning_path_id: string
          topics_completed?: number | null
          total_xp_earned?: number | null
          user_id: string
        }
        Update: {
          completed_at?: string | null
          current_topic_position?: number | null
          enrolled_at?: string | null
          id?: string
          last_activity_at?: string | null
          learning_path_id?: string
          topics_completed?: number | null
          total_xp_earned?: number | null
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
          memory_verse_overdue_enabled: boolean
          memory_verse_reminder_enabled: boolean | null
          memory_verse_reminder_time: string
          recommended_topic_enabled: boolean | null
          streak_reminder_enabled: boolean | null
          timezone_offset_minutes: number | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string | null
          daily_verse_enabled?: boolean | null
          id?: string
          memory_verse_overdue_enabled?: boolean
          memory_verse_reminder_enabled?: boolean | null
          memory_verse_reminder_time?: string
          recommended_topic_enabled?: boolean | null
          streak_reminder_enabled?: boolean | null
          timezone_offset_minutes?: number | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string | null
          daily_verse_enabled?: boolean | null
          id?: string
          memory_verse_overdue_enabled?: boolean
          memory_verse_reminder_enabled?: boolean | null
          memory_verse_reminder_time?: string
          recommended_topic_enabled?: boolean | null
          streak_reminder_enabled?: boolean | null
          timezone_offset_minutes?: number | null
          updated_at?: string | null
          user_id?: string
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
          biggest_challenge: string | null
          created_at: string | null
          faith_stage: string | null
          id: string
          learning_style: string | null
          life_stage_focus: string | null
          questionnaire_completed: boolean | null
          questionnaire_skipped: boolean | null
          scoring_results: Json | null
          spiritual_goals: string[] | null
          time_availability: string | null
          updated_at: string | null
          user_id: string
        }
        Insert: {
          biggest_challenge?: string | null
          created_at?: string | null
          faith_stage?: string | null
          id?: string
          learning_style?: string | null
          life_stage_focus?: string | null
          questionnaire_completed?: boolean | null
          questionnaire_skipped?: boolean | null
          scoring_results?: Json | null
          spiritual_goals?: string[] | null
          time_availability?: string | null
          updated_at?: string | null
          user_id: string
        }
        Update: {
          biggest_challenge?: string | null
          created_at?: string | null
          faith_stage?: string | null
          id?: string
          learning_style?: string | null
          life_stage_focus?: string | null
          questionnaire_completed?: boolean | null
          questionnaire_skipped?: boolean | null
          scoring_results?: Json | null
          spiritual_goals?: string[] | null
          time_availability?: string | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: []
      }
      user_profiles: {
        Row: {
          age_group: string | null
          created_at: string | null
          first_name: string | null
          id: string
          interests: string[] | null
          is_admin: boolean | null
          language_preference: string | null
          last_name: string | null
          onboarding_status: string | null
          phone_country_code: string | null
          phone_number: string | null
          phone_verified: boolean | null
          profile_image_url: string | null
          profile_picture: string | null
          theme_preference: string | null
          updated_at: string | null
        }
        Insert: {
          age_group?: string | null
          created_at?: string | null
          first_name?: string | null
          id: string
          interests?: string[] | null
          is_admin?: boolean | null
          language_preference?: string | null
          last_name?: string | null
          onboarding_status?: string | null
          phone_country_code?: string | null
          phone_number?: string | null
          phone_verified?: boolean | null
          profile_image_url?: string | null
          profile_picture?: string | null
          theme_preference?: string | null
          updated_at?: string | null
        }
        Update: {
          age_group?: string | null
          created_at?: string | null
          first_name?: string | null
          id?: string
          interests?: string[] | null
          is_admin?: boolean | null
          language_preference?: string | null
          last_name?: string | null
          onboarding_status?: string | null
          phone_country_code?: string | null
          phone_number?: string | null
          phone_verified?: boolean | null
          profile_image_url?: string | null
          profile_picture?: string | null
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
          scrolled_to_bottom?: boolean | null
          study_guide_id?: string
          time_spent_seconds?: number | null
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_study_guides_study_guide_id_fkey"
            columns: ["study_guide_id"]
            isOneToOne: false
            referencedRelation: "study_guides"
            referencedColumns: ["id"]
          },
        ]
      }
      user_study_streaks: {
        Row: {
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
          month_year: string
          monthly_conversations_completed: number
          monthly_conversations_started: number
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
          month_year?: string
          monthly_conversations_completed?: number
          monthly_conversations_started?: number
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
          month_year?: string
          monthly_conversations_completed?: number
          monthly_conversations_started?: number
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
      [_ in never]: never
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
          new_balance: number
          success: boolean
        }[]
      }
      apply_promo_discount: {
        Args: {
          p_base_price_minor: number
          p_discount_type: string
          p_discount_value: number
        }
        Returns: number
      }
      calculate_comprehensive_mastery: {
        Args: { p_memory_verse_id: string }
        Returns: number
      }
      calculate_study_streak: {
        Args: { p_user_id: string }
        Returns: number
      }
      calculate_user_profitability: {
        Args: { p_user_id: string }
        Returns: Json
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
      check_mode_unlock_status: {
        Args: {
          p_memory_verse_id: string
          p_mode: string
          p_tier: string
          p_user_id: string
        }
        Returns: Json
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
        Args: Record<PropertyKey, never>
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
      cleanup_expired_oauth_states: {
        Args: Record<PropertyKey, never>
        Returns: undefined
      }
      cleanup_expired_otp_requests: {
        Args: Record<PropertyKey, never>
        Returns: undefined
      }
      cleanup_expired_pending_purchases: {
        Args: Record<PropertyKey, never>
        Returns: number
      }
      cleanup_old_unlocked_modes: {
        Args: Record<PropertyKey, never>
        Returns: number
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
          daily_tokens_used: number
          error_message: string
          purchased_tokens: number
          purchased_tokens_used: number
          success: boolean
        }[]
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
      detect_usage_anomalies: {
        Args: { p_threshold_multiplier?: number }
        Returns: {
          anomaly_factor: number
          avg_usage_count: number
          feature_name: string
          recent_usage_count: number
          tier: string
          user_id: string
        }[]
      }
      encrypt_payment_token: {
        Args: { p_key_id?: string; p_token: string }
        Returns: string
      }
      enroll_in_learning_path: {
        Args: { p_learning_path_id: string; p_user_id: string }
        Returns: string
      }
      generate_input_hash: {
        Args: { input_value: string }
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
      get_available_learning_paths: {
        Args: { p_language?: string; p_user_id?: string }
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
          recommended_mode: string
          slug: string
          title: string
          total_topics: number
          total_xp: number
        }[]
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
          recommended_mode: string
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
          overdue_verse_count: number
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
        Args: Record<PropertyKey, never>
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
      get_or_create_study_streak: {
        Args: { p_user_id: string }
        Returns: {
          created_at: string
          current_streak: number
          id: string
          last_study_date: string
          longest_streak: number
          total_study_days: number
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
      get_payment_method_token: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: string
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
      get_plan_with_pricing: {
        Args: { p_plan_code: string; p_provider?: string; p_region?: string }
        Returns: {
          base_price_minor: number
          currency: string
          features: Json
          plan_code: string
          plan_id: string
          plan_name: string
          provider: string
          provider_plan_id: string
          tier: number
        }[]
      }
      get_profitability_report: {
        Args: { p_feature_name: string; p_tier: string }
        Returns: Json
      }
      get_recommended_topics: {
        Args:
          | {
              p_category?: string
              p_difficulty_level?: string
              p_language_code?: string
              p_limit?: number
              p_offset?: number
            }
          | {
              p_category?: string
              p_language_code?: string
              p_limit?: number
              p_offset?: number
            }
        Returns: {
          category: string
          created_at: string
          description: string
          display_order: number
          id: string
          input_type: string
          tags: string[]
          title: string
          updated_at: string
        }[]
      }
      get_recommended_topics_categories: {
        Args: { p_language_code?: string }
        Returns: {
          category: string
          topic_count: number
        }[]
      }
      get_recommended_topics_count: {
        Args: { p_category?: string }
        Returns: number
      }
      get_usage_stats: {
        Args: {
          p_end_date: string
          p_feature_name?: string
          p_start_date: string
          p_tier?: string
        }
        Returns: Json
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
          description: string
          disciple_level: string
          enrolled_at: string
          estimated_days: number
          icon_name: string
          last_activity_at: string
          path_id: string
          progress_percentage: number
          recommended_mode: string
          slug: string
          title: string
          topics_completed: number
          total_topics: number
          total_xp: number
        }[]
      }
      get_user_memory_verses_count: {
        Args: { p_user_id: string }
        Returns: number
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
      get_user_token_usage_history: {
        Args: { p_limit?: number; p_offset?: number; p_user_id: string }
        Returns: {
          content_reference: string
          content_title: string
          created_at: string
          daily_tokens_used: number
          feature_name: string
          id: string
          input_type: string
          language: string
          operation_type: string
          purchased_tokens_used: number
          study_mode: string
          token_cost: number
          user_plan: string
        }[]
      }
      get_voice_conversation_history: {
        Args: { p_limit?: number; p_offset?: number }
        Returns: Json
      }
      get_voice_preferences: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      has_active_subscription: {
        Args: { p_user_id: string }
        Returns: boolean
      }
      log_usage: {
        Args: {
          p_feature_name: string
          p_llm_cost_usd?: number
          p_llm_input_tokens?: number
          p_llm_model?: string
          p_llm_output_tokens?: number
          p_llm_provider?: string
          p_operation_type: string
          p_request_metadata?: Json
          p_response_metadata?: Json
          p_tier: string
          p_tokens_consumed?: number
          p_user_id: string
        }
        Returns: string
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
      record_token_usage: {
        Args: {
          p_content_reference?: string
          p_content_title?: string
          p_daily_tokens_used?: number
          p_feature_name: string
          p_input_type?: string
          p_language?: string
          p_operation_type: string
          p_purchased_tokens_used?: number
          p_session_id?: string
          p_study_mode?: string
          p_token_cost: number
          p_user_id: string
          p_user_plan?: string
        }
        Returns: string
      }
      save_payment_method: {
        Args: {
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
        Returns: string
      }
      set_default_payment_method: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: boolean
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
      unlock_practice_mode: {
        Args: {
          p_memory_verse_id: string
          p_mode: string
          p_tier: string
          p_user_id: string
        }
        Returns: Json
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
      update_payment_method_usage: {
        Args: { p_method_id: string; p_user_id: string }
        Returns: boolean
      }
      update_payment_preferences: {
        Args: {
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
      uuid_generate_v4: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
      validate_promo_code: {
        Args: {
          p_campaign_code: string
          p_plan_code?: string
          p_user_id: string
        }
        Returns: {
          campaign_id: string
          discount_type: string
          discount_value: number
          message: string
          valid: boolean
        }[]
      }
      validate_sm2_quality_rating: {
        Args: { rating: number }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
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
    Enums: {},
  },
} as const

