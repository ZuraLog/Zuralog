// website/src/components/ClientShell.tsx
"use client";
import { LoadingScreen } from "@/components/LoadingScreen";
import { ScrollPhone } from "@/components/phone/ScrollPhone";

export function ClientShell() {
  return (
    <>
      <ScrollPhone />
      <LoadingScreen />
    </>
  );
}
