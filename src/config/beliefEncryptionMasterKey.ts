import { resolve } from "node:path";
import { homedir } from "node:os";

/**
 * Returns the path for the CSFLE master key.
 * Separate from the credential vault master key to avoid coupling.
 */
export function getBeliefMasterKeyPath(mnemaHome?: string): string {
  const base = mnemaHome ?? resolve(homedir(), ".mnema");
  return resolve(base, "belief.key");
}
