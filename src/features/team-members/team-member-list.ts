import type { TeamRole } from "@/lib/auth/team-context";

export type TeamMemberListItem = {
  userId: string;
  email: string;
  role: TeamRole;
  isActive: boolean;
  invitedAt: string;
  fingerprint: string;
};
