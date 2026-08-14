import { createServerClient, type CookieOptions } from "@supabase/ssr";
import { type NextRequest, type NextResponse } from "next/server";
import { applyPrivateResponseHeaders } from "@/lib/auth/private-response";
import { getSupabaseConfig } from "@/lib/supabase/config";

type AuthCookie = {
  name: string;
  options: CookieOptions;
  value: string;
};

export function createRouteHandlerClient(request: NextRequest) {
  let pendingCookies: AuthCookie[] = [];
  let pendingHeaders: Record<string, string> = {};
  const { publishableKey, url } = getSupabaseConfig();

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        pendingCookies = cookiesToSet;
        pendingHeaders = headers;
      },
    },
  });

  function applyAuthState(response: NextResponse) {
    applyPrivateResponseHeaders(response.headers);
    pendingCookies.forEach(({ name, options, value }) => {
      response.cookies.set(name, value, options);
    });
    Object.entries(pendingHeaders).forEach(([name, value]) => {
      response.headers.set(name, value);
    });
    return response;
  }

  return { applyAuthState, supabase };
}
