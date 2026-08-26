import { headers } from "next/headers";
import { VERIFIED_USER_HEADER } from "@/lib/auth/verified-user-header";

export async function getVerifiedUserId(): Promise<string | null> {
  return (await headers()).get(VERIFIED_USER_HEADER);
}
