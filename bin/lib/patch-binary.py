#!/usr/bin/env python3
"""
patch-binary.py -- Patch Claude Code's CLI binary or JS bundle.

Applies two patches to the Claude CLI:
  1. isChannelAllowlisted() -> always returns true  (bypasses GrowthBook check)
  2. DevChannelsDialog()    -> auto-accepts           (bypasses interactive prompt)

Supports two modes, auto-detected from the file:
  - JS text mode:  For Node.js/JS bundles (pre-2.1.119). Reads as UTF-8, uses regex.
  - ELF binary mode: For Bun-compiled binaries (2.1.119+). Reads as bytes, uses
    same-length byte replacement padded with JS block comments.

Creates a patched COPY -- never modifies the original.

Usage:
    python3 bin/lib/patch-binary.py <source_path> <output_path> [--verbose]
    python3 bin/lib/patch-binary.py --check <file_path>   # Check if already patched

Exit codes:
    0  Success (both patches applied, or --check finds already patched)
    1  Patch failure (anchor not found, function not found, etc.)
    2  Partial patch (one succeeded, one failed -- output deleted for safety)
    3  Already patched (--check mode only, when file IS already patched)

The output file is deleted on any failure to prevent partial patches from being used.
"""

import re
import sys
import os

VERBOSE = False

def log(msg):
    """Print a message only when --verbose is active."""
    if VERBOSE:
        print(f"  [verbose] {msg}")


# ---------------------------------------------------------------------------
# Signature used to detect an already-patched binary
# Both patches produce patterns like: return!0}  or  .onAccept()}
# We look for the combination of both markers.
PATCH1_SIGNATURE = r"function [\$\w]+\([^)]*\)\{return!0\}"  # isChannelAllowlisted
PATCH2_SIGNATURE = r"function [\$\w]+\(\w+\)\{\w+\.onAccept\(\)\}"  # DevChannelsDialog


def detect_file_type(filepath: str) -> str:
    """Detect whether the file is a JS text bundle or an ELF binary.

    Returns 'js' or 'elf'.
    Raises PatchError if the file is neither (e.g. PE/MZ Windows binary).
    """
    with open(filepath, "rb") as f:
        magic = f.read(4)
    if magic[:4] == b"\x7fELF":
        return "elf"
    if magic[:2] == b"MZ":
        raise PatchError(f"{filepath} is a PE/Windows binary -- not supported")
    # Assume JS text for everything else (shebang, plain text, etc.)
    return "js"


def is_already_patched(source: str) -> bool:
    """Check if the source already has both patches applied (text mode)."""
    has_patch1 = bool(re.search(PATCH1_SIGNATURE, source))
    has_patch2 = bool(re.search(PATCH2_SIGNATURE, source))
    return has_patch1 and has_patch2


def is_already_patched_bytes(data: bytes) -> bool:
    """Check if the binary already has both patches applied (binary mode).

    Markers must be specific enough not to match unpatched source code.
    The patched functions have a distinctive pattern: short body + long comment pad.
    """
    has_patch1 = b"return!0}/*xxx" in data
    # Patch 2: the function body is {PARAM.onAccept()} followed by a long pad.
    # The unpatched binary has .onAccept() in various contexts, so we need the
    # distinctive pad pattern that only our patcher produces.
    has_patch2 = b".onAccept()}/*xxx" in data
    return has_patch1 and has_patch2


# ---------------------------------------------------------------------------
# Patch 1: isChannelAllowlisted() => { return true }
# ---------------------------------------------------------------------------

def patch_channel_allowlist(source: str) -> str:
    """Replace isChannelAllowlisted function body with { return!0 }."""
    # Find export mapping: isChannelAllowlisted:()=>FUNCNAME
    export_match = re.search(r"isChannelAllowlisted:\(\)=>(\w+)", source)
    if not export_match:
        raise PatchError("Could not find isChannelAllowlisted export mapping")

    func_name = export_match.group(1)

    # Find function definition
    func_pattern = re.compile(rf"function {re.escape(func_name)}\(")
    func_match = func_pattern.search(source)
    if not func_match:
        raise PatchError(f"Could not find function {func_name} definition")

    func_start = func_match.start()

    # Find function body boundaries by counting braces
    brace_start = source.index("{", func_start)
    func_end = find_matching_brace(source, brace_start)
    if func_end == -1:
        raise PatchError("Could not find matching closing brace for isChannelAllowlisted")

    # Extract params
    original_func = source[func_start:func_end]
    param_match = re.match(r"function \w+\(([^)]*)\)", original_func)
    params = param_match.group(1) if param_match else ""

    replacement = f"function {func_name}({params}){{return!0}}"

    # Check if already patched
    if original_func == replacement:
        return source  # already patched

    return source[:func_start] + replacement + source[func_end:]


