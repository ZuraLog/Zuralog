/**
 * useQuiz — state machine for the interactive waitlist quiz.
 *
 * Manages step navigation, answer collection, and submission readiness.
 * Answers are stored locally; they're submitted alongside email signup.
 */
'use client';

import { useState, useCallback } from 'react';

export type QuizStep = 'apps' | 'frustrations' | 'goal' | 'signup';

export interface QuizAnswers {
  apps: string[];
  frustrations: string[];
  goal: string;
}

export interface UseQuizReturn {
  currentStep: QuizStep;
  answers: QuizAnswers;
  stepIndex: number;
  totalSteps: number;
  progressPct: number;
  /** Toggle an app selection */
  toggleApp: (app: string) => void;
  /** Toggle a frustration selection */
  toggleFrustration: (frustration: string) => void;
  /** Set the primary goal */
  setGoal: (goal: string) => void;
  /** Advance to next step (or submit if on last step) */
  nextStep: () => void;
  /** Go back to previous step */
  prevStep: () => void;
  /** Whether the current step has valid answers to proceed */
  canProceed: boolean;
}

const STEPS: QuizStep[] = ['apps', 'frustrations', 'goal', 'signup'];

/**
 * Returns stateful quiz management utilities.
 */
export function useQuiz(): UseQuizReturn {
  const [stepIndex, setStepIndex] = useState(0);
  const [answers, setAnswers] = useState<QuizAnswers>({
    apps: [],
    frustrations: [],
    goal: '',
  });

  const currentStep = STEPS[stepIndex];
  const totalSteps = STEPS.length;
  const progressPct = Math.round((stepIndex / (totalSteps - 1)) * 100);

  const toggleApp = useCallback((app: string) => {
    setAnswers((prev) => ({
      ...prev,
      apps: prev.apps.includes(app)
        ? prev.apps.filter((a) => a !== app)
        : [...prev.apps, app],
    }));
  }, []);

  const toggleFrustration = useCallback((f: string) => {
    setAnswers((prev) => ({
      ...prev,
      frustrations: prev.frustrations.includes(f)
        ? prev.frustrations.filter((x) => x !== f)
        : [...prev.frustrations, f],
    }));
  }, []);

  const setGoal = useCallback((goal: string) => {
    setAnswers((prev) => ({ ...prev, goal }));
  }, []);

  const nextStep = useCallback(() => {
    setStepIndex((i) => Math.min(i + 1, STEPS.length - 1));
  }, []);

  const prevStep = useCallback(() => {
    setStepIndex((i) => Math.max(i - 1, 0));
  }, []);

  // Validation per step
  const canProceed =
    currentStep === 'apps'
      ? answers.apps.length > 0
      : currentStep === 'frustrations'
        ? answers.frustrations.length > 0
        : currentStep === 'goal'
          ? answers.goal.length > 0
          : true; // signup step handled by form validation

  return {
    currentStep,
    answers,
    stepIndex,
    totalSteps,
    progressPct,
    toggleApp,
    toggleFrustration,
    setGoal,
    nextStep,
    prevStep,
    canProceed,
  };
}
