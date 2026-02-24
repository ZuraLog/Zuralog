/**
 * QuizContainer — orchestrates the multi-step onboarding flow.
 *
 * New flow order:
 *   1. signup  — email form (FIRST — secure spot before answering questions)
 *   2. apps    — which fitness apps do you use?
 *   3. frustrations — what frustrates you most?
 *   4. goal    — what's your primary goal?
 *   5. complete — success panel with referral code
 *
 * Transitions between steps use Framer Motion slide animations.
 */
'use client';

import { AnimatePresence, motion } from 'framer-motion';
import { useQuiz } from '@/hooks/use-quiz';
import { WaitlistForm } from './waitlist-form';
import { AppsStep } from './apps-step';
import { FrustrationsStep } from './frustrations-step';
import { GoalStep } from './goal-step';
import { CompletionStep } from './completion-step';
import { ProgressIndicator } from './progress-indicator';

/**
 * Renders the full quiz flow with step transitions.
 * Email signup is step 0; quiz questions follow.
 */
interface QuizContainerProps {
  /** Bubbles email value up for easter egg detection */
  onEmailChange?: (value: string) => void;
}

export function QuizContainer({ onEmailChange }: QuizContainerProps) {
  const quiz = useQuiz();

  // Quiz questions are steps 1-3 (apps, frustrations, goal)
  // Progress indicator only shows during question steps
  const showProgress = quiz.currentStep === 'apps'
    || quiz.currentStep === 'frustrations'
    || quiz.currentStep === 'goal';

  // 0-indexed within question steps (0=apps, 1=frustrations, 2=goal)
  const questionIndex = quiz.currentStep === 'apps' ? 0
    : quiz.currentStep === 'frustrations' ? 1
    : quiz.currentStep === 'goal' ? 2
    : 0;

  return (
    <div className="w-full max-w-2xl">
      {/* Progress bar — only during question steps */}
      {showProgress && (
        <ProgressIndicator
          current={questionIndex}
          total={3}
          pct={Math.round(((questionIndex) / 3) * 100)}
        />
      )}

      {/* Step content with slide transition */}
      <div className={`relative ${showProgress ? 'mt-8' : ''} min-h-[400px]`}>
        <AnimatePresence mode="wait">
          {quiz.currentStep === 'signup' && (
            <motion.div
              key="signup"
              initial={{ opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -40 }}
              transition={{ duration: 0.3 }}
            >
              <WaitlistForm onSignupSuccess={quiz.onSignupSuccess} onEmailChange={onEmailChange} />
            </motion.div>
          )}

          {quiz.currentStep === 'apps' && (
            <motion.div
              key="apps"
              initial={{ opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -40 }}
              transition={{ duration: 0.3 }}
            >
              <AppsStep
                selected={quiz.answers.apps}
                onToggle={quiz.toggleApp}
                onNext={quiz.nextStep}
                canProceed={quiz.canProceed}
              />
            </motion.div>
          )}

          {quiz.currentStep === 'frustrations' && (
            <motion.div
              key="frustrations"
              initial={{ opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -40 }}
              transition={{ duration: 0.3 }}
            >
              <FrustrationsStep
                selected={quiz.answers.frustrations}
                onToggle={quiz.toggleFrustration}
                onNext={quiz.nextStep}
                onBack={quiz.prevStep}
                canProceed={quiz.canProceed}
              />
            </motion.div>
          )}

          {quiz.currentStep === 'goal' && (
            <motion.div
              key="goal"
              initial={{ opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -40 }}
              transition={{ duration: 0.3 }}
            >
              <GoalStep
                selected={quiz.answers.goal}
                onSelect={quiz.setGoal}
                onNext={quiz.nextStep}
                onBack={quiz.prevStep}
                canProceed={quiz.canProceed}
              />
            </motion.div>
          )}

          {quiz.currentStep === 'complete' && quiz.signupData && (
            <motion.div
              key="complete"
              initial={{ opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -40 }}
              transition={{ duration: 0.3 }}
            >
              <CompletionStep data={quiz.signupData} />
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
