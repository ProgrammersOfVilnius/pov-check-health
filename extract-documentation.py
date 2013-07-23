#!/usr/bin/env python
import re

checks_marker = '\n#\n# Checks\n#\n\n'

doc_rx = re.compile('^\n(# [a-zA-Z_0-9]+.*\n(?:#.*\n)+)', re.MULTILINE)


def extract_docs(filename='functions.sh'):
    with open(filename) as f:
        code = f.read()
    checks = code.partition(checks_marker)[-1]
    docs = doc_rx.findall(checks)
    return docs


def main():
    docs = extract_docs()
    for doc in docs:
        doc = (doc.lstrip('# ')
                  .replace('\n# ', '\n')
                  .replace('\n#', '\n')
                  .replace('\n  Example:', '\n\n  Example:'))
        doc = re.sub('Example: (.*)', r'Example: ``\1``', doc)
        print doc
        print

if __name__ == '__main__':
    main()

