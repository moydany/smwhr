import { CatalogSection } from "@/components/sections/catalog-section";
import { FinalCtaSection } from "@/components/sections/final-cta-section";
import { HeroSection } from "@/components/sections/hero-section";
import { HowSection } from "@/components/sections/how-section";
import { ProofSection } from "@/components/sections/proof-section";
import { Footer } from "@/components/shared/footer";
import { createServiceClient } from "@/lib/supabase";

async function getWaitlistCount(): Promise<number> {
  if (
    !process.env.NEXT_PUBLIC_SUPABASE_URL ||
    !process.env.SUPABASE_SERVICE_ROLE_KEY
  ) {
    return 0;
  }

  try {
    const supabase = createServiceClient();
    const { count } = await supabase
      .from("waitlist_signups")
      .select("*", { count: "exact", head: true });
    return count ?? 0;
  } catch {
    return 0;
  }
}

export default async function HomePage() {
  const count = await getWaitlistCount();

  return (
    <main className="bg-bg text-text-primary">
      <HeroSection count={count} />
      <ProofSection />
      <HowSection />
      <CatalogSection />
      <FinalCtaSection count={count} />
      <Footer />
    </main>
  );
}