# ---------------------------------------------------------------------------
# Patch 2: DevChannelsDialog() => auto-accept
# ---------------------------------------------------------------------------

ANCHOR_STRING = "I am using this for local development"


def patch_dev_channels_dialog(source: str) -> str:
    """Replace DevChannelsDialog function with one that calls onAccept() immediately."""
    anchor_index = source.find(ANCHOR_STRING)
    if anchor_index == -1:
        raise PatchError(f'Anchor string not found: "{ANCHOR_STRING}"')

    # Primary strategy: find export mapping DevChannelsDialog:()=>FUNCNAME
    export_match = re.search(r"DevChannelsDialog:\(\)=>(\$?\w+)", source)
    func_bounds = None

    if export_match:
        func_name = export_match.group(1)
        func_decl = f"function {func_name}("
        func_decl_index = source.find(func_decl)
        if func_decl_index != -1:
            brace_start = source.index("{", func_decl_index)
            func_end = find_matching_brace(source, brace_start)
            if func_end != -1 and func_decl_index < anchor_index < func_end:
                func_bounds = (func_decl_index, func_end)

    # Fallback: scan backwards from anchor for enclosing function
    if func_bounds is None:
        func_bounds = find_smallest_enclosing_function(source, anchor_index)

    if func_bounds is None:
        raise PatchError("Could not find function containing DevChannelsDialog anchor string")

    func_start, func_end = func_bounds
    original_func = source[func_start:func_end]

    # Extract function name and parameter
    sig_match = re.match(r"function (\$?\w+)\((\w+)\)", original_func)
    if not sig_match:
        raise PatchError(
            f"Could not parse function signature: {original_func[:100]}..."
        )

    func_name = sig_match.group(1)
    param_name = sig_match.group(2)

    replacement = f"function {func_name}({param_name}){{{param_name}.onAccept()}}"

    # Check if already patched
    if original_func == replacement:
        return source  # already patched

    return source[:func_start] + replacement + source[func_end:]


# ---------------------------------------------------------------------------
# ELF Binary Mode -- Patch functions for Bun-compiled binaries
# ---------------------------------------------------------------------------

def _pad_to_length(replacement: bytes, original_len: int) -> bytes:
    """Pad replacement with a JS block comment to match original_len exactly.

    The comment is appended inside the function body, e.g.:
      {return!0}  -->  {return!0/*xxxxxxx*/}
    We insert the comment BEFORE the final closing brace.
    """
    diff = original_len - len(replacement)
    if diff < 0:
        raise PatchError(
            f"Replacement ({len(replacement)} bytes) is longer than "
            f"original ({original_len} bytes) -- cannot pad"
        )
    if diff == 0:
        return replacement
    # We need to fit /*...*/ which is 4 chars overhead minimum
    if diff < 4:
        # Use spaces instead (still valid JS in most contexts)
        return replacement + b" " * diff
    # Build comment: /* + (diff-4) padding chars + */
    comment = b"/*" + b"x" * (diff - 4) + b"*/"
    return replacement + comment


