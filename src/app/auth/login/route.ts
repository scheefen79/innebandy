import { NextResponse, type NextRequest } from "next/server";
import { getSafeNextPath } from "@/lib/auth/safe-next-path";
import { createRouteHandlerClient } from "@/lib/supabase/route-handler";

export async function POST(request: NextRequest) {
  const formData = await request.formData();
  const email = formData.get("email");
  const password = formData.get("password");
  const nextPath = getSafeNextPath(formData.get("next"));
  const { applyAuthState, supabase } = createRouteHandlerClient(request);
  const normalizedEmail = typeof email === "string" ? email.trim().toLowerCase() : "";
  const normalizedPassword = typeof password === "string" ? password : "";

  let invalidCredentials = !normalizedEmail || !normalizedPassword;

  if (!invalidCredentials) {
    const { error } = await supabase.auth.signInWithPassword({
      email: normalizedEmail,
      password: normalizedPassword,
    });
    invalidCredentials = Boolean(error);
  }

  if (invalidCredentials) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("error", "invalid");
    if (nextPath !== "/") {
      loginUrl.searchParams.set("next", nextPath);
    }
    return applyAuthState(NextResponse.redirect(loginUrl, 303));
  }

  return applyAuthState(NextResponse.redirect(new URL(nextPath, request.url), 303));
}
