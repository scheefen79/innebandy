import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { applyPrivateResponseHeaders } from "@/lib/auth/private-response";
import { getSafeNextPath } from "@/lib/auth/safe-next-path";
import { VERIFIED_USER_HEADER } from "@/lib/auth/verified-user-header";
import { getSupabaseConfig } from "@/lib/supabase/config";

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });
  applyPrivateResponseHeaders(response.headers);
  let refreshedCookies: Array<{
    name: string;
    options: Parameters<typeof response.cookies.set>[2];
    value: string;
  }> = [];
  let refreshedHeaders: Record<string, string> = {};
  const { publishableKey, url } = getSupabaseConfig();

  const supabase = createServerClient(url, publishableKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        refreshedCookies = cookiesToSet;
        refreshedHeaders = headers;
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        applyPrivateResponseHeaders(response.headers);
        cookiesToSet.forEach(({ name, options, value }) => {
          response.cookies.set(name, value, options);
        });
        Object.entries(headers).forEach(([name, value]) => {
          response.headers.set(name, value);
        });
      },
    },
  });

  const { data: verifiedSession } = await supabase.auth.getClaims();
  const claims = verifiedSession?.claims;
  const isLoginRoute = request.nextUrl.pathname === "/login";
  const isPublicAuthRoute = isLoginRoute || request.nextUrl.pathname === "/auth/login";

  if (claims?.sub) {
    request.headers.set(VERIFIED_USER_HEADER, claims.sub);
    response = NextResponse.next({ request });
    applyPrivateResponseHeaders(response.headers);
    refreshedCookies.forEach(({ name, options, value }) => {
      response.cookies.set(name, value, options);
    });
    Object.entries(refreshedHeaders).forEach(([name, value]) => {
      response.headers.set(name, value);
    });
  }

  function redirectWithRefreshedSession(url: URL) {
    const redirectResponse = NextResponse.redirect(url);
    applyPrivateResponseHeaders(redirectResponse.headers);
    refreshedCookies.forEach(({ name, options, value }) => {
      redirectResponse.cookies.set(name, value, options);
    });
    Object.entries(refreshedHeaders).forEach(([name, value]) => {
      redirectResponse.headers.set(name, value);
    });
    return redirectResponse;
  }

  if (!claims?.sub && !isPublicAuthRoute) {
    const loginUrl = request.nextUrl.clone();
    loginUrl.pathname = "/login";
    loginUrl.search = "";
    loginUrl.searchParams.set(
      "next",
      getSafeNextPath(`${request.nextUrl.pathname}${request.nextUrl.search}`),
    );
    return redirectWithRefreshedSession(loginUrl);
  }

  if (claims?.sub && isLoginRoute) {
    const destination = new URL(
      getSafeNextPath(request.nextUrl.searchParams.get("next")),
      request.url,
    );
    return redirectWithRefreshedSession(destination);
  }

  return response;
}
