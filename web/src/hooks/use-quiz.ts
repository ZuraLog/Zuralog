/**
 * useQuiz — state machine for the interactive waitlist quiz.
 *
 * Manages step navigation, answer collection, and submission readiness.
 * Answers are stored locally; they're submitted alongside email signup.
 */
'use client';

import { useState, useCallback } from 'react';

export type QuizStep = 'signup' | 'apps' | 'frustrations' | 'goal' | 'complete';

export interface QuizAnswers {
  apps: string[];
  frustrations: string[];
  goal: string;
}

export interface SuccessData {
  position: number;
  referralCode: string;
  tier: string;
}

export interface UseQuizReturn {
  currentStep: QuizStep;
  answers: QuizAnswers;
  signupData: SuccessData | null;
  stepIndex: number;
  totalSteps: number;
  progressPct: number;
  /** Toggle an app selection */
  toggleApp: (app: string) => void;
  /** Toggle a frustration selection */
  toggleFrustration: (frustration: string) => void;
  /** Set the primary goal */
  setGoal: (goal: string) => void;
  /** Advance to next step */
  nextStep: () => void;
  /** Go back to previous step */
  prevStep: () => void;
  /** Set signup success data and advance to next step */
  onSignupSuccess: (data: SuccessData) => void;
  /** Whether the current step has valid answers to proceed */
  canProceed: boolean;
}

/** Steps visible in the progress indicator (excludes signup and complete) */
const QUIZ_STEPS: QuizStep[] = ['signup', 'apps', 'frustrations', 'goal', 'complete'];

/**
 * Returns stateful quiz management utilities.
 * Flow: signup (email first) → apps → frustrations → goal → complete
 */
export function useQuiz(): UseQuizReturn {
  const [stepIndex, setStepIndex] = useState(0);
  const [signupData, setSignupData] = useState<SuccessData | null>(null);
  const [answers, setAnswers] = useState<QuizAnswers>({
    apps: [],
    frustrations: [],
    goal: '',
  });

  const currentStep = QUIZ_STEPS[stepIndex];
  const totalSteps = QUIZ_STEPS.length;
  // Progress excludes signup (step 0) and complete (last) — only quiz steps count
  const quizStepIndex = stepIndex - 1; // 0-indexed within quiz steps
  const quizTotalSteps = 3; // apps, frustrations, goal
  const progressPct = currentStep === 'signup' || currentStep === 'complete'
    ? 0
    : Math.round((quizStepIndex / quizTotalSteps) * 100);

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
    setStepIndex((i) => Math.min(i + 1, QUIZ_STEPS.length - 1));
  }, []);

  const prevStep = useCallback(() => {
    setStepIndex((i) => Math.max(i - 1, 0));
  }, []);

  /**
   * Called by WaitlistForm on successful email signup.
   * Stores success data and advances to quiz question steps.
   */
  const onSignupSuccess = useCallback((data: SuccessData) => {
    setSignupData(data);
    setStepIndex(1); // advance to 'apps' step
  }, []);

  // Validation per step
  const canProceed =
    currentStep === 'apps'
      ? answers.apps.length > 0
      : currentStep === 'frustrations'
        ? answers.frustrations.length > 0
        : currentStep === 'goal'
          ? answers.goal.length > 0
          : true; // signup handled by form; complete has no proceed

  return {
    currentStep,
    answers,
    signupData,
    stepIndex,
    totalSteps,
    progressPct,
    toggleApp,
    toggleFrustration,
    setGoal,
    nextStep,
    prevStep,
    onSignupSuccess,
    canProceed,
  };
}
