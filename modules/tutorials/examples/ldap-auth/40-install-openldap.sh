#!/usr/bin/env bash
set -euo pipefail

echo "Installing tutorial-openldap stack"
# tag::install-openldap[]
stackablectl stack install tutorial-openldap
# end::install-openldap[]

echo "Applying yamls"

# tag::apply-bind-credentials-secret[]
kubectl apply -f bind-credentials-secret.yaml
# end::apply-bind-credentials-secret[]

# tag::apply-bind-credentials-secretclass[]
kubectl apply -f bind-credentials-secretclass.yaml
# end::apply-bind-credentials-secretclass[]

# tag::apply-ldap-authenticationclass[]
kubectl apply -f ldap-authenticationclass.yaml
# end::apply-ldap-authenticationclass[]
