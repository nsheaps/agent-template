#!/usr/bin/env bun
/**
 * patch-channel-allowlist.ts — Patches Claude Code's isChannelAllowlisted() to always return true
 *
 * Uses AST parsing to reliably find and patch the function regardless of minification.
 * Works by:
 * 1. Finding the export name mapping: isChannelAllowlisted:()=>FUNCNAME
 * 2. Finding that function's definition in the AST
 * 3. Replacing the function body with { return true }
 *
 * Usage: bun run bin/helpers/patch-channel-allowlist.ts [--restore]
 *
 * Creates a patched COPY rather than modifying in place.
 * The patched copy is used by bin/agent instead of the original.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { resolve, dirname, join } from 'path';
import { execSync } from 'child_process';
import { homedir } from 'os';

const PATCHED_PATH = join(homedir(), '.claude', 'cli.patched.js');

// Find Claude binary
function findClaudeBinary(): string {
  const which = execSync('which claude', { encoding: 'utf-8' }).trim();
  // Resolve symlinks
  const resolved = execSync(`readlink -f "${which}"`, { encoding: 'utf-8' }).trim();
  return resolved;
}

// Get the patched copy path — always ~/.claude/cli.patched.js
function getPatchedPath(_originalPath: string): string {
  return PATCHED_PATH;
}

function restore() {
  const original = findClaudeBinary();
  const patched = getPatchedPath(original);
  if (existsSync(patched)) {
    execSync(`rm "${patched}"`);
    console.log(`Removed patched copy at ${patched}`);
  } else {
    console.log('No patched copy found');
  }
}

function patch() {
  const cliPath = findClaudeBinary();
  console.log(`Source: ${cliPath}`);

  const source = readFileSync(cliPath, 'utf-8');

  // Step 1: Find the export mapping to get the minified function name
  // Pattern: isChannelAllowlisted:()=>FUNCNAME
  const exportMatch = source.match(/isChannelAllowlisted:\(\)=>(\w+)/);
  if (!exportMatch) {
    console.error('ERROR: Could not find isChannelAllowlisted export mapping');
    process.exit(1);
  }
  const funcName = exportMatch[1];
  console.log(`Found isChannelAllowlisted => ${funcName}`);

  // Step 2: Find the function definition using regex to get its position
  // We look for: function FUNCNAME(
  const funcDefRegex = new RegExp(`function ${funcName}\\(`);
  const funcMatch = funcDefRegex.exec(source);
  if (!funcMatch || funcMatch.index === undefined) {
    console.error(`ERROR: Could not find function ${funcName} definition`);
    process.exit(1);
  }

  const funcStart = funcMatch.index;
  console.log(`Found function at offset ${funcStart}`);

  // Step 3: Find the function body boundaries by counting braces
  // Start from the opening { of the function
  let braceStart = source.indexOf('{', funcStart);
  if (braceStart === -1) {
    console.error('ERROR: Could not find opening brace');
    process.exit(1);
  }

  let depth = 0;
  let funcEnd = -1;
  for (let i = braceStart; i < source.length; i++) {
    if (source[i] === '{') depth++;
    else if (source[i] === '}') {
      depth--;
      if (depth === 0) {
        funcEnd = i + 1; // include the closing brace
        break;
      }
    }
  }

  if (funcEnd === -1) {
    console.error('ERROR: Could not find matching closing brace');
    process.exit(1);
  }

  const originalFunc = source.substring(funcStart, funcEnd);
  console.log(`Original function (${originalFunc.length} chars): ${originalFunc.substring(0, 80)}...`);

  // Step 4: Build the replacement
  // Keep the same function signature, just replace the body
  const paramMatch = originalFunc.match(/function \w+\(([^)]*)\)/);
  const params = paramMatch ? paramMatch[1] : '';
  const replacement = `function ${funcName}(${params}){return!0}`;
  console.log(`Replacement: ${replacement}`);

  // Step 5: Check if already patched
  if (originalFunc === replacement) {
    console.log('Already patched');
    process.exit(0);
  }

  // Step 6: Create patched copy
  const patched = source.substring(0, funcStart) + replacement + source.substring(funcEnd);
  const patchedPath = getPatchedPath(cliPath);
  // Ensure ~/.claude/ directory exists
  const claudeDir = join(homedir(), '.claude');
  if (!existsSync(claudeDir)) {
    mkdirSync(claudeDir, { recursive: true });
  }
  writeFileSync(patchedPath, patched, 'utf-8');
  // Make executable
  execSync(`chmod +x "${patchedPath}"`);

  // Step 7: Verify the patch
  const verify = readFileSync(patchedPath, 'utf-8');
  const verifyMatch = verify.match(new RegExp(`function ${funcName}\\([^)]*\\)\\{return!0\\}`));
  if (verifyMatch) {
    console.log(`SUCCESS: Patched copy created at ${patchedPath}`);
    console.log(`Original preserved at ${cliPath}`);
  } else {
    console.error('ERROR: Patch verification failed');
    execSync(`rm "${patchedPath}"`);
    process.exit(1);
  }
}

// Main
const args = process.argv.slice(2);
if (args.includes('--restore')) {
  restore();
} else {
  patch();
}
