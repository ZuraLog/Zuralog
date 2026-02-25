/**
 * useQuiz — state machine for the interactive waitlist quiz.
 *
 * Flow: signup (email first) → apps → frustrations → goal → complete
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
  toggleApp: (app: string) => void;
  toggleFrustration: (frustration: string) => void;
  setGoal: (goal: string) => void;
  nextStep: () => void;
  prevStep: () => void;
  onSignupSuccess: (data: SuccessData) => void;
  canProceed: boolean;
}

const QUIZ_STEPS: QuizStep[] = ['signup', 'apps', 'frustrations', 'goal', 'complete'];

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
  const quizStepIndex = stepIndex - 1;
  const quizTotalSteps = 3;
  const progressPct =
    currentStep === 'signup' || currentStep === 'complete'
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

  const onSignupSuccess = useCallback((data: SuccessData) => {
    setSignupData(data);
    setStepIndex(1);
  }, []);

  const canProceed =
    currentStep === 'apps'
      ? answers.apps.length > 0
      : currentStep === 'frustrations'
        ? answers.frustrations.length > 0
        : currentStep === 'goal'
          ? answers.goal.length > 0
          : true;

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
