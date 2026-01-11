#!/usr/bin/env python3
"""
Generate test vectors for byte↔UTF-16 position conversion.
Each test case includes:
- The test string
- A list of (bytePos, utf16Pos) pairs for key positions
"""

def analyze_string(s: str, label: str) -> dict:
    """Analyze a string and return byte/UTF-16 position mappings."""
    utf8_bytes = s.encode('utf-8')
    _ = s.encode('utf-16-le')  # LE to avoid BOM (used for validation)

    # Build position map: for each byte position, what's the UTF-16 position?
    byte_to_utf16 = []
    utf16_pos = 0
    byte_pos = 0

    for char in s:
        char_utf8_len = len(char.encode('utf-8'))
        char_utf16_len = len(char.encode('utf-16-le')) // 2  # units, not bytes

        # Record the start position of this character
        byte_to_utf16.append((byte_pos, utf16_pos, char, char_utf8_len, char_utf16_len))

        byte_pos += char_utf8_len
        utf16_pos += char_utf16_len

    # Add end position
    byte_to_utf16.append((byte_pos, utf16_pos, '<END>', 0, 0))

    return {
        'label': label,
        'string': s,
        'byte_len': len(utf8_bytes),
        'utf16_len': utf16_pos,
        'positions': byte_to_utf16
    }

def format_sc_string(s: str) -> str:
    """Escape a string for SuperCollider."""
    # Escape backslashes and quotes
    escaped = s.replace('\\', '\\\\').replace('"', '\\"')
    return f'"{escaped}"'

def generate_test_vectors():
    """Generate comprehensive test vectors."""

    test_cases = [
        # 1. ASCII only
        ("Hello World!", "ascii_only"),

        # 2. 2-byte UTF-8 (U+0080-07FF): Latin Extended, Greek, Cyrillic
        ("café", "latin_2byte"),
        ("αβγδ", "greek"),
        ("Привет", "cyrillic"),

        # 3. 3-byte UTF-8 (U+0800-FFFF): CJK, symbols, arrows
        ("한글", "korean"),
        ("日本語", "japanese"),
        ("→←↑↓", "arrows"),
        ("∑∏∫∂", "math_symbols"),

        # 4. 4-byte UTF-8 (U+10000+): Emoji (surrogate pairs in UTF-16)
        ("🎹", "single_emoji"),
        ("🎹🎸🎺", "multiple_emoji"),
        ("👨‍👩‍👧‍👦", "family_emoji"),  # ZWJ sequence

        # 5. Mixed content
        ("Hello→World", "mixed_ascii_arrow"),
        ("a한b글c", "mixed_ascii_korean"),
        ("test🎹end", "mixed_ascii_emoji"),
        ("café→한글🎹done", "mixed_all"),

        # 6. Edge cases
        ("", "empty"),
        ("a", "single_ascii"),
        ("é", "single_2byte"),
        ("한", "single_3byte"),
        ("🎹", "single_4byte"),

        # 7. Boundary positions
        ("abc→def한ghi🎹jkl", "boundary_test"),
    ]

    results = []
    for s, label in test_cases:
        results.append(analyze_string(s, label))

    return results

def print_sc_test_data(vectors):
    """Print test data formatted for SuperCollider."""
    print("// Auto-generated test vectors from m09-test-vectors.py")
    print("// Format: [string, [[bytePos, utf16Pos], ...]]")
    print("(")
    print("~testVectors = [")

    for v in vectors:
        positions = [(p[0], p[1]) for p in v['positions']]
        # Format as SC array
        pos_str = str(positions).replace('(', '[').replace(')', ']')
        print(f"  // {v['label']}: byte_len={v['byte_len']}, utf16_len={v['utf16_len']}")
        print(f"  [{format_sc_string(v['string'])}, {pos_str}],")

    print("];")
    print(")")

def print_detailed_analysis(vectors):
    """Print detailed analysis for debugging."""
    print("\n" + "="*70)
    print("DETAILED POSITION ANALYSIS")
    print("="*70)

    for v in vectors:
        print(f"\n--- {v['label']} ---")
        print(f"String: {repr(v['string'])}")
        print(f"Byte length: {v['byte_len']}, UTF-16 length: {v['utf16_len']}")
        print(f"{'Byte':>6} {'UTF16':>6} {'Char':>6} {'UTF8len':>8} {'UTF16len':>9}")
        print("-" * 40)
        for byte_pos, utf16_pos, char, u8len, u16len in v['positions']:
            char_repr = repr(char) if char != '<END>' else '<END>'
            print(f"{byte_pos:>6} {utf16_pos:>6} {char_repr:>6} {u8len:>8} {u16len:>9}")

def main():
    vectors = generate_test_vectors()

    print("// " + "="*66)
    print("// M0.9 TEST VECTORS - Byte ↔ UTF-16 Position Conversion")
    print("// " + "="*66)
    print()

    print_sc_test_data(vectors)
    print()
    print_detailed_analysis(vectors)

if __name__ == '__main__':
    main()
