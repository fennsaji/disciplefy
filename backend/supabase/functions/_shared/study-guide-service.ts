
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { StudyGuideRepository } from '../study-generate/study-guide-repository.ts';
import { LLMService } from './llm-service.ts';
import { SecurityValidator } from './security-validator.ts';
import { CacheService } from './cache-service.ts';

interface StudyGuideInput {
  inputType: 'scripture' | 'topic';
  inputValue: string;
  language: string;
}

interface UserContext {
  isAuthenticated: boolean;
  userId?: string;
  sessionId?: string;
}

export class StudyGuideService {
  private repository: StudyGuideRepository;
  private llmService: LLMService;
  private securityValidator: SecurityValidator;
  private cache: CacheService;

  constructor(supabaseClient: SupabaseClient) {
    this.repository = new StudyGuideRepository(supabaseClient);
    this.llmService = new LLMService();
    this.securityValidator = new SecurityValidator();
    this.cache = new CacheService();
  }

  async findOrCreateStudyGuide(input: StudyGuideInput, userContext: UserContext) {
    const cacheKey = await this.getCacheKey(input);
    const cachedGuide = this.cache.get(cacheKey);
    if (cachedGuide) {
      return this.saveStudyGuide(input, cachedGuide, userContext);
    }

    const existingStudyGuide = await this.findExistingStudyGuide(input, userContext);
    if (existingStudyGuide) {
      return existingStudyGuide;
    }

    const newStudyGuide = await this.llmService.generateStudyGuide(input);
    this.cache.set(cacheKey, newStudyGuide, 3600 * 1000); // Cache for 1 hour

    return await this.saveStudyGuide(input, newStudyGuide, userContext);
  }

  private async getCacheKey(input: StudyGuideInput): Promise<string> {
    const hash = await this.securityValidator.hashSensitiveData(
      `${input.inputType}:${input.inputValue}:${input.language}`
    );
    return `study-guide:${hash}`;
  }

  private async findExistingStudyGuide(input: StudyGuideInput, userContext: UserContext) {
    if (userContext.isAuthenticated) {
      return await this.repository.findExistingAuthenticatedStudyGuide(
        userContext.userId!,
        input.inputType,
        input.inputValue,
        input.language
      );
    } else {
      const inputValueHash = await this.securityValidator.hashSensitiveData(input.inputValue);
      return await this.repository.findExistingAnonymousStudyGuide(
        userContext.sessionId!,
        input.inputType,
        inputValueHash,
        input.language
      );
    }
  }

  private async saveStudyGuide(input: StudyGuideInput, studyGuide: any, userContext: UserContext) {
    const studyGuideData = {
      ...studyGuide,
      inputType: input.inputType,
      inputValue: input.inputValue,
      language: input.language,
    };

    if (userContext.isAuthenticated) {
      return await this.repository.saveAuthenticatedStudyGuide(userContext.userId!, studyGuideData);
    } else {
      const inputValueHash = await this.securityValidator.hashSensitiveData(input.inputValue);
      return await this.repository.saveAnonymousStudyGuide(userContext.sessionId!, {
        ...studyGuideData,
        inputValueHash,
      });
    }
  }

  async getStudyGuides(userId: string, savedOnly: boolean, limit: number, offset: number) {
    return await this.repository.getStudyGuides(userId, savedOnly, limit, offset);
  }

  async updateStudyGuide(userId: string, guideId: string, isSaved: boolean) {
    return await this.repository.updateStudyGuide(userId, guideId, isSaved);
  }
}