def elf_patch_channel_allowlist(data: bytes) -> bytes:
    """Binary-mode patch for isChannelAllowlisted: replace body with {return!0}."""

    # Step 1: Find the export mapping to get the function name
    anchor = b"isChannelAllowlisted:()=>"
    anchor_pos = data.find(anchor)
    if anchor_pos == -1:
        raise PatchError("Could not find isChannelAllowlisted export mapping in binary")

    # Extract function name after the arrow
    name_start = anchor_pos + len(anchor)
    # Function name is alphanumeric + $ + _
    name_end = name_start
    while name_end < len(data) and (data[name_end:name_end+1].isalnum() or data[name_end:name_end+1] in (b"$", b"_")):
        name_end += 1
    func_name = data[name_start:name_end]
    if not func_name:
        raise PatchError("Could not extract function name from isChannelAllowlisted export")
    log(f"Patch 1: function name = {func_name.decode('ascii', errors='replace')}")

    # Step 2: Find function definition: function FUNCNAME(
    func_decl = b"function " + func_name + b"("
    func_pos = data.find(func_decl)
    if func_pos == -1:
        raise PatchError(f"Could not find function {func_name} definition in binary")

    # Step 3: Find the opening brace and match to closing brace
    brace_pos = data.index(b"{", func_pos + len(func_decl))
    func_end = _find_matching_brace_bytes(data, brace_pos)
    if func_end == -1:
        raise PatchError("Could not find matching closing brace for isChannelAllowlisted")

    original = data[func_pos:func_end]
    log(f"Patch 1: original ({len(original)} bytes): {original[:120]}...")

    # Step 4: Build replacement -- keep signature, replace body
    # Extract the signature up to and including the opening paren
    sig_end = data.index(b")", func_pos) + 1  # past the closing paren
    signature = data[func_pos:sig_end]
    # Replacement body: {return!0}
    raw_replacement = signature + b"{return!0}"
    replacement = _pad_to_length(raw_replacement, len(original))

    log(f"Patch 1: replacement ({len(replacement)} bytes): {replacement[:120]}...")

    if len(replacement) != len(original):
        raise PatchError(
            f"Length mismatch: original={len(original)}, replacement={len(replacement)}"
        )

    return data[:func_pos] + replacement + data[func_end:]


def elf_patch_dev_channels_dialog(data: bytes) -> bytes:
    """Binary-mode patch for DevChannelsDialog: replace entire function with onAccept() call.

    Must match the JS-mode approach: replace the entire DevChannelsDialog function body
    so the dialog component never renders at all. The previous approach of only rewriting
    the case"exit" handler was insufficient -- the dialog still rendered and prompted.
    """

    # Step 1: Find the anchor string to confirm the binary has the dialog code
    anchor = b"I am using this for local development"
    anchor_pos = data.find(anchor)
    if anchor_pos == -1:
        raise PatchError(f'Anchor string not found in binary: "{anchor.decode()}"')
    log(f"Patch 2: anchor found at offset {anchor_pos}")

    # Step 2: Find the export mapping to get the function name
    export_match = re.search(rb"DevChannelsDialog:\(\)=>(\$?\w+)", data)
    if not export_match:
        raise PatchError("Could not find DevChannelsDialog export mapping in binary")

    func_name = export_match.group(1)
    log(f"Patch 2: function name = {func_name.decode('ascii', errors='replace')}")

    # Step 3: Find the function definition
    func_decl = b"function " + func_name + b"("
    func_pos = data.find(func_decl)
    if func_pos == -1:
        raise PatchError(f"Could not find function {func_name.decode()} definition in binary")

    # Verify anchor is inside this function (sanity check)
    brace_pos = data.index(b"{", func_pos + len(func_decl))
    func_end = _find_matching_brace_bytes(data, brace_pos)
    if func_end == -1:
        raise PatchError("Could not find matching closing brace for DevChannelsDialog")

    if not (func_pos < anchor_pos < func_end):
        raise PatchError(
            f"Anchor string at {anchor_pos} is not inside DevChannelsDialog function "
            f"[{func_pos}..{func_end}] -- wrong function matched"
        )

    original = data[func_pos:func_end]
    log(f"Patch 2: original ({len(original)} bytes): {original[:120]}...")

    # Step 4: Extract the parameter name from the signature
    sig_match = re.match(rb"function \$?\w+\((\w+)\)", original)
    if not sig_match:
        raise PatchError(
            f"Could not parse function signature: {original[:100]}..."
        )
    param_name = sig_match.group(1)

    # Step 5: Build replacement -- entire function calls onAccept() immediately
    # This prevents the dialog from ever rendering (matches JS-mode behavior)
    sig_end_pos = data.index(b")", func_pos) + 1
    signature = data[func_pos:sig_end_pos]
    raw_replacement = signature + b"{" + param_name + b".onAccept()}"
    replacement = _pad_to_length(raw_replacement, len(original))

    log(f"Patch 2: replacement ({len(replacement)} bytes): {replacement[:120]}...")

    if len(replacement) != len(original):
        raise PatchError(
            f"Length mismatch: original={len(original)}, replacement={len(replacement)}"
        )

    return data[:func_pos] + replacement + data[func_end:]


