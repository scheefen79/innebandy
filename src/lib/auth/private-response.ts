export const privateResponseHeaders = {
  "Cache-Control": "private, no-cache, no-store, must-revalidate, max-age=0",
  Expires: "0",
  Pragma: "no-cache",
};

export function applyPrivateResponseHeaders(headers: Headers) {
  Object.entries(privateResponseHeaders).forEach(([name, value]) => {
    headers.set(name, value);
  });
}
