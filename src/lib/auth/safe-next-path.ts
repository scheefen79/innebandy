export function getSafeNextPath(value: FormDataEntryValue | string | null | undefined) {
  if (typeof value !== "string") {
    return "/";
  }

  if (
    !value.startsWith("/") ||
    value.startsWith("//") ||
    value.includes("\\") ||
    /[\u0000-\u001f\u007f]/.test(value)
  ) {
    return "/";
  }

  const parsed = new URL(value, "https://innebandy.local");

  if (parsed.origin !== "https://innebandy.local") {
    return "/";
  }

  return `${parsed.pathname}${parsed.search}${parsed.hash}`;
}
