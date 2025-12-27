/**
 * JSON Schema for Study Guide Structured Outputs
 * 
 * This schema enforces that the LLM MUST generate all 14 required fields.
 * Uses OpenAI's Structured Outputs feature for 100% schema compliance.
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
      summaryInsights: {
        type: "array",
        description: "Key resonance themes from the summary",
        items: {
          type: "string"
        }
      },
      interpretationInsights: {
        type: "array",
        description: "Key theological insights from interpretation",
        items: {
          type: "string"
        }
      },
      reflectionAnswers: {
        type: "array",
        description: "Actionable life application responses",
        items: {
          type: "string"
        }
      },
      contextQuestion: {
        type: "string",
        description: "Yes/no question connecting context to modern life"
      },
      summaryQuestion: {
        type: "string",
        description: "Engaging question about the summary"
      },
      relatedVersesQuestion: {
        type: "string",
        description: "Question about verse selection or memorization"
      },
      reflectionQuestion: {
        type: "string",
        description: "Application question connecting theology to daily life"
      },
      prayerQuestion: {
        type: "string",
        description: "Question inviting personal prayer response"
      }
    },
    required: [
      "summary",
      "interpretation",
      "context",
      "relatedVerses",
      "reflectionQuestions",
      "prayerPoints",
      "summaryInsights",
      "interpretationInsights",
      "reflectionAnswers",
      "contextQuestion",
      "summaryQuestion",
      "relatedVersesQuestion",
      "reflectionQuestion",
      "prayerQuestion"
    ],
    additionalProperties: false
  }
} as const
