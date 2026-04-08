// website/src/components/phone/screens/PlaceholderScreen.tsx
"use client";

interface PlaceholderScreenProps {
  label?: string;
}

export function PlaceholderScreen({ label = "ZuraLog" }: PlaceholderScreenProps) {
  return (
    <div className="w-full h-full flex items-center justify-center bg-[#F0EEE9]">
      <span
        className="text-xs text-[#9B9894]"
        style={{ fontFamily: "var(--font-jakarta)" }}
      >
        {label}
      </span>
    </div>
  );
}
