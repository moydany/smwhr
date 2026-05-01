import { NextResponse } from "next/server";
import { createServiceClient } from "@/lib/supabase";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET() {
  const supabase = createServiceClient();

  const { count, error } = await supabase
    .from("waitlist_signups")
    .select("*", { count: "exact", head: true });

  if (error) {
    return NextResponse.json({ count: 0 }, { status: 200 });
  }

  return NextResponse.json(
    { count: count ?? 0 },
    {
      headers: {
        "cache-control": "public, s-maxage=60, stale-while-revalidate=300",
      },
    },
  );
}
