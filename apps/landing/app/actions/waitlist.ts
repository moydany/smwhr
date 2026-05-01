"use server";

import { z } from "zod";
import { createServiceClient } from "@/lib/supabase";

const schema = z.object({
  email: z.string().email(),
  interests: z.array(z.string()).max(5),
});

export interface WaitlistResult {
  success: boolean;
  message?: string;
  position?: number;
  alreadyRegistered?: boolean;
}

export async function joinWaitlist(input: {
  email: string;
  interests: string[];
}): Promise<WaitlistResult> {
  const parsed = schema.safeParse(input);

  if (!parsed.success) {
    return { success: false, message: "Email inválido" };
  }

  const supabase = createServiceClient();
  const email = parsed.data.email.toLowerCase().trim();

  const { data: existing, error: existingError } = await supabase
    .from("waitlist_signups")
    .select("id")
    .eq("email", email)
    .maybeSingle();

  if (existingError) {
    return { success: false, message: "Error al consultar la lista" };
  }

  if (existing) {
    const { count } = await supabase
      .from("waitlist_signups")
      .select("*", { count: "exact", head: true });

    return {
      success: true,
      alreadyRegistered: true,
      message: "Ya estás en la lista. Te avisamos pronto.",
      position: count ?? undefined,
    };
  }

  const { error: insertError } = await supabase
    .from("waitlist_signups")
    .insert({
      email,
      interests: parsed.data.interests,
      source: "landing",
    });

  if (insertError) {
    return { success: false, message: "Error al guardar" };
  }

  const { count } = await supabase
    .from("waitlist_signups")
    .select("*", { count: "exact", head: true });

  return {
    success: true,
    position: count ?? undefined,
  };
}
