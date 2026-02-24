/**
 * QuizContainer — orchestrates the multi-step onboarding quiz.
 *
 * Manages step transitions and wires the useQuiz hook to child steps.
 * Transitions between steps use Framer Motion slide animations.
 */
'use client';

import { AnimatePresence, motion } from 'framer-motion';
import { useQuiz } from '@/hooks/use-quiz';
import { AppsStep } from './apps-step';
import { FrustrationsStep } from './frustrations-step';
import { GoalStep } from './goal-step';
import { WaitlistForm } from './waitlist-form';
import { ProgressIndicator } from './progress-indicator';

/**
 * Renders the full quiz flow with step transitions.
 */
export function QuizContainer() {
  const quiz = useQuiz();

  return (
    <div className="w-full max-w-2xl">
      {/* Progress bar — hidden on signup step */}
      {quiz.currentStep !== 'signup' && (
        <ProgressIndicator
          current={quiz.stepIndex}
          total={quiz.totalSteps - 1}
          pct={quiz.progressPct}
        />
      )}

      {/* Step content with slide transition */}
      <div className="relative mt-8 min-h-[400px]">
        <AnimatePresence mode="wait">
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

          {quiz.currentStep === 'signup' && (
            <motion.div
              key="signup"
              initial={{ opacity: 0, x: 40 }}
              animate={{ opacity: 1, x: 0 }}
              exit={{ opacity: 0, x: -40 }}
              transition={{ duration: 0.3 }}
            >
              <WaitlistForm
                quizAnswers={quiz.answers}
                onBack={quiz.prevStep}
              />
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
}