def _find_matching_brace_bytes(data: bytes, brace_start: int) -> int:
    """Find position after the closing brace matching the one at brace_start (bytes mode)."""
    depth = 0
    for i in range(brace_start, len(data)):
        if data[i:i+1] == b"{":
            depth += 1
        elif data[i:i+1] == b"}":
            depth -= 1
            if depth == 0:
                return i + 1
    return -1


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class PatchError(Exception):
    """Raised when a patch cannot be applied."""
    pass


def find_matching_brace(source: str, brace_start: int) -> int:
    """Find the position after the closing brace that matches the one at brace_start."""
    depth = 0
    for i in range(brace_start, len(source)):
        if source[i] == "{":
            depth += 1
        elif source[i] == "}":
            depth -= 1
            if depth == 0:
                return i + 1
    return -1


def find_smallest_enclosing_function(source: str, anchor_index: int):
    """Find the smallest function that contains the anchor index."""
    search_back = 100_000
    search_start = max(0, anchor_index - search_back)
    region = source[search_start:anchor_index]

    candidates = []
    for m in re.finditer(r"function ([\$\w]+)\((\w+)\)\{", region):
        func_start = m.start() + search_start
        brace_start = func_start + len(m.group(0)) - 1
        func_end = find_matching_brace(source, brace_start)
        if func_end != -1 and func_start < anchor_index < func_end:
            candidates.append((func_start, func_end, func_end - func_start))

    if not candidates:
        return None

    # Return smallest enclosing function
    candidates.sort(key=lambda x: x[2])
    return (candidates[0][0], candidates[0][1])


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    global VERBOSE

    args = [a for a in sys.argv[1:] if a != "--verbose"]
    if "--verbose" in sys.argv:
        VERBOSE = True

    if len(args) < 2:
        print("Usage: python3 patch-binary.py <source> <output> [--verbose]", file=sys.stderr)
        print("       python3 patch-binary.py --check <file>", file=sys.stderr)
        sys.exit(1)

    # --check mode: just test if already patched
    if args[0] == "--check":
        filepath = args[1]
        ftype = detect_file_type(filepath)
        if ftype == "elf":
            with open(filepath, "rb") as f:
                data = f.read()
            if is_already_patched_bytes(data):
                print("Already patched (ELF binary)")
                sys.exit(3)
            else:
                print("Not patched (ELF binary)")
                sys.exit(0)
        else:
            try:
                with open(filepath, "r", encoding="utf-8") as f:
                    source = f.read()
            except (UnicodeDecodeError, OSError):
                print("Not patchable (unreadable)")
                sys.exit(0)
            if is_already_patched(source):
                print("Already patched")
                sys.exit(3)
            else:
                print("Not patched")
                sys.exit(0)

    source_path = args[0]
    output_path = args[1]

    # Detect file type
    try:
        ftype = detect_file_type(source_path)
    except PatchError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    except OSError as e:
        print(f"ERROR: Cannot read {source_path}: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"Detected file type: {ftype}")

    if ftype == "elf":
        _main_elf(source_path, output_path)
    else:
        _main_js(source_path, output_path)


def _main_js(source_path: str, output_path: str):
    """Patch a JS text bundle (original mode)."""
    try:
        with open(source_path, "r", encoding="utf-8") as f:
            source = f.read()
    except UnicodeDecodeError:
        print(
            f"ERROR: {source_path} is not a valid UTF-8 text file.",
            file=sys.stderr,
        )
        sys.exit(1)

    log(f"Read {len(source)} characters from {source_path}")

    # Idempotency: check if source is already fully patched
    if is_already_patched(source):
        print("Already patched, copying as-is")
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(source)
        os.chmod(output_path, 0o755)
        sys.exit(0)

    # Apply patches
    patches_applied = 0
    patches_failed = []

    # Patch 1: isChannelAllowlisted
    try:
        source = patch_channel_allowlist(source)
        patches_applied += 1
        print("Patch 1/2: isChannelAllowlisted -- OK")
    except PatchError as e:
        patches_failed.append(f"isChannelAllowlisted: {e}")
        print(f"Patch 1/2: isChannelAllowlisted -- FAILED: {e}", file=sys.stderr)

    # Patch 2: DevChannelsDialog
    try:
        source = patch_dev_channels_dialog(source)
        patches_applied += 1
        print("Patch 2/2: DevChannelsDialog -- OK")
    except PatchError as e:
        patches_failed.append(f"DevChannelsDialog: {e}")
        print(f"Patch 2/2: DevChannelsDialog -- FAILED: {e}", file=sys.stderr)

    # Enforce both-patches-required
    if patches_failed:
        if os.path.exists(output_path):
            os.unlink(output_path)
        if patches_applied > 0:
            print(
                f"PARTIAL FAILURE: {patches_applied}/2 patches applied, "
                f"but both are required. Output deleted.",
                file=sys.stderr,
            )
            for msg in patches_failed:
                print(f"  Failed: {msg}", file=sys.stderr)
            sys.exit(2)
        else:
            print("FAILURE: No patches could be applied.", file=sys.stderr)
            for msg in patches_failed:
                print(f"  Failed: {msg}", file=sys.stderr)
            sys.exit(1)

    # Write patched output
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(source)
    os.chmod(output_path, 0o755)

    # Verify
    with open(output_path, "r", encoding="utf-8") as f:
        verify = f.read()

    if not is_already_patched(verify):
        print("ERROR: Verification failed -- patches not found in output", file=sys.stderr)
        os.unlink(output_path)
        sys.exit(1)

    print(f"SUCCESS: Patched JS binary written to {output_path}")


def _main_elf(source_path: str, output_path: str):
    """Patch a Bun-compiled ELF binary."""
    with open(source_path, "rb") as f:
        data = f.read()

    log(f"Read {len(data)} bytes from {source_path}")

    # Idempotency
    if is_already_patched_bytes(data):
        print("Already patched, copying as-is")
        with open(output_path, "wb") as f:
            f.write(data)
        os.chmod(output_path, 0o755)
        sys.exit(0)

    # Apply patches
    patches_applied = 0
    patches_failed = []

    # Patch 1: isChannelAllowlisted
    try:
        data = elf_patch_channel_allowlist(data)
        patches_applied += 1
        print("Patch 1/3: isChannelAllowlisted (ELF) -- OK")
    except PatchError as e:
        patches_failed.append(f"isChannelAllowlisted: {e}")
        print(f"Patch 1/3: isChannelAllowlisted (ELF) -- FAILED: {e}", file=sys.stderr)

    # Patch 2: DevChannelsDialog
    try:
        data = elf_patch_dev_channels_dialog(data)
        patches_applied += 1
        print("Patch 2/3: DevChannelsDialog (ELF) -- OK")
    except PatchError as e:
        patches_failed.append(f"DevChannelsDialog: {e}")
        print(f"Patch 2/3: DevChannelsDialog (ELF) -- FAILED: {e}", file=sys.stderr)

    # Patch 3: Invalidate bytecode marker so Bun falls back to source text
    # Bun ELF binaries embed both bytecode (in .rodata) and source text (in .bun).
    # By default, Bun executes the pre-compiled bytecode, ignoring our source patches.
    # Corrupting the bytecode marker forces Bun to interpret the patched source instead.
    BYTECODE_MARKER = b"// @bun @bytecode @bun-cjs"
    CORRUPTED_MARKER = b"// @bun @xxxxxxxx @bun-cjs"
    marker_pos = data.find(BYTECODE_MARKER)
    if marker_pos >= 0:
        data = data[:marker_pos] + CORRUPTED_MARKER + data[marker_pos + len(BYTECODE_MARKER):]
        patches_applied += 1
        log(f"Patch 3: bytecode marker invalidated at offset 0x{marker_pos:x}")
        print("Patch 3/3: bytecode marker invalidation -- OK")
    else:
        # No bytecode marker = source-only binary, patches already effective
        patches_applied += 1
        print("Patch 3/3: bytecode marker -- not present (source-only binary, OK)")

    # Enforce both-patches-required
    if patches_failed:
        if os.path.exists(output_path):
            os.unlink(output_path)
        if patches_applied > 0:
            print(
                f"PARTIAL FAILURE: {patches_applied}/2 patches applied, "
                f"but both are required. Output deleted.",
                file=sys.stderr,
            )
            for msg in patches_failed:
                print(f"  Failed: {msg}", file=sys.stderr)
            sys.exit(2)
        else:
            print("FAILURE: No patches could be applied.", file=sys.stderr)
            for msg in patches_failed:
                print(f"  Failed: {msg}", file=sys.stderr)
            sys.exit(1)

    # Write patched output
    with open(output_path, "wb") as f:
        f.write(data)
    os.chmod(output_path, 0o755)

    print(f"SUCCESS: Patched ELF binary written to {output_path}")


if __name__ == "__main__":
    main()
