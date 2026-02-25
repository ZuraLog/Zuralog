/**
 * Zod validation schemas for waitlist API routes.
 */
import { z } from 'zod';

export const joinWaitlistSchema = z.object({
  email: z
    .string()
    .email('Please enter a valid email address')
    .max(255, 'Email is too long')
    .toLowerCase()
    .trim(),
  referralCode: z.string().max(20, 'Invalid referral code').optional().nullable(),
  quizAnswers: z
    .object({
      apps: z.array(z.string()).optional(),
      frustrations: z.array(z.string()).optional(),
      goal: z.string().optional(),
    })
    .optional()
    .nullable(),
});

export type JoinWaitlistInput = z.infer<typeof joinWaitlistSchema>;

export const referralCodeSchema = z.object({
  code: z
    .string()
    .min(6, 'Invalid referral code')
    .max(20, 'Invalid referral code')
    .regex(/^[A-Z0-9]+$/, 'Invalid referral code format'),
});

export type ReferralCodeInput = z.infer<typeof referralCodeSchema>;
