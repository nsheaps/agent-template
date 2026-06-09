#!/usr/bin/env bun
/**
 * patch-dev-channels.ts
 *
 * Patches Claude Code's DevChannelsDialog to auto-accept instead of prompting.
 * Creates a patched copy at ~/.claude/cli.patched.js — NEVER modifies the original.
 *
 * Usage:
 *   bun run patch-dev-channels.ts          # Create/update patched copy
 *   bun run patch-dev-channels.ts --path   # Print path to patched copy (empty if not patched)
 *   bun run patch-dev-channels.ts --restore  # Remove patched copy
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { execSync } from 'child_process';
import { join } from 'path';
import { homedir } from 'os';

const ANCHOR_STRING = 'I am using this for local development';
const PATCHED_PATH = join(homedir(), '.claude', 'cli.patched.js');

function findCliJs(): string {
  const which = execSync('which claude', { encoding: 'utf-8' }).trim();
  const resolved = execSync(`readlink -f "${which}"`, { encoding: 'utf-8' }).trim();
  return resolved;
}

/**
 * Find the function body bounds for the function that contains `anchor`.
 *
 * Strategy: use the export map entry `DevChannelsDialog:()=>FUNCNAME` to find the
 * exact minified function name, then locate `function FUNCNAME(` in the source.
 * Falls back to a brace-walk scan if the export map pattern isn't found.
 */
