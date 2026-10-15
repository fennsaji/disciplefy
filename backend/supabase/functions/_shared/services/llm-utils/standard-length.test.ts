// Run with: deno test standard-length.test.ts
import { assert, assertEquals, assertStringIncludes } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { standardInterpretationTargets, createStandardPass1Prompt } from './standard-multipass.ts'
import { getLanguageConfig } from '../llm-config/language-configs.ts'

Deno.test('English asks for at least 460 + 300 interpretation words', () => {
  const t = standardInterpretationTargets('en')
  assertEquals(t.part1Min, 460)
  assertEquals(t.part2Min, 300)
})

Deno.test('Malayalam asks for more than English, not less', () => {
  // Scaling Malayalam down by its lower guide target made its guides shorter.
  assert(standardInterpretationTargets('ml').part1Min > standardInterpretationTargets('en').part1Min)
})

Deno.test('the pass 1 prompt states the interpretation length as a floor', () => {
  const config = getLanguageConfig('hi')!
  const prompt = createStandardPass1Prompt({ inputType: 'topic', inputValue: 'Prayer', language: 'hi', studyMode: 'standard' }, config)
  const text = JSON.stringify(prompt)
  assertStringIncludes(text, `at least ${standardInterpretationTargets('hi').part1Min}`)
  assertStringIncludes(text, 'LENGTH IS A FLOOR')
})
