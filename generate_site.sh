#! /bin/bash
DOCSEARCH_ENABLED=true DOCSEARCH_ENGINE=lunr antora --fetch sven-antora-playbook.yml
touch build/site/.nojekyll