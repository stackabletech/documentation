#! /bin/bash
DOCSEARCH_ENABLED=true DOCSEARCH_ENGINE=lunr antora sven-antora-playbook.yml
touch build/site/.nojekyll