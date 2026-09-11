/**
 * JSON Schema for Study Guide Structured Outputs
 *
 * This schema enforces that the LLM MUST generate all 15 required fields.
 * Uses OpenAI's Structured Outputs feature for 100% schema compliance.
 *
 * IMPORTANT: Every field that the prompt instructs the LLM to produce MUST be
 * declared here. OpenAI enforces strict: true + additionalProperties: false,
 * which silently strips any field absent from this schema — regardless of
 * what the prompt says. 'passage' was previously missing, causing it to be
 * dropped in production (OpenAI) while working locally (Anthropic, no schema).
 */

export const studyGuideSchema = {
  name: "study_guide",
  strict: true,
  schema: {
    type: "object",
    properties: {
      summary: {
        type: "string",
        description: "Brief overview of the study content"
      },
      interpretation: {
        type: "string",
        description: "Theological interpretation and explanation"
      },
      context: {
        type: "string",
        description: "Historical and cultural background"
      },
      passage: {
        type: "string",
        description: "Relevant Bible passage text for reading and meditation"
      },
      relatedVerses: {
        type: "array",
        description: "Relevant Bible verses",
        items: {
          type: "string"
        }
      },
      reflectionQuestions: {
        type: "array",
        description: "Practical application questions",
        items: {
          type: "string"
        }
      },
      prayerPoints: {
        type: "array",
        description: "Prayer suggestions",
        items: {
          type: "string"
        }
      },
    },
    required: [
      "summary",
      "interpretation",
      "context",
      "passage",
      "relatedVerses",
      "reflectionQuestions",
      "prayerPoints",
    ],
    additionalProperties: false
  }
} as const