function findFunctionContainingString(
  source: string,
  anchor: string
): { start: number; end: number } | null {
  const anchorIndex = source.indexOf(anchor);
  if (anchorIndex === -1) return null;

  // Primary strategy: find the export mapping for DevChannelsDialog.
  // The minified bundle exports it as: DevChannelsDialog:()=>FUNCNAME
  // FUNCNAME may include $ (e.g. $KO), so we use a permissive capture group.
  const exportMatch = source.match(/DevChannelsDialog:\(\)=>(\$?\w+)/);
  if (exportMatch) {
    const funcName = exportMatch[1];
    const funcDecl = `function ${funcName}(`;
    const funcDeclIndex = source.indexOf(funcDecl);
    if (funcDeclIndex !== -1) {
      const braceStart = source.indexOf('{', funcDeclIndex);
      if (braceStart !== -1) {
        let depth = 0;
        let funcEnd = -1;
        for (let i = braceStart; i < source.length; i++) {
          if (source[i] === '{') depth++;
          else if (source[i] === '}') {
            depth--;
            if (depth === 0) {
              funcEnd = i + 1;
              break;
            }
          }
        }
        if (funcEnd !== -1 && braceStart < anchorIndex && anchorIndex < funcEnd) {
          return { start: funcDeclIndex, end: funcEnd };
        }
      }
    }
  }

  // Fallback: scan backwards from the anchor, checking all function declarations
  // (including those with $ in the name) to find the smallest enclosing one.
  const SEARCH_BACK = 100_000;
  const searchStart = Math.max(0, anchorIndex - SEARCH_BACK);
  const funcDeclRegex = /function ([\$\w]+)\((\w+)\)\{/g;
  funcDeclRegex.lastIndex = 0;
  const regionBefore = source.substring(searchStart, anchorIndex);

  const containing: Array<{ start: number; end: number; size: number }> = [];

  let m: RegExpExecArray | null;
  while ((m = funcDeclRegex.exec(regionBefore)) !== null) {
    const funcStart = m.index + searchStart;
    // The { is the last character of the full match
    const braceStart = funcStart + m[0].length - 1;
    let depth = 0;
    let funcEnd = -1;
    for (let i = braceStart; i < source.length; i++) {
      if (source[i] === '{') depth++;
      else if (source[i] === '}') {
        depth--;
        if (depth === 0) {
          funcEnd = i + 1;
          break;
        }
      }
    }
    if (funcEnd !== -1 && funcStart < anchorIndex && anchorIndex < funcEnd) {
      containing.push({ start: funcStart, end: funcEnd, size: funcEnd - funcStart });
    }
  }

  if (containing.length === 0) return null;

  // Return the smallest (innermost) enclosing function
  containing.sort((a, b) => a.size - b.size);
  const { start, end } = containing[0];
  return { start, end };
}

function main() {
  const args = process.argv.slice(2);

  // --restore: remove the patched copy
  if (args.includes('--restore')) {
    if (existsSync(PATCHED_PATH)) {
      execSync(`rm "${PATCHED_PATH}"`);
      console.log(`Removed patched copy at ${PATCHED_PATH}`);
    } else {
      console.log('No patched copy found, nothing to restore.');
    }
    return;
  }

  // --path: print path to patched copy (empty if not yet created)
  if (args.includes('--path')) {
    if (existsSync(PATCHED_PATH)) {
      console.log(PATCHED_PATH);
    } else {
      console.log('');
    }
    return;
  }

  // Default: create/update the patched copy
  // Read from existing patched copy if available (chains with patch-channel-allowlist)
  const cliPath = existsSync(PATCHED_PATH) ? PATCHED_PATH : findCliJs();
  console.log(`Source: ${cliPath}`);

  const source = readFileSync(cliPath, 'utf-8');

  // Verify the anchor exists in the source
  if (!source.includes(ANCHOR_STRING)) {
    console.error(`ERROR: Anchor string not found in ${cliPath}`);
    console.error(`  Looking for: "${ANCHOR_STRING}"`);
    console.error('  The CLI version may have changed. Update the anchor string.');
    process.exit(1);
  }

  // Find the DevChannelsDialog function boundaries
  const funcBounds = findFunctionContainingString(source, ANCHOR_STRING);
  if (!funcBounds) {
    console.error('ERROR: Could not find the function containing the anchor string.');
    process.exit(1);
  }

  const originalFunc = source.substring(funcBounds.start, funcBounds.end);
  console.log(`Found function (${originalFunc.length} chars) at offset ${funcBounds.start}`);

  // Extract function name and first parameter name from the signature
  // Function names in minified bundles may include $ (e.g. $KO)
  const sigMatch = originalFunc.match(/^function ([\$\w]+)\((\w+)\)/);
  if (!sigMatch) {
    console.error('ERROR: Could not parse function signature from:');
    console.error(`  ${originalFunc.substring(0, 100)}...`);
    process.exit(1);
  }

  const [, funcName, paramName] = sigMatch;
  console.log(`Function: ${funcName}, param: ${paramName}`);

  // Build the replacement: call onAccept() immediately via the props object.
  // Using paramName.onAccept() avoids depending on any minified destructured name.
  const replacement = `function ${funcName}(${paramName}){${paramName}.onAccept()}`;
  console.log(`Replacement: ${replacement}`);

  // Check if the patched file already has this exact replacement
  if (existsSync(PATCHED_PATH)) {
    const existingPatched = readFileSync(PATCHED_PATH, 'utf-8');
    if (existingPatched.includes(replacement)) {
      console.log('Already patched, no changes needed.');
      console.log(PATCHED_PATH);
      return;
    }
  }

  // Build the patched source
  const patched =
    source.substring(0, funcBounds.start) + replacement + source.substring(funcBounds.end);

  // Ensure ~/.claude/ directory exists
  const claudeDir = join(homedir(), '.claude');
  if (!existsSync(claudeDir)) {
    mkdirSync(claudeDir, { recursive: true });
  }

  // Write the patched copy
  writeFileSync(PATCHED_PATH, patched, 'utf-8');
  execSync(`chmod +x "${PATCHED_PATH}"`);

  // Verify the patch landed correctly
  const verify = readFileSync(PATCHED_PATH, 'utf-8');
  if (!verify.includes(replacement)) {
    console.error('ERROR: Verification failed — replacement not found in patched file.');
    execSync(`rm "${PATCHED_PATH}"`);
    process.exit(1);
  }

  console.log(`SUCCESS: Patched copy written to ${PATCHED_PATH}`);
  console.log(PATCHED_PATH);
}

main();
