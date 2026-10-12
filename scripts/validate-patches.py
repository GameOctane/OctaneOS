#!/usr/bin/env python3
"""Check unified-diff patches: hunk header counts vs body, and missing trailing context.
Usage: validate-patches.py FILE...   (exit 1 if any problem)"""
import re, sys
H = re.compile(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@')
def check(path):
    probs = []
    lines = open(path, errors='replace').read().split('\n')
    if lines and lines[-1] == '': lines.pop()
    i = 0
    while i < len(lines):
        m = H.match(lines[i])
        if not m: i += 1; continue
        ob = int(m.group(2)) if m.group(2) is not None else 1
        nb = int(m.group(4)) if m.group(4) is not None else 1
        start = i; i += 1
        o = n = 0; body = []
        while i < len(lines) and not H.match(lines[i]) and not lines[i].startswith('diff --git') \
              and not re.match(r'^(--- |\+\+\+ )', lines[i]) or (i < len(lines) and lines[i].startswith(('---','+++')) and o < ob and False):
            l = lines[i]
            if l.startswith('\\'): i += 1; continue
            c = l[:1] if l else ' '            # an empty line counts as blank context
            if c == ' ': o += 1; n += 1; body.append(' ')
            elif c == '-': o += 1; body.append('-')
            elif c == '+': n += 1; body.append('+')
            else: break
            i += 1
            if o >= ob and n >= nb: break
        if (o, n) != (ob, nb):
            probs.append(f"hunk at line {start+1}: header says -{ob} +{nb}, body has -{o} +{n}")
        # context balance
        pre = 0
        for c in body:
            if c == ' ': pre += 1
            else: break
        post = 0
        for c in reversed(body):
            if c == ' ': post += 1
            else: break
        if post < pre and any(c != ' ' for c in body):
            probs.append(f"hunk at line {start+1}: {pre} leading but only {post} trailing context lines (GNU patch will insist on end-of-file)")
    return probs
bad = 0
for p in sys.argv[1:]:
    pr = check(p)
    if pr:
        bad += 1
        print(f"BAD  {p}")
        for x in pr: print("       " + x)
print(f"\n{len(sys.argv)-1} patches checked, {bad} with problems")
sys.exit(1 if bad else 0)
