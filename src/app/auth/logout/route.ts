import { NextResponse, type NextRequest } from "next/server";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export async function POST(request: NextRequest) {
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  await supabase.auth.signOut();
  return applyAuthState(NextResponse.redirect(new URL("/login", request.url), 303));
}
