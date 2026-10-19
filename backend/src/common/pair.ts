/** Canonical ordering for an unordered pair of user ids. */
export function orderedPair(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a];
}
